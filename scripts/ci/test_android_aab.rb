# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'tmpdir'

# Exercise the helper with a stand-in for the external Toolchain executable.
module AndroidAabTest
  ROOT = File.expand_path('../..', __dir__)
  PUBLISHED = 'build/releases/android/android-app-release.aab'

  def self.assert(value, message)
    raise message unless value
  end

  def self.package(project, env)
    Open3.capture2e(env, '/bin/bash', File.join(project, 'scripts/ci/build_android_aab.sh'), chdir: '/', unsetenv_others: true)
  end

  def self.with_project
    Dir.mktmpdir('mobi-aab-') do |temp|
      project = File.join(temp, 'project with spaces')
      FileUtils.mkdir_p(File.join(project, 'scripts/ci'))
      %w[build_android_aab.sh run_kotlin_with_logs.sh print_recent_logs.sh].each do |script|
        FileUtils.cp(File.join(ROOT, 'scripts/ci', script), File.join(project, 'scripts/ci', script))
      end
      File.write(File.join(project, 'kotlin'), <<~'SH')
        #!/usr/bin/env bash
        set -eu
        [[ "$*" == 'package -m android-app' ]]
        [[ -f android-app/keystore.properties ]]
        mkdir -p build/tasks/_android-app_bundleAndroid
        mkdir -p build/tasks/_android-app_bundleAndroid/gradle-project/build/intermediates
        printf 'intermediate bundle' > build/tasks/_android-app_bundleAndroid/gradle-project/build/intermediates/intermediary-bundle.aab
        printf 'packaged bundle' > build/tasks/_android-app_bundleAndroid/gradle-project-release.aab
      SH
      FileUtils.chmod(0o755, File.join(project, 'kotlin'))
      FileUtils.mkdir_p(File.join(project, 'android-app'))
      File.write(File.join(project, 'android-app/keystore.properties'), 'fixture signing config')
      env = { 'PATH' => '/usr/bin:/bin:/usr/sbin:/sbin', 'HOME' => temp, 'LANG' => 'en_US.UTF-8' }
      yield project, env
    end
  end
  with_project do |project, env|
    File.write(File.join(project, 'kotlin'), <<~'SH')
      #!/bin/bash
      set -eu
      mkdir -p build/tasks/_android-app_bundleAndroid
      printf 'redirected bundle' > other.aab
      ln -s ../../../other.aab build/tasks/_android-app_bundleAndroid/gradle-project-release.aab
    SH
    output, status = package(project, env)
    assert(!status.success? && output.include?('Android App Bundle'), "Redirected package accepted: #{output}")
    assert(!File.exist?(File.join(project, PUBLISHED)), 'Redirected package was published')
  end

  with_project do |project, env|
    output, status = package(project, env)
    assert(status.success?, "Packaging failed: #{output}")
    assert(File.binread(File.join(project, PUBLISHED)) == 'packaged bundle', 'Published bundle differs')
    assert(File.read(File.join(project, 'android-app/keystore.properties')) == 'fixture signing config', 'Signing config changed')
  end
  with_project do |project, env|
    FileUtils.mkdir_p(File.dirname(File.join(project, PUBLISHED)))
    File.write(File.join(project, PUBLISHED), 'old published bundle')
    File.write(File.join(project, 'kotlin'), "#!/bin/bash\nexit 42\n")
    output, status = package(project, env)
    assert(status.exitstatus == 42, "Toolchain failure lost: #{status.exitstatus}: #{output}")
    assert(!File.exist?(File.join(project, PUBLISHED)), 'Failed package left a stale published bundle')
  end
  with_project do |project, env|
    FileUtils.mkdir_p(File.dirname(File.join(project, PUBLISHED)))
    File.write(File.join(project, PUBLISHED), 'old published bundle')
    File.write(File.join(project, 'kotlin'), "#!/bin/bash\nexit 0\n")
    output, status = package(project, env)
    assert(!status.success? && output.include?('No Android App Bundle'), "Missing package accepted: #{output}")
    assert(!File.exist?(File.join(project, PUBLISHED)), 'Missing package left a stale published bundle')
  end
  %w[GRADLE_BIN ANDROID_AAB_GRADLE_JVM_ARGS ANDROID_AAB_MAX_WORKERS].each do |override|
    with_project do |project, env|
      output, status = package(project, env.merge(override => 'old override'))
      assert(!status.success? && output.include?(override), "Retired override silently ignored: #{override}: #{output}")
    end
  end
  puts 'Android AAB helper contracts passed'
end
