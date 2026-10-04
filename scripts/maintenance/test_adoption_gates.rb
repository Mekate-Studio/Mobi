# frozen_string_literal: true

require_relative 'adapters/upstream_remediation'
require_relative 'kotlin_check'
require_relative 'lib/executor'

tests = []
tests << ['unknown or combined packaging profiles refuse before prerequisites', lambda do
  %w[packaging bogus].each do |profile|
    begin
      Maintenance::UpstreamRemediationRehearsal.new(Dir.pwd, source: nil, profile: profile)
      raise 'Accepted unsupported profile'
    rescue Maintenance::Failure => error
      raise unless error.message.include?('Use upstream profile')
    end
  end
end]
tests << ['native profiles require the explicit reviewed SDK patch', lambda do
  %w[mobile android-packaging ios-release ios-archive].each do |profile|
    begin
      Maintenance::UpstreamRemediationRehearsal.new(Dir.pwd, source: nil, profile: profile)
      raise 'Accepted native rehearsal without reviewed patch'
    rescue Maintenance::Failure => error
      raise unless error.message.include?('compile SDK 37 patch')
    end
  end
end]
tests << ['private provisioning and macro setup preserve the host SDK in both phases', lambda do
  %w[baseline candidate].each do |phase|
    Dir.mktmpdir('mobi-adoption-setup-') do |root|
      store = Maintenance::RunStore.new(File.join(root, 'runs')); journal = store.allocate(SecureRandom.hex(16), {}, {})
      work = store.directory(journal, 'work/' + phase); control = store.directory(journal, 'steps/setup', disposable: false)
      %w[source output cache home tmp].each { |name| Dir.mkdir(File.join(work, name)) }
      source = File.join(work, 'source'); File.write(File.join(source, 'project.yaml'), "modules: [app]\n")
      File.write(File.join(source, 'kotlin'), "kotlin_cli_version=0.13.0\n")
      sdk = File.join(root, 'sdk'); %w[platforms/android-36 platforms/android-37.0 build-tools/37.0.0 licenses].each { |path| FileUtils.mkdir_p(File.join(sdk, path)) }
      File.write(File.join(sdk, 'platforms/android-37.0/android.jar'), 'fixture'); File.write(File.join(sdk, 'licenses/android-sdk-license'), 'accepted fixture')
      nonce = SecureRandom.hex(16); Maintenance::KotlinResources.prepare(control: control, workspace: work, nonce: nonce)
      host = File.join(root, 'host.json'); File.write(host, JSON.generate('ruby' => RbConfig.ruby, 'android_sdk' => sdk, 'java_home' => '/usr', 'developer_dir' => '/usr', 'required_ios_major' => 26, 'macro_validation' => 'NO', 'cold_candidate_compile_sdk' => 37))
      before = ENV.to_h
      begin
        ENV.replace('PATH' => '/usr/bin:/bin', 'HOME' => File.join(work, 'home'), 'TMPDIR' => File.join(work, 'tmp'), 'MOBI_PHASE' => phase, 'MOBI_RESOURCE_NONCE' => nonce, 'MOBI_RESULT_PATH' => File.join(control, 'check.json'), 'SKIP_MACRO_VALIDATION' => 'YES')
        check = Maintenance::KotlinCheck.new(source, File.join(work, 'output'), File.join(work, 'cache'), host, 'mobile')
        check.native_setup(simulator: false)
        raise 'Host SDK mutated' unless File.read(File.join(sdk, 'platforms/android-37.0/android.jar')) == 'fixture'
        private_37 = File.join(work, 'output/android-sdk/platforms/android-37.0/android.jar')
        raise 'Private provisioning state wrong' unless File.exist?(private_37) == (phase == 'baseline')
        raise 'Macro validation skipped' unless check.report.dig('environment', 'macro_validation') == 'enabled'
        raise 'License state lost' unless File.read(File.join(work, 'output/android-sdk/licenses/android-sdk-license')) == 'accepted fixture'
      ensure
        ENV.replace(before)
      end
    end
  end
end]

failures = 0
tests.each do |name, test|
  test.call
  puts 'PASS ' + name
rescue StandardError => error
  failures += 1; warn 'FAIL ' + name + ': ' + error.message
end
puts "#{tests.size} adoption gate contracts, #{failures} failures"
exit(failures.zero? ? 0 : 1)
