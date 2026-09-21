# frozen_string_literal: true

# Disposable Git repositories and fake analyzers; no gems, native builds or downloads.
require 'fileutils'
require 'json'
require 'open3'
require 'rbconfig'
require 'tmpdir'
require_relative 'quality'

module QualityTest
  ROOT = File.expand_path('../..', __dir__)
  RUBY = RbConfig.ruby
  TOOL_NAMES = %w[ktlint detekt swiftformat swiftlint shellcheck].freeze

  def self.assert(condition, message)
    raise message unless condition
  end

  class Fixture
    attr_reader :root, :env

    def initialize(temp)
      @root = File.join(temp, 'repo')
      bin = File.join(temp, 'bin')
      FileUtils.mkdir_p([@root, bin])
      @env = { 'PATH' => "#{bin}:#{ENV.fetch('PATH')}", 'QUALITY_TEST_LOG' => File.join(temp, 'tools.jsonl') }
      # Prevent the calling checkout/index or a user's Git configuration from leaking in.
      %w[GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR CI_PROJECT_DIR].each { |key| @env[key] = nil }
      @env['GIT_CONFIG_GLOBAL'] = File::NULL
      @env['GIT_CONFIG_NOSYSTEM'] = '1'
      copy('scripts/dev/quality.rb')
      copy('scripts/quality_tools.rb')
      copy('.ruby-version')
      copy('.swift-version')
      %w[lint format check common].each { |name| copy("scripts/dev/#{name}.sh") }
      copy('scripts/ci/run_job.sh')
      copy('scripts/ci/lib.sh')
      Dir.glob(File.join(ROOT, 'scripts/ci/lib/*.sh')).each { |path| copy(path.delete_prefix(ROOT + '/')) }
      copy('.githooks/pre-commit')
      %w[.swiftlint.yml .swiftformat detekt.yml .editorconfig].each { |path| copy(path) }
      write('project.yaml', "modules:\n  - feature\n")
      write('feature/module.yaml', "product: jvm/lib\n")
      write('feature/src/Example.kt', "class Example\n")
      write('ios-app/Dependencies/Package.swift', "// swift-tools-version: 6.0\n")
      write('.gitignore', "ignored/\n.quality/\n")
      TOOL_NAMES.each do |tool|
        path = File.join(bin, tool)
        File.write(path, "#!#{RUBY}\n" + <<~'SCRIPT')
          require 'json'
          name = File.basename($PROGRAM_NAME)
          if ARGV == ['--version']
            puts(name == 'ktlint' ? 'ktlint version fixture-version' : name == 'shellcheck' ? 'version: fixture-version' : 'fixture-version')
            exit 0
          end
          entry = { 'tool' => name, 'args' => ARGV }
          if name == 'swiftlint'
            entry['swift'] = Integer(ENV.fetch('SCRIPT_INPUT_FILE_COUNT')).times.map { |i| ENV.fetch("SCRIPT_INPUT_FILE_#{i}") }
          end
          File.open(ENV.fetch('QUALITY_TEST_LOG'), 'a') { |log| log.puts JSON.generate(entry) }
          if name == 'ktlint'
            sleep 0.05 if ENV['QUALITY_TEST_MUTATION']
            case ENV['QUALITY_TEST_MUTATION']
            when 'same-stat'
              path = 'feature/src/Example.kt'
              stat = File.stat(path)
              File.write(path, "class Changed\n")
              File.utime(stat.atime, stat.mtime, path)
            when 'index'
              File.write('feature/src/Example.kt', "class Changed\n")
              abort 'fixture git add failed' unless system('git', 'add', '--', 'feature/src/Example.kt')
            when 'untracked'
              File.write('new-during-analysis.txt', 'new')
            end
          end
          exit(ENV['QUALITY_TEST_FAIL'] == name ? 1 : 0)
        SCRIPT
        File.chmod(0o755, path)
      end
      setup_fake_toolchain(bin)
      git('init', '--quiet')
      git('config', 'core.filemode', 'true')
      stage
    end

    def setup_fake_toolchain(bin)
      lock = JSON.parse(File.read(File.join(ROOT, 'quality-tools.json')))
      lock['ruby']['version'] = RUBY_VERSION
      lock['ruby']['entry'] = 'tools/ruby'
      lock['platforms'].each_value do |platform|
        platform['java']['entry'] = 'tools/java'
        platform['tools'].each do |name, item|
          item['kind'] = 'executable'
          item['entry'] = "tools/#{name}"
          item['version'] = 'fixture-version'
        end
      end
      lock['rules'].each_key { |path| lock['rules'][path] = Digest::SHA256.file(File.join(@root, path)).hexdigest }
      write('quality-tools.json', JSON.pretty_generate(lock) + "\n")
      toolchain = PinnedQuality::Toolchain.new(@root)
      FileUtils.mkdir_p(File.join(toolchain.slot, 'tools'))
      TOOL_NAMES.each { |name| FileUtils.cp(File.join(bin, name), File.join(toolchain.slot, 'tools', name)) }
      ruby = File.join(toolchain.slot, 'tools/ruby')
      File.write(ruby, "#!#{RUBY}\nexec #{RUBY.inspect}, *ARGV\n")
      File.chmod(0o755, ruby)
      java = File.join(toolchain.slot, 'tools/java')
      File.write(java, "#!#{RUBY}\nputs 'java.runtime.version = 21.0.11+10-LTS'\nputs 'java.vendor = Eclipse Adoptium'\n")
      File.chmod(0o755, java)
      File.write(File.join(toolchain.slot, '.mobi-quality-owned'), toolchain.install_id)
      receipt = { 'schema' => 1, 'install_id' => toolchain.install_id, 'files' => toolchain.tree }
      File.write(File.join(toolchain.slot, 'receipt.json'), JSON.pretty_generate(receipt))
    end

    def copy(path)
      target = File.join(@root, path)
      FileUtils.mkdir_p(File.dirname(target))
      FileUtils.cp(File.join(ROOT, path), target)
    end

    def use_installed_toolchain
      original = PinnedQuality::Toolchain.new(ROOT)
      original.verify!
      copy('quality-tools.json')
      relocated = PinnedQuality::Toolchain.new(@root)
      FileUtils.mkdir_p(File.dirname(relocated.slot))
      FileUtils.cp_r(original.slot, relocated.slot)
      relocated.verify!
      @quality_ruby = relocated.command('ruby').first
      program = "require 'yaml'; require 'json'; require 'digest'; require 'open3'; require 'tmpdir'; " \
                "abort 'Ruby still uses the original prefix' if ($LOAD_PATH + $LOADED_FEATURES).any? { |path| path.start_with?(ARGV.fetch(0)) }"
      ok, output = run(@quality_ruby, '-e', program, original.slot)
      QualityTest.assert(ok, "Relocated Ruby standard library failed: #{output}")
    end

    def write(path, content)
      target = File.join(@root, path)
      FileUtils.mkdir_p(File.dirname(target))
      File.binwrite(target, content)
    end

    def git(*args, input: '')
      out, err, status = Open3.capture3(@env, 'git', *args, chdir: @root, stdin_data: input)
      raise "Fixture git #{args.inspect}: #{err}" unless status.success?

      out
    end

    def stage
      git('add', '--all')
    end

    def calls
      log = @env.fetch('QUALITY_TEST_LOG')
      File.exist?(log) ? File.readlines(log).map { |line| JSON.parse(line) } : []
    end

    def clear_calls
      FileUtils.rm_f(@env.fetch('QUALITY_TEST_LOG'))
    end

    def refresh_receipt
      toolchain = PinnedQuality::Toolchain.new(@root)
      receipt = { 'schema' => 1, 'install_id' => toolchain.install_id, 'files' => toolchain.tree }
      File.write(File.join(toolchain.slot, 'receipt.json'), JSON.pretty_generate(receipt))
    end

    def run(*argv, extra_env: {})
      out, err, status = Open3.capture3(@env.merge(extra_env), *argv, chdir: @root)
      [status.success?, out + err]
    end

    def quality(mode = 'commit', *options, **kwargs)
      run(@quality_ruby || RUBY, 'scripts/dev/quality.rb', mode, *options, **kwargs)
    end

    def pass(*args, **kwargs)
      ok, output = quality(*args, **kwargs)
      QualityTest.assert(ok, "Expected pass:\n#{output}")
      output
    end

    def reject(pattern, *args, **kwargs)
      ok, output = quality(*args, **kwargs)
      QualityTest.assert(!ok && output.match?(pattern), "Expected rejection #{pattern}:\n#{output}")
      output
    end

    def manifest(mode = 'static')
      JSON.parse(pass(mode, '--manifest'))
    end

    def new_module
      write('project.yaml', "modules:\n  - feature\n  - feature-new\n")
      write('feature-new/module.yaml', "product: kmp/lib\n")
      %w[src src@android src@ios test test@iosSimulatorArm64].each do |dir|
        write("feature-new/#{dir}/Example.kt", "class Example\n")
      end
    end
  end

  @tests = []
  def self.test(name, &block)
    @tests << [name, block]
  end

  test('manual lint includes untracked source, dynamic roots, packages and hooks') do |f|
    f.new_module
    f.write('ios-app/Dependencies/Sources/New.swift', "struct New {}\n")
    f.write('settings.gradle.kts', "// build script\n")
    f.pass('static')
    inputs = f.manifest.fetch('inputs')
    assert(inputs['detekt'].count == 6, inputs.inspect)
    assert(inputs['kotlin'].include?('settings.gradle.kts'), inputs.inspect)
    assert(inputs['swift'].include?('ios-app/Dependencies/Sources/New.swift'), inputs.inspect)
    assert(inputs['shell'].include?('.githooks/pre-commit'), inputs.inspect)
    f.reject(/untracked/)
    f.stage
    f.pass
  end

  test('tracked ignored files are inputs; generated untracked files are excluded') do |f|
    f.write('ignored/Tracked.kts', '// tracked despite ignore')
    f.git('add', '--force', '--', 'ignored/Tracked.kts')
    f.new_module
    f.write('feature-new/build/Generated.kt', 'not source')
    f.write('ignored/NotSource.kt', 'not source')
    inputs = f.manifest
    assert(inputs['inputs']['kotlin'].include?('ignored/Tracked.kts'), inputs.inspect)
    assert(inputs['excluded_generated'] == ['feature-new/build/Generated.kt'], inputs.inspect)
    assert(!inputs['inputs']['kotlin'].include?('ignored/NotSource.kt'), inputs.inspect)
    f.reject(/untracked/)
    FileUtils.rm_rf(File.join(f.root, 'feature-new/build'))
    f.stage
    f.pass
  end

  test('spaces, tabs, newlines and leading dashes remain exact analyzer inputs') do |f|
    names = ["space name", "tab\tname", "new\nline", '-leading']
    names.each do |name|
      f.write("feature/src/#{name}.kt", "class Example\n")
      f.write("ios-app/Dependencies/#{name}.swift", "struct Example {}\n")
      f.write("scripts/#{name}.sh", "#!/bin/sh\ntrue\n")
    end
    f.stage
    f.pass
    names.each do |name|
      assert(f.calls.find { |c| c['tool'] == 'ktlint' }['args'].include?("./feature/src/#{name}.kt"), name.inspect)
      assert(f.calls.find { |c| c['tool'] == 'detekt' }['args'].last.split(',').include?("./feature/src/#{name}.kt"), name.inspect)
      assert(f.calls.find { |c| c['tool'] == 'swiftlint' }['swift'].include?("./ios-app/Dependencies/#{name}.swift"), name.inspect)
      assert(f.calls.find { |c| c['tool'] == 'swiftformat' }['args'].include?("./ios-app/Dependencies/#{name}.swift"), name.inspect)
      assert(f.calls.find { |c| c['tool'] == 'shellcheck' }['args'].include?("./scripts/#{name}.sh"), name.inspect)
    end
  end

  test('partial staging rejects before tools and preserves both copies') do |f|
    index = File.binread(File.join(f.root, '.git/index'))
    f.write('feature/src/Example.kt', "class Changed\n")
    f.reject(/Index\/checkout mismatch/)
    assert(f.calls.empty?, 'analyzers ran on partial staging')
    assert(File.binread(File.join(f.root, '.git/index')) == index, 'index was modified')
    assert(File.read(File.join(f.root, 'feature/src/Example.kt')) == "class Changed\n", 'work was modified')
    f.stage
    f.pass
  end

  test('unstaged tracked deletion and rename reject') do |f|
    FileUtils.mv(File.join(f.root, 'feature/src/Example.kt'), File.join(f.root, 'feature/src/Renamed.kt'))
    f.reject(/untracked/)
    FileUtils.rm(File.join(f.root, 'feature/src/Renamed.kt'))
    f.reject(/Missing or unresolved path/)
    assert(f.calls.empty?, 'analyzers ran on deleted source')
    f.stage
    f.pass
  end

  test('mode changes reject even with core.filemode false') do |f|
    f.git('config', 'core.filemode', 'false')
    File.chmod(0o755, File.join(f.root, 'feature/src/Example.kt'))
    f.reject(/mismatch/)
    f.git('update-index', '--chmod=+x', '--', 'feature/src/Example.kt')
    f.pass
  end

  test('intent-to-add including an empty file rejects') do |f|
    f.write('empty.txt', '')
    f.git('add', '--intent-to-add', '--', 'empty.txt')
    f.reject(/Intent-to-add/)
    assert(f.calls.empty?, 'analyzers ran on intent-to-add')
    f.stage
    f.pass
  end

  test('unmerged entries reject') do |f|
    oid = f.git('rev-parse', ':feature/src/Example.kt').strip
    f.git('update-index', '--index-info', input: "0 #{'0' * 40}\tfeature/src/Example.kt\n100644 #{oid} 1\tfeature/src/Example.kt\n100644 #{oid} 2\tfeature/src/Example.kt\n")
    f.reject(/unmerged/i)
    assert(f.calls.empty?, 'analyzers ran on conflict')
  end

  test('intent-to-add on a recreated HEAD path cannot hide behind the same diff name') do |f|
    # One synthetic HEAD object in this disposable fixture, without running hooks.
    f.env.merge!('GIT_AUTHOR_NAME' => 'Fixture', 'GIT_AUTHOR_EMAIL' => 'fixture@example.invalid',
                 'GIT_COMMITTER_NAME' => 'Fixture', 'GIT_COMMITTER_EMAIL' => 'fixture@example.invalid')
    tree = f.git('write-tree').strip
    head = f.git('commit-tree', tree, input: "Fixture baseline\n").strip
    f.git('update-ref', 'HEAD', head)
    f.git('rm', '--cached', '--', 'feature/src/Example.kt')
    f.write('feature/src/Example.kt', '')
    f.git('add', '--intent-to-add', '--', 'feature/src/Example.kt')
    f.reject(/Intent-to-add/)
    assert(f.calls.empty?, 'analyzers ran on recreated intent-to-add')
  end

  %w[assume-unchanged skip-worktree].each do |flag|
    test("#{flag} cannot hide content") do |f|
      f.git('update-index', "--#{flag}", '--', 'feature/src/Example.kt')
      f.write('feature/src/Example.kt', "class Changed\n")
      f.reject(/Unsupported index flags/)
      assert(f.calls.empty?, 'analyzers ran with trust flag')
      f.git('update-index', "--no-#{flag}", '--', 'feature/src/Example.kt')
      f.stage
      f.pass
    end
  end

  test('symlinks cannot escape or silently omit source') do |f|
    File.symlink('project.yaml', File.join(f.root, 'doc-link'))
    f.stage
    f.pass
    FileUtils.rm(File.join(f.root, 'doc-link'))
    File.symlink('detekt.yml', File.join(f.root, 'doc-link'))
    f.reject(/mismatch/)
    f.stage
    f.pass
    File.symlink('/etc/passwd', File.join(f.root, 'escape'))
    f.stage
    f.reject(/escapes repository/)
    FileUtils.rm(File.join(f.root, 'escape'))
    File.symlink('Example.kt', File.join(f.root, 'feature/src/Link.kt'))
    f.stage
    f.reject(/Unsupported source symlink/)
  end

  test('custom layouts, templates, unknown Kotlin roots and ambiguous paths reject') do |f|
    f.write('feature/module.yaml', "product: jvm/lib\napply: template.yaml\n")
    f.reject(/Unsupported module/, 'static')
    f.write('feature/module.yaml', "product: jvm/lib\nsettings:\n  sources: other\n")
    f.reject(/Unsupported source configuration/, 'static')
    f.write('feature/module.yaml', "product: jvm/lib\n")
    f.write('feature/custom/Example.kt', 'class Example')
    f.reject(/Unsupported Kotlin source layout/, 'static')
    FileUtils.rm_rf(File.join(f.root, 'feature/custom'))
    f.write('feature/src/comma,name.kt', 'class Example')
    f.reject(/Unsupported kotlin analyzer path/, 'static')
    FileUtils.rm(File.join(f.root, 'feature/src/comma,name.kt'))
    f.write('ios-app/Dependencies/Glob[1].swift', '// unsupported glob path')
    f.reject(/Unsupported swift analyzer path/, 'static')
  end

  test('directory symlinks and source ancestors cannot hide source') do |f|
    File.symlink('src', File.join(f.root, 'feature/src@ios'))
    f.reject(/Unsupported directory symlink/, 'static')
    FileUtils.rm(File.join(f.root, 'feature/src@ios'))
    FileUtils.mv(File.join(f.root, 'feature/src'), File.join(f.root, 'feature/real-source'))
    File.symlink('real-source', File.join(f.root, 'feature/src'))
    f.write('.gitignore', "ignored/\nfeature/real-source/\n")
    f.reject(/Unsupported (source|directory) symlink/, 'static')
  end

  test('duplicate YAML graph keys cannot hide modules') do |f|
    f.write('project.yaml', "modules: [hidden]\nmodules: [feature]\n")
    f.reject(/Duplicate YAML keys/, 'static')
    f.write('project.yaml', "modules: [feature]\n---\nmodules: [hidden]\n")
    f.reject(/single YAML document/, 'static')
  end

  test('submodule index entries fail explicitly') do |f|
    oid = f.git('rev-parse', ':feature/src/Example.kt').strip
    f.git('update-index', '--add', '--cacheinfo', "160000,#{oid},external-module")
    f.reject(/Unsupported index mode 160000/)
    assert(f.calls.empty?, 'analyzers ran with a submodule')
  end

  %w[same-stat index untracked].each do |mutation|
    test("during-analysis #{mutation} mutation invalidates successful tools") do |f|
      output = f.reject(/mismatch|changed during analysis|untracked/, extra_env: { 'QUALITY_TEST_MUTATION' => mutation })
      assert(f.calls.size == 5, output)
    end
  end

  test('hook, manual check, lint and CI share manifests and execute tools once') do |f|
    manifests = []
    [['./.githooks/pre-commit'], ['./scripts/dev/check.sh'], ['./scripts/dev/lint.sh'],
     ['./scripts/ci/run_job.sh', 'quality-check']].each do |command|
      f.clear_calls
      index = File.binread(File.join(f.root, '.git/index'))
      ok, output = f.run(*command)
      assert(ok, output)
      manifests << JSON.parse(output.lines.find { |line| line.start_with?('[quality] manifest=') }.delete_prefix('[quality] manifest='))
      assert(f.calls.map { |call| call['tool'] } == TOOL_NAMES, f.calls.inspect)
      assert(File.binread(File.join(f.root, '.git/index')) == index, 'index mutated')
      assert(!Dir.exist?(File.join(f.root, 'build')), 'CI static mode bootstrapped build directories')
      assert(output.include?('[quality] versions=') && output.include?('[quality] timing='), output)
    end
    assert(manifests.uniq.length == 1, 'entry-point inputs differ')
    f.write('feature/src/Example.kt', "class Changed\n")
    ok, output = f.run('./scripts/ci/run_job.sh', 'quality-check')
    assert(ok, output)
  end

  test('formatter shares inventory; only explicit format invokes autofix') do |f|
    f.write('feature/src/New.kt', 'class New')
    static = f.manifest
    assert(f.manifest('format') == static, 'format inventory differs')
    f.pass('format')
    assert(f.calls.map { |call| call['tool'] } == %w[ktlint swiftformat], f.calls.inspect)
    assert(f.calls.first['args'].include?('--format'), f.calls.inspect)
    assert(!f.calls.last['args'].include?('--lint'), f.calls.inspect)
  end

  test('analyzer failure propagates and cannot produce a pass') do |f|
    f.reject(/detekt failed/, extra_env: { 'QUALITY_TEST_FAIL' => 'detekt' })
    assert(f.calls.map { |call| call['tool'] } == %w[ktlint detekt], f.calls.inspect)
  end

  test('missing managed tools fail before analysis despite tools on PATH') do |f|
    toolchain = PinnedQuality::Toolchain.new(f.root)
    FileUtils.rm(File.join(toolchain.slot, 'tools/detekt'))
    f.reject(/checksum\/identity mismatch.*install_quality_tools/)
    assert(f.calls.empty?, 'analyzer started despite missing tool')
  end

  test('wrong managed version fails even with a consistent local receipt') do |f|
    toolchain = PinnedQuality::Toolchain.new(f.root)
    target = File.join(toolchain.slot, 'tools/swiftlint')
    File.write(target, "#!#{RUBY}\nputs 'unexpected-version'\n")
    f.refresh_receipt
    f.reject(/swiftlint version mismatch/)
    assert(f.calls.empty?, 'analysis ran with wrong version')
  end

  test('wrong core runtime fails before tool analysis') do |f|
    lock = JSON.parse(File.read(File.join(f.root, 'quality-tools.json')))
    lock['ruby']['version'] = '0.0.0'
    f.write('quality-tools.json', JSON.pretty_generate(lock))
    f.stage
    f.reject(/Ruby version mismatch/)
    assert(f.calls.empty?, 'analysis ran with wrong Ruby')
  end

  test('rule drift and ignored nested configuration fail before analysis') do |f|
    f.write('.swiftlint.yml', "disabled_rules: []\n")
    f.stage
    f.reject(/Rule profile mismatch/)
    f.copy('.swiftlint.yml')
    f.write('.gitignore', "ignored/\n.quality/\nfeature/src/.editorconfig\n")
    f.write('feature/src/.editorconfig', "[*]\nktlint = disabled\n")
    f.stage
    f.reject(/Unpinned analyzer configuration/)
    assert(f.calls.empty?, 'analysis ran with rule drift')
  end

  test('global PATH tools cannot shadow the locked tools') do |f|
    path = File.join(f.env.fetch('PATH').split(':').first, 'ktlint')
    File.write(path, "#!#{RUBY}\nabort 'shadow was used'\n")
    f.pass
    assert(f.calls.size == 5, 'managed analyzer count differs')
  end

  test('verified offline setup reuse does not call download or build') do |f|
    toolchain = PinnedQuality::Toolchain.new(f.root)
    toolchain.define_singleton_method(:build_install!) { raise 'unexpected build/network' }
    toolchain.install!
    assert(f.calls.empty?, 'reuse ran source analysis')
  end

  test('concurrent setup fails without touching the active store') do |f|
    toolchain = PinnedQuality::Toolchain.new(f.root)
    File.open(File.join(f.root, '.quality/install.lock'), File::RDWR | File::CREAT, 0o600) do |lock|
      lock.flock(File::LOCK_EX)
      begin
        toolchain.install!
        raise 'concurrent installer unexpectedly succeeded'
      rescue PinnedQuality::Failure => error
        assert(error.message.include?('Another quality installer'), error.message)
      end
    end
    f.pass
  end

  test('incomplete receipt blocks use and explicit repair recovers the selected slot') do |f|
    toolchain = PinnedQuality::Toolchain.new(f.root)
    FileUtils.rm(File.join(toolchain.slot, 'receipt.json'))
    f.reject(/Missing complete quality installation/)
    begin
      toolchain.install!
      raise 'incomplete installation reused'
    rescue PinnedQuality::Failure => error
      assert(error.message.include?('Missing complete'), error.message)
    end
    # Exercise the actual repair/ownership/locking path, with a local fixture builder.
    toolchain.define_singleton_method(:build_install!) do
      f.setup_fake_toolchain(f.env.fetch('PATH').split(':').first)
    end
    toolchain.install!(repair: true)
    f.pass
  end

  test('corrupt downloads fail checksum verification before extraction') do |f|
    toolchain = PinnedQuality::Toolchain.new(f.root)
    # Replace transport only; exercise the production checksum boundary.
    toolchain.define_singleton_method(:run!) do |*args, **_options|
      File.write(args[args.index('--output') + 1], 'corrupt artifact')
    end
    Dir.mktmpdir('mobi-quality-checksum-') do |temp|
      begin
        toolchain.send(:download, { 'url' => 'https://example.invalid/pinned', 'sha256' => '0' * 64 }, temp)
        raise 'corrupt download accepted'
      rescue PinnedQuality::Failure => error
        assert(error.message.include?('checksum mismatch'), error.message)
      end
    end
  end

  test('failed installation removes temporary state and publishes no receipt') do |f|
    toolchain = PinnedQuality::Toolchain.new(f.root)
    FileUtils.rm_rf(toolchain.slot)
    toolchain.define_singleton_method(:download) { |_item, _directory| raise PinnedQuality::Failure, 'simulated network failure' }
    begin
      toolchain.install!
      raise 'failed setup accepted'
    rescue PinnedQuality::Failure => error
      assert(error.message.include?('simulated network failure'), error.message)
    end
    assert(!Dir.exist?(toolchain.slot), 'failed setup published a slot')
    assert(Dir.glob(File.join(f.root, '.quality/build-*')).empty?, 'temporary build directory leaked')
  end

  test('interrupted installation removes temporary state and publishes no receipt') do |f|
    toolchain = PinnedQuality::Toolchain.new(f.root)
    FileUtils.rm_rf(toolchain.slot)
    toolchain.define_singleton_method(:download) { |_item, _directory| raise Interrupt }
    begin
      toolchain.install!
      raise 'interrupted setup accepted'
    rescue Interrupt
      assert(!Dir.exist?(toolchain.slot), 'interrupted setup published a slot')
      assert(Dir.glob(File.join(f.root, '.quality/build-*')).empty?, 'temporary build directory leaked')
    end
  end

  test('repair refuses unowned state and symlinked stores') do |f|
    toolchain = PinnedQuality::Toolchain.new(f.root)
    FileUtils.rm(File.join(toolchain.slot, '.mobi-quality-owned'))
    begin
      toolchain.install!(repair: true)
      raise 'unowned state removed'
    rescue PinnedQuality::Failure => error
      assert(error.message.include?('unowned'), error.message)
    end
    assert(Dir.exist?(toolchain.slot), 'unowned state was deleted')
    FileUtils.mv(File.join(f.root, '.quality'), File.join(f.root, '.quality-saved'))
    File.symlink('.quality-saved', File.join(f.root, '.quality'))
    begin
      PinnedQuality::Toolchain.new(f.root)
      raise 'symlinked store accepted'
    rescue PinnedQuality::Failure => error
      assert(error.message.include?('Symlinked quality store'), error.message)
    end
  end

  test('manifest inspection works without installing quality tools') do |f|
    toolchain = PinnedQuality::Toolchain.new(f.root)
    FileUtils.rm_rf(File.join(f.root, '.quality'))
    ok, output = f.run('./scripts/dev/lint.sh', '--manifest')
    assert(ok && JSON.parse(output)['inputs']['kotlin'] == ['feature/src/Example.kt'], output)
  end

  def self.run
    failures = []
    @tests.each do |name, block|
      Dir.mktmpdir('mobi-quality-test-') do |temp|
        begin
          block.call(Fixture.new(temp))
          puts "PASS #{name}"
        rescue StandardError => error
          failures << name
          warn "FAIL #{name}: #{error.message}"
        end
      end
    end
    puts "#{@tests.length} tests, #{failures.length} failures"
    exit(failures.empty? ? 0 : 1)
  end
end

QualityTest.run if $PROGRAM_NAME == __FILE__
