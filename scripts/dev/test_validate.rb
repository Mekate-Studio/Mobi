# frozen_string_literal: true

require_relative 'test_quality'
require_relative 'validate'

module ValidationTest
  @tests = []
  def self.test(name, &block)
    @tests << [name, block]
  end

  def self.assert(value, message)
    QualityTest.assert(value, message)
  end

  def self.base(f, action = '')
    f.write('project.yaml', "modules: [feature, android-app]\n")
    f.write('android-app/module.yaml', "product: android/app\nsettings:\n  android:\n    versionCode: 42\n    versionName: reviewed\n")
    f.write('android-app/src/HomePresenter.kt', "class HomePresenter\n")
    f.write('android-app/test/ExampleTest.kt', "class ExampleTest\n")
    jobs = File.join(File.dirname(f.root), 'jobs.jsonl')
    f.write('scripts/ci/run_job.sh', "#!#{QualityTest::RUBY}\nrequire 'json'\n" + <<~RUBY)
      File.open(#{jobs.inspect}, 'a') { |log| log.puts JSON.generate('job' => ARGV[0], 'cwd' => Dir.pwd, 'pid' => Process.pid, 'env' => ENV.to_h) }
      #{action}
    RUBY
    File.chmod(0o755, File.join(f.root, 'scripts/ci/run_job.sh'))
    f.stage
    f.git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '--quiet', '--no-verify', '-m', 'baseline')
    f.write('android-app/src/HomePresenter.kt', "class HomePresenter { val value = 1 }\n")
    f.stage
    jobs
  end

  def self.plan(f)
    Dir.chdir(f.root) { Precommit::Plan.new.data }
  end

  def self.jobs(path)
    File.exist?(path) ? File.readlines(path).map { |line| JSON.parse(line) } : []
  end

  def self.gradle_fixture(log, versions: %w[8.14.3], action: '')
    launcher = "#!#{QualityTest::RUBY}\nrequire 'json'\n" + <<~RUBY
      File.open(#{log.inspect}, 'a') { |file| file.puts JSON.generate('args' => ARGV, 'env' => ENV.to_h, 'pid' => Process.pid, 'cwd' => Dir.pwd, 'launcher' => $PROGRAM_NAME) }
      #{action}
    RUBY
    <<~RUBY
      require 'fileutils'
      #{versions.inspect}.each do |version|
        home = ENV.fetch('GRADLE_USER_HOME')
        FileUtils.mkdir_p(File.join(home, 'daemon', version))
        launcher = File.join(home, 'wrapper/dists', "gradle-\#{version}-bin/fixture/gradle-\#{version}/bin/gradle")
        FileUtils.mkdir_p(File.dirname(launcher))
        File.write(launcher, #{launcher.inspect})
        File.chmod(0755, launcher)
      end
    RUBY
  end

  def self.remove_retained_copy(log)
    jobs(log).each { |job| FileUtils.remove_entry_secure(job['cwd']) if Dir.exist?(job['cwd']) }
  end

  test('behavior runs static once and only selected native tests in a cleaned source copy') do |f|
    log = base(f)
    before = File.binread(File.join(f.root, '.git/index'))
    ok, output = f.run('./scripts/dev/check.sh', extra_env: { 'ANDROID_KEYSTORE_BASE64' => 'fixture-secret', 'VERSION_CODE' => '999', 'GITHUB_TOKEN' => 'fixture-secret' })
    assert(ok, output)
    records = jobs(log)
    assert(records.map { |job| job['job'] } == ['android-test'], records.inspect)
    assert(records.all? { |job| job['cwd'] != f.root && !Dir.exist?(job['cwd']) }, 'snapshot escaped or leaked')
    assert(records.none? { |job| %w[GITHUB_TOKEN ANDROID_KEYSTORE_BASE64 VERSION_CODE].any? { |key| job['env'].key?(key) } }, 'credentials or version override inherited')
    assert(f.calls.size == 5, 'static checks duplicated')
    assert(before == File.binread(File.join(f.root, '.git/index')), 'caller index changed')
    assert(output.include?('[validation] passed='), output)
  end

  test('docs-only plan is inspectable without executing native jobs or analyzers') do |f|
    log = base(f)
    f.git('restore', '--staged', '--worktree', 'android-app/src/HomePresenter.kt')
    f.write('docs/new.md', '# Notes')
    f.stage
    ok, output = f.run('./scripts/dev/check.sh', '--plan')
    assert(ok && JSON.parse(output)['jobs'].empty?, output)
    assert(f.calls.empty? && jobs(log).empty?, 'plan executed work')
    ok, output = f.run('./scripts/dev/check.sh')
    assert(ok && jobs(log).empty? && f.calls.size == 5, output)
  end

  test('full validation executes every selected job exactly once') do |f|
    log = base(f)
    f.write('unexpected.txt', 'full validation')
    f.stage
    ok, output = f.run('./scripts/dev/check.sh')
    assert(ok, output)
    assert(jobs(log).map { |job| job['job'] } == %w[android-test ios-test android-build-debug ios-build-debug], jobs(log).inspect)
    assert(f.calls.size == 5, 'static checks duplicated')
  end

  test('native behavior changes run affected tests without extra packaging') do |f|
    log = base(f)
    f.write('ios-app/src/HomeFeature.swift', 'struct HomeFeature {}')
    f.stage
    ok, output = f.run('./scripts/dev/check.sh')
    assert(ok && jobs(log).map { |job| job['job'] } == %w[android-test ios-test], output)
  end

  test('both manifests, dependencies and unknown paths select all four jobs once') do |f|
    base(f)
    %w[android-app/module.yaml ios-app/module.yaml quality-tools.json unexpected.txt].each do |path|
      f.git('restore', '--staged', '--worktree', '.')
      if File.file?(File.join(f.root, path))
        File.open(File.join(f.root, path), 'a') { |file| file.puts(path.end_with?('.json') ? ' ' : '# change') }
      else
        f.write(path, path.end_with?('.yaml') ? "product: ios/app\n" : 'new')
      end
      f.stage
      assert(plan(f)['jobs'] == %w[android-test ios-test android-build-debug ios-build-debug], path)
    end
  end

  test('rename to docs retains deleted behavior path and exact unusual paths') do |f|
    base(f)
    f.git('restore', '--staged', '--worktree', '.')
    FileUtils.mkdir_p(File.join(f.root, 'docs'))
    f.git('mv', 'android-app/src/HomePresenter.kt', "docs/renamed\nfile.md")
    data = plan(f)
    assert(data['paths'].include?('android-app/src/HomePresenter.kt') && data['paths'].include?("docs/renamed\nfile.md"), data.inspect)
    assert(data['jobs'] == ['android-test'], data.inspect)
  end

  test('new test-bearing module is discovered and uncovered test targets fail explicitly') do |f|
    base(f)
    f.write('project.yaml', "modules: [feature, android-app, new-module]\n")
    f.write('new-module/module.yaml', "product:\n  type: kmp/lib\n  platforms: [android, iosArm64]\n")
    f.write('new-module/test@android/AddedTest.kt', 'class AddedTest')
    f.stage
    assert(plan(f)['host_test_modules'] == %w[android-app new-module], 'new module omitted')
    f.write('new-module/test@ios/NativeTest.kt', 'class NativeTest')
    f.stage
    begin
      plan(f)
      raise 'uncovered tests accepted'
    rescue Quality::Failure => error
      assert(error.message.include?('Uncovered Kotlin test target'), error.message)
    end
  end

  test('ignored unstaged tests do not enter the staged validation plan') do |f|
    base(f)
    f.write('project.yaml', "modules: [feature, android-app, new-module]\n")
    f.write('new-module/module.yaml', "product: android/lib\n")
    File.open(File.join(f.root, '.gitignore'), 'a') { |file| file.puts 'new-module/test/IgnoredTest.kt' }
    f.write('new-module/test/IgnoredTest.kt', 'class IgnoredTest')
    f.stage
    assert(plan(f)['host_test_modules'] == ['android-app'], 'unstaged ignored tests changed the plan')
  end

  test('job failure stops remaining jobs and removes only the owned copy') do |f|
    log = base(f, 'exit 17')
    f.write('unexpected.txt', 'full')
    f.stage
    ok, output = f.run('./scripts/dev/check.sh')
    assert(!ok && output.include?('Validation job failed: android-test') && !output.include?('[validation] passed='), output)
    assert(jobs(log).size == 1 && !Dir.exist?(jobs(log).first['cwd']), 'remaining job ran or copy leaked')
    assert(File.read(File.join(f.root, 'unexpected.txt')) == 'full', 'caller changed')
  end

  test('snapshot content mutation rejects a successful child') do |f|
    log = base(f, "File.write('android-app/module.yaml', 'changed')")
    ok, output = f.run('./scripts/dev/check.sh')
    assert(!ok && output.include?('Snapshot inputs changed') && !output.include?('[validation] passed='), output)
    assert(!Dir.exist?(jobs(log).first['cwd']), 'drift copy leaked')
    assert(File.read(File.join(f.root, 'android-app/module.yaml')).include?('versionCode: 42'), 'caller metadata changed')
  end

  test('transient shutdown metadata does not invalidate successful jobs and caller stays intact') do |f|
    log = base(f)
    program = <<~RUBY
      require './scripts/dev/validate'
      FileUtils.singleton_class.prepend(Module.new do
        def remove_entry_secure(path, *args)
          if File.basename(path).start_with?('mobi-validation-') && !@retried_owned_cleanup
            @retried_owned_cleanup = true
            FileUtils.mkdir_p(File.join(path, '.gradle-user-home/daemon'))
            File.write(File.join(path, '.gradle-user-home/daemon/registry.bin'), 'shutdown')
            raise Errno::ENOTEMPTY, path
          end
          super
        end
      end)
      Precommit::Runner.new(Precommit::Plan.new).run
    RUBY
    ok, output = f.run(QualityTest::RUBY, '-e', program)
    assert(ok && output.include?('[validation] passed='), output)
    assert(jobs(log).size == 1 && !Dir.exist?(jobs(log).first['cwd']), 'copy not removed after transient cleanup failure')
    assert(File.read(File.join(f.root, 'android-app/src/HomePresenter.kt')).include?('value = 1'), 'caller changed')
  end

  test('persistent cleanup failure is bounded and retains the owned recovery path without a pass') do |f|
    log = base(f)
    program = <<~RUBY
      require './scripts/dev/validate'
      FileUtils.singleton_class.prepend(Module.new do
        def remove_entry_secure(path, *args)
          raise Errno::ENOTEMPTY, path if File.basename(path).start_with?('mobi-validation-')
          super
        end
      end)
      Precommit::Runner.new(Precommit::Plan.new, cleanup_timeout: 0.1).run
    RUBY
    begin
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      ok, output = f.run(QualityTest::RUBY, '-e', program)
      assert(!ok && output.include?('Cleanup incomplete:') && !output.include?('[validation] passed='), output)
      owned = jobs(log).first.fetch('cwd')
      reported = output.lines.find { |line| line.start_with?('[validation] workspace=') }.split('=', 2).last.strip
      assert(output.include?("Cleanup incomplete: #{reported}") && Dir.exist?(owned) && File.realpath(reported) == File.realpath(owned), 'recovery path missing')
      assert(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started < 10, 'cleanup retry not bounded')
    ensure
      jobs(log).each { |job| FileUtils.remove_entry_secure(job['cwd']) if Dir.exist?(job['cwd']) }
    end
  end

  test('snapshot mode mutation rejects a successful child') do |f|
    base(f, "File.chmod(0755, 'android-app/module.yaml')")
    ok, output = f.run('./scripts/dev/check.sh')
    assert(!ok && output.include?('Snapshot inputs changed'), output)
  end

  test('shutdown stops each installed version using only the owned registry and pinned Java') do |f|
    shutdown_log = File.join(File.dirname(f.root), 'shutdown.jsonl')
    caller_home = File.join(File.dirname(f.root), 'caller-gradle')
    FileUtils.mkdir_p(caller_home)
    File.write(File.join(caller_home, 'sentinel'), 'preserve')
    log = base(f, gradle_fixture(shutdown_log, versions: %w[8.14.3 9.6.1]))
    ok, output = f.run('./scripts/dev/check.sh', extra_env: { 'GRADLE_USER_HOME' => caller_home, 'GITHUB_TOKEN' => 'fixture-secret' })
    assert(ok && output.include?('[validation] passed='), output)
    records = jobs(shutdown_log)
    assert(records.size == 2, records.inspect)
    records.each do |record|
      owned_home = File.join(record.fetch('cwd'), '.gradle-user-home')
      assert(record['args'] == ['--gradle-user-home', record['env']['GRADLE_USER_HOME'], '--offline', '--stop'], record.inspect)
      assert(File.expand_path(record['env']['GRADLE_USER_HOME']).sub(%r{\A/private/var/}, '/var/') == owned_home.sub(%r{\A/private/var/}, '/var/'), 'shutdown escaped owned home')
      assert(record['env']['JAVA_HOME'] == PinnedQuality::Toolchain.new(f.root).slot, 'shutdown did not use pinned Java')
      assert(!record['env'].key?('GITHUB_TOKEN'), 'shutdown inherited credentials')
    end
    assert(!Dir.exist?(jobs(log).first['cwd']), 'copy leaked')
    assert(File.read(File.join(caller_home, 'sentinel')) == 'preserve', 'caller Gradle home changed')
  end

  test('shutdown failure retains the owned workspace and cannot report success') do |f|
    shutdown_log = File.join(File.dirname(f.root), 'shutdown.jsonl')
    log = base(f, gradle_fixture(shutdown_log, action: 'exit 17'))
    begin
      ok, output = f.run('./scripts/dev/check.sh')
      assert(!ok && output.include?('Gradle shutdown failed: 8.14.3') && !output.include?('[validation] passed='), output)
      assert(Dir.exist?(jobs(log).first['cwd']) && output.include?('snapshot retained at'), 'recovery path not retained')
    ensure
      remove_retained_copy(log)
    end
  end

  test('shutdown timeout terminates its child and retains the workspace for recovery') do |f|
    shutdown_log = File.join(File.dirname(f.root), 'shutdown.jsonl')
    log = base(f, gradle_fixture(shutdown_log, action: "trap('TERM') { }; sleep 60"))
    begin
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      program = "require './scripts/dev/validate'; Precommit::Runner.new(Precommit::Plan.new, shutdown_timeout: 1).run"
      ok, output = f.run(QualityTest::RUBY, '-e', program)
      assert(!ok && output.include?('Gradle shutdown interrupted or timed out') && !output.include?('[validation] passed='), output)
      assert(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started < 15, 'shutdown not bounded')
      assert(Dir.exist?(jobs(log).first['cwd']), 'recovery copy missing')
      begin
        Process.kill(0, jobs(shutdown_log).first.fetch('pid'))
        raise 'timed out shutdown child survived'
      rescue Errno::ESRCH
        nil
      end
    ensure
      remove_retained_copy(log)
    end
  end

  test('missing or escaping launchers fail without falling back to PATH Gradle') do |f|
    shutdown_log = File.join(File.dirname(f.root), 'shutdown.jsonl')
    path_gradle = File.join(f.env.fetch('PATH').split(':').first, 'gradle')
    File.write(path_gradle, "#!#{QualityTest::RUBY}\nFile.write(#{shutdown_log.inspect}, 'forbidden')\n")
    File.chmod(0755, path_gradle)
    %w[missing symlink].each do |kind|
      action = <<~RUBY
        require 'fileutils'
        home = ENV.fetch('GRADLE_USER_HOME')
        FileUtils.mkdir_p(File.join(home, 'daemon/8.14.3'))
        if #{kind.inspect} == 'symlink'
          launcher = File.join(home, 'wrapper/dists/gradle-8.14.3-bin/fixture/gradle-8.14.3/bin/gradle')
          FileUtils.mkdir_p(File.dirname(launcher))
          File.symlink(#{path_gradle.inspect}, launcher)
        end
      RUBY
      log = base(f, action)
      begin
        ok, output = f.run('./scripts/dev/check.sh')
        assert(!ok && output.include?('installed launcher missing') && !output.include?('[validation] passed='), output)
        assert(Dir.exist?(jobs(log).last['cwd']) && !File.exist?(shutdown_log), 'unowned launcher ran or recovery copy missing')
      ensure
        remove_retained_copy(log)
      end
    end
  end

  test('shutdown refuses a registry redirected outside the owned workspace') do |f|
    caller_registry = File.join(File.dirname(f.root), 'caller-daemon')
    FileUtils.mkdir_p(File.join(caller_registry, '8.14.3'))
    File.write(File.join(caller_registry, 'sentinel'), 'preserve')
    action = "File.symlink(#{caller_registry.inspect}, File.join(ENV.fetch('GRADLE_USER_HOME'), 'daemon'))"
    log = base(f, action)
    begin
      ok, output = f.run('./scripts/dev/check.sh')
      assert(!ok && output.include?('Gradle registry escaped owned workspace') && !output.include?('[validation] passed='), output)
      assert(Dir.exist?(jobs(log).first['cwd']), 'recovery copy missing')
      assert(File.read(File.join(caller_registry, 'sentinel')) == 'preserve', 'caller registry changed')
    ensure
      remove_retained_copy(log)
    end
  end

  test('new authored source in the copy invalidates native success') do |f|
    base(f, "File.write('android-app/src/Unreviewed.kt', 'class Unreviewed')")
    ok, output = f.run('./scripts/dev/check.sh')
    assert(!ok && output.include?('Unexpected authored source in snapshot'), output)
  end

  test('same-stat caller changes invalidate native success') do |f|
    target = File.join(f.root, 'android-app/src/HomePresenter.kt')
    base(f, "path = #{target.inspect}; stat = File.stat(path); File.write(path, File.read(path).sub('value', 'other')); File.utime(stat.atime, stat.mtime, path)")
    ok, output = f.run('./scripts/dev/check.sh')
    assert(!ok && output.include?('Index/checkout mismatch') && !output.include?('[validation] passed='), output)
  end

  test('caller index mutation invalidates native success') do |f|
    base(f, "system('git', '-C', #{f.root.inspect}, 'update-index', '--chmod=+x', 'android-app/module.yaml') or abort 'fixture failed'")
    ok, output = f.run('./scripts/dev/check.sh')
    assert(!ok && output.include?('Index/checkout mismatch') && !output.include?('[validation] passed='), output)
  end

  test('base commit changes invalidate an unchanged index') do |f|
    base(f, "system('git', '-C', #{f.root.inspect}, 'reset', '--soft', 'HEAD^') or abort 'fixture failed'")
    f.git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '--quiet', '--no-verify', '-m', 'second base')
    f.write('android-app/src/HomePresenter.kt', "class HomePresenter { val value = 2 }\n")
    f.stage
    ok, output = f.run('./scripts/dev/check.sh')
    assert(!ok && output.include?('base commit changed') && !output.include?('[validation] passed='), output)
  end

  test('copied bytes and captured index must match the planned Git objects') do |f|
    base(f)
    Dir.chdir(f.root) do
      runner = Precommit::Runner.new(Precommit::Plan.new)
      entries = f.git('ls-files', '--stage', '-z')
      flags = f.git('ls-files', '-v', '-z')
      f.write('android-app/src/HomePresenter.kt', 'temporary mutation')
      begin
        runner.verify_index_copy!(f.root, entries, flags, 'sha1')
        raise 'copied content not bound to Git objects'
      rescue Quality::Failure => error
        assert(error.message.include?('differs from staged Git object'), error.message)
      end
      begin
        runner.verify_index_copy!(f.root, entries + 'changed', flags, 'sha1')
        raise 'changed index accepted'
      rescue Quality::Failure => error
        assert(error.message.include?('Captured index differs'), error.message)
      end
    end
  end

  test('timeout terminates an uncooperative child and cleans the snapshot') do |f|
    log = base(f, "trap('TERM') { }; sleep 60")
    program = "require './scripts/dev/validate'; Precommit::Runner.new(Precommit::Plan.new, job_timeout: 1).run"
    ok, output = f.run(QualityTest::RUBY, '-e', program)
    assert(!ok && output.include?('timed out'), output)
    assert(jobs(log).size == 1, "timeout fixture did not start exactly one child: #{jobs(log).inspect}\n#{output}")
    assert(!Dir.exist?(jobs(log).first['cwd']), 'timeout snapshot leaked')
    begin
      Process.kill(0, jobs(log).first.fetch('pid'))
      raise 'timed out child survived'
    rescue Errno::ESRCH
      nil
    end
  end

  test('TERM interruption terminates children and cleans the snapshot') do |f|
    log = base(f, "trap('TERM') { }; sleep 60")
    program = "require './scripts/dev/validate'; trap('TERM') { raise Interrupt }; " \
              "Thread.new { sleep 0.05 until File.exist?(#{log.inspect}); Process.kill('TERM', Process.pid) }; " \
              "Precommit::Runner.new(Precommit::Plan.new).run"
    ok, output = f.run(QualityTest::RUBY, '-e', program)
    assert(!ok && output.include?('interrupted'), output)
    assert(jobs(log).size == 1 && !Dir.exist?(jobs(log).first['cwd']), 'interrupted snapshot leaked')
  end

  test('Android test preparation preserves versions, avoids Bundler and ignores release signing') do |f|
    f.copy('scripts/ci/run_job.sh')
    f.copy('scripts/ci/run_android_tests.sh')
    f.write('kotlin', "#!/bin/sh\nexit 0\n")
    File.chmod(0o755, File.join(f.root, 'kotlin'))
    f.write('android-app/module.yaml', "product: android/app\nsettings: {android: {versionCode: 42, versionName: reviewed}}\n")
    log = File.join(File.dirname(f.root), 'prep.log')
    fake = File.join(f.root, 'scripts/ci/lib/android.sh')
    File.open(fake, 'a') do |file|
      file.puts <<~SH
        ci_detect_context() { :; }
        ci_prepare_workspace() { :; }
        ci_set_java_home() { :; }
        ci_resolve_android_sdk_root() { :; }
        ci_configure_path() { :; }
        ci_log_android_sdk_env() { :; }
        ci_bundle_install() { echo forbidden-bundle; exit 19; }
      SH
    end
    %w[apply_android_version write_android_signing_files].each do |name|
      f.write("scripts/ci/#{name}.sh", "#!/bin/sh\necho forbidden; exit 19\n")
    end
    f.write('scripts/ci/ensure_android_debug_signing_files.sh', "#!/bin/sh\nprintf debug >> #{log.inspect}\n")
    f.write('scripts/ci/run_android_tests.sh', "#!/bin/sh\nprintf test >> #{log.inspect}\n")
    Dir.glob(File.join(f.root, 'scripts/ci/*.sh')).each { |path| File.chmod(0o755, path) }
    before = File.binread(File.join(f.root, 'android-app/module.yaml'))
    ok, output = f.run('./scripts/ci/run_job.sh', 'android-test', extra_env: { 'VERSION_CODE' => '999', 'ANDROID_KEYSTORE_BASE64' => 'unused' })
    assert(ok && File.read(log) == 'debugtest', output)
    assert(before == File.binread(File.join(f.root, 'android-app/module.yaml')), 'version metadata changed')
  end

  test('validation refuses to provision a simulator when none is available') do |f|
    bin = f.env.fetch('PATH').split(':').first
    File.write(File.join(bin, 'xcrun'), "#!/bin/sh\n[ \"$1 $2 $3 $4\" = 'simctl list devices available' ] || exit 19\nprintf '{\"devices\":{}}'\n")
    File.chmod(0o755, File.join(bin, 'xcrun'))
    ok, output = f.run('bash', '-c', 'source scripts/ci/lib/xcode.sh; ci_resolve_ios_simulator_destination', extra_env: { 'MOBI_VALIDATION' => '1' })
    assert(!ok && output.include?('existing available iPhone simulator'), output)
  end

  def self.run
    failures = []
    @tests.each do |name, block|
      Dir.mktmpdir('mobi-validation-test-') do |temp|
        begin
          block.call(QualityTest::Fixture.new(temp))
          puts "PASS #{name}"
        rescue StandardError => error
          failures << name
          warn "FAIL #{name}: #{error.message}"
        end
      end
    end
    puts "#{@tests.size} validation tests, #{failures.size} failures"
    exit(failures.empty? ? 0 : 1)
  end
end

ValidationTest.run if $PROGRAM_NAME == __FILE__
