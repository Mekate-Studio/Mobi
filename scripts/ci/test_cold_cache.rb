# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'tmpdir'
require 'yaml'

module ColdCacheTest
  ROOT = File.expand_path('../..', __dir__)

  def self.assert(value, message)
    raise message unless value
  end

  def self.with_project
    Dir.mktmpdir('mobi-cold-') do |temp|
      project = File.join(temp, 'project with spaces')
      FileUtils.mkdir_p(File.join(project, 'scripts'))
      FileUtils.cp_r(File.join(ROOT, 'scripts/ci'), File.join(project, 'scripts'))
      FileUtils.mkdir_p(File.join(project, 'ios-app/tests'))
      FileUtils.cp_r(File.join(ROOT, 'ios-app/module.xcodeproj'), File.join(project, 'ios-app'))
      FileUtils.cp_r(File.join(ROOT, 'ios-app/tests/Plans'), File.join(project, 'ios-app/tests'))
      env = { 'PATH' => '/usr/bin:/bin:/usr/sbin:/sbin', 'HOME' => temp, 'LANG' => 'en_US.UTF-8' }
      yield project, env
    end
  end

  with_project do |project, env|
    stale = File.join(project, '.kotlin-cache/previous.zip')
    FileUtils.mkdir_p(File.dirname(stale)); File.write(stale, 'keep this input')
    output, status = Open3.capture2e(env, '/bin/bash', File.join(project, 'scripts/ci/cold_cache_preflight.sh'), unsetenv_others: true)
    assert(!status.success? && output.include?('.kotlin-cache'), "Existing dependency cache accepted: #{output}")
    assert(File.read(stale) == 'keep this input', 'Preflight removed an existing cache')
  end
  with_project do |project, env|
    output, status = Open3.capture2e(env, '/bin/bash', File.join(project, 'scripts/ci/cold_cache_preflight.sh'), chdir: '/', unsetenv_others: true)
    assert(status.success?, "Fresh checkout refused: #{output}")
    assert(File.read(File.join(project, 'build/logs/cold-cache/preflight.log')).include?('Verified absent before setup: build'), 'Missing startup receipt')
  end
  with_project do |project, env|
    File.write(File.join(project, 'kotlin'), "#!/bin/bash\nexit 0\n"); FileUtils.chmod(0o755, File.join(project, 'kotlin'))
    inherited = File.join(project, 'inherited-cache')
    settings = env.merge('CI_PROJECT_DIR' => project, 'MOBI_VALIDATION' => '1', 'MOBI_COLD_VALIDATION' => '1',
                         'KOTLIN_CLI_BOOTSTRAP_CACHE_DIR' => inherited, 'KOTLIN_CLI_USER_HOME' => inherited, 'GRADLE_USER_HOME' => inherited, 'KONAN_DATA_DIR' => inherited)
    script = 'source "$1"; ci_prepare_workspace; printf "CACHES:%s\\n" "$KOTLIN_CLI_BOOTSTRAP_CACHE_DIR" "$KOTLIN_CLI_USER_HOME" "$GRADLE_USER_HOME" "$KONAN_DATA_DIR"'
    output, status = Open3.capture2e(settings, '/bin/bash', '-c', script, '_', File.join(project, 'scripts/ci/lib/common.sh'), unsetenv_others: true)
    assert(status.success?, "Cold workspace preparation failed: #{output}")
    %w[.kotlin-cache .kotlin-user-home .gradle-user-home build/cold-cache/konan].each do |path|
      assert(output.include?('CACHES:' + File.join(project, path)), "Cache escaped the cold workspace: #{output}")
    end
    assert(!File.exist?(inherited), 'Cold mode wrote an inherited cache')
  end
  %w[run_xcodebuild_with_logs.sh run_xcode_tests_with_logs.sh].each do |wrapper|
    with_project do |project, env|
      bin = File.join(project, 'fake-bin'); FileUtils.mkdir_p(bin)
      File.write(File.join(bin, 'xcodebuild'), "#!/bin/bash\nprintf '%s\\n' \"$@\" > \"$CAPTURE_PATH\"\n")
      FileUtils.chmod(0o755, File.join(bin, 'xcodebuild'))
      %w[0 1].each do |cold|
        capture = File.join(project, 'arguments')
        settings = env.merge('PATH' => bin + ':' + env.fetch('PATH'), 'CI_PROJECT_DIR' => project,
                             'MOBI_COLD_VALIDATION' => cold, 'CAPTURE_PATH' => capture,
                             'IOS_SIMULATOR_DESTINATION' => 'platform=iOS Simulator,id=fixture', 'SKIP_MACRO_VALIDATION' => 'NO')
        args = ['/bin/bash', File.join(project, 'scripts/ci', wrapper)]
        args << 'Debug' if wrapper == 'run_xcodebuild_with_logs.sh'
        output, status = Open3.capture2e(settings, *args, unsetenv_others: true)
        assert(status.success?, "Xcode wrapper failed: #{output}")
        actual = File.readlines(capture, chomp: true)
        if cold == '1'
          assert(actual.include?('-disablePackageRepositoryCache'), "Shared package cache still enabled: #{wrapper}")
          index = actual.index('-packageCachePath')
          assert(index && actual[index + 1] == File.join(project, 'build/cold-cache/swiftpm'), 'Package cache path was split or escaped')
        else
          assert(!actual.include?('-packageCachePath') && !actual.include?('-disablePackageRepositoryCache'), 'Normal Xcode package behavior changed')
        end
      end
    end
  end
  with_project do |project, env|
    workflow = YAML.safe_load(File.read(File.join(ROOT, '.github/workflows/mobile-ci.yml')))
    step = workflow.fetch('jobs').fetch('classify').fetch('steps').find { |item| item['id'] == 'changes' }.fetch('run')
    bin = File.join(project, 'fake-bin'); FileUtils.mkdir_p(bin)
    File.write(File.join(bin, 'git'), "#!/bin/bash\n[[ \"$1\" == diff ]]\nprintf 'README.md\\0'\n")
    FileUtils.chmod(0o755, File.join(bin, 'git'))
    %w[0 1].each do |cold|
      settings = env.merge('PATH' => bin + ':' + env.fetch('PATH'), 'MOBI_COLD_VALIDATION' => cold,
                           'PR_BASE_SHA' => 'base', 'PR_HEAD_SHA' => 'head')
      output, status = Open3.capture2e(settings, '/bin/bash', '-eu', '-c', step, chdir: project, unsetenv_others: true)
      assert(status.success?, "Workflow classification failed: #{output}")
      assert(output.include?('full_validation=' + (cold == '1').to_s), "Manual cold scope was skipped or normal scope broadened: #{output}")
      assert(output.include?('docs_only=' + (cold == '0').to_s), "Documentation classification changed: #{output}")
    end
  end
  puts 'Cold-cache contracts passed'
end
