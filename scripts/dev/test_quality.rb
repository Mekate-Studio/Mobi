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
      write('.gitignore', "ignored/\n")
      TOOL_NAMES.each do |tool|
        path = File.join(bin, tool)
        File.write(path, "#!#{RUBY}\n" + <<~'SCRIPT')
          require 'json'
          name = File.basename($PROGRAM_NAME)
          if ARGV == ['--version']
            puts "#{name} fixture-version"
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
      git('init', '--quiet')
      git('config', 'core.filemode', 'true')
      stage
    end

    def copy(path)
      target = File.join(@root, path)
      FileUtils.mkdir_p(File.dirname(target))
      FileUtils.cp(File.join(ROOT, path), target)
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

    def run(*argv, extra_env: {})
      out, err, status = Open3.capture3(@env.merge(extra_env), *argv, chdir: @root)
      [status.success?, out + err]
    end

    def quality(mode = 'commit', *options, **kwargs)
      run(RUBY, 'scripts/dev/quality.rb', mode, *options, **kwargs)
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

  test('missing tools fail before any analyzer with installation guidance') do |f|
    # Direct runner isolates PATH; the shell front door intentionally adds installed tools.
    empty = File.join(File.dirname(f.root), 'runtime-only')
    FileUtils.mkdir_p(empty)
    # Apple's system Ruby invokes uname during startup; keep runtime prerequisites.
    %w[git uname].each do |command|
      path = ENV.fetch('PATH').split(':').map { |dir| File.join(dir, command) }.find { |candidate| File.executable?(candidate) && File.file?(candidate) }
      File.symlink(path, File.join(empty, command)) if path
    end
    f.reject(/Missing quality tools:.*install_quality_tools/, extra_env: { 'PATH' => empty })
    assert(f.calls.empty?, 'analyzer started despite missing tool')
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
