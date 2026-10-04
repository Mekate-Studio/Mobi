# frozen_string_literal: true

require_relative 'kotlin_rehearsal'
require_relative 'compatibility'
require_relative '../lib/direct_resolution'

module Maintenance
  class UpstreamRemediationRehearsal < KotlinRehearsal
    def self.sdk_edits(source, sdk)
      return [] if sdk.nil?
      raise Failure, 'Only the reviewed compile SDK 37 remediation is supported' unless sdk == 37
      path = 'android-app/module.yaml'
      before = File.read(File.join(source.root, path))
      android = YAML.safe_load(before).fetch('settings').fetch('android')
      unless android.values_at('compileSdk', 'minSdk', 'targetSdk') == [36, 36, 36] && before.scan(/^    compileSdk: 36$/).size == 1
        raise Failure, 'Android compile/minimum/target declarations differ from reviewed remediation baseline'
      end
      after = before.sub(/^    compileSdk: 36$/, '    compileSdk: 37')
      [{ 'path' => path, 'before_sha256' => source.files.fetch(path)['sha256'], 'content' => after, 'after_sha256' => Digest::SHA256.hexdigest(after) }]
    end

    def self.xcode_ready!(developer_dir, runner: Open3.method(:capture3))
      _out, _error, status = runner.call({ 'PATH' => '/usr/bin:/bin', 'DEVELOPER_DIR' => developer_dir }, '/usr/bin/xcodebuild', '-checkFirstLaunchStatus', unsetenv_others: true)
      raise Failure, 'Xcode first-launch readiness is missing; complete approved host setup before a full upstream rehearsal' unless status.success?
    end

    PROFILES = %w[build-inputs mobile android-packaging ios-release ios-archive].freeze

    def initialize(root, source:, experimental: false, compile_sdk: nil, profile: 'build-inputs')
      raise Failure, 'Use upstream profile build-inputs, mobile, android-packaging, ios-release or ios-archive' unless PROFILES.include?(profile)
      raise Failure, 'Native adoption gates require the reviewed compile SDK 37 patch' if profile != 'build-inputs' && compile_sdk != 37
      wrappers = KotlinWrappers.new(root)
      raise Failure, 'Upstream assessment requires one reviewed candidate' unless wrappers.pins['candidates'].size == 1
      candidate = wrappers.pins['candidates'].first
      selection = wrappers.selection(candidate, experimental: experimental)
      raise Failure, 'Compile SDK remediation is reviewed only for Toolchain 0.13.0' if compile_sdk && candidate != '0.13.0'
      sdk_edits = self.class.sdk_edits(source, compile_sdk)
      raise Failure, 'Unsupported upstream compiler producer' unless [wrappers.pins['baseline'], candidate].all? { |v| BuildInputs::COMPILERS.key?(v) }
      super(root, source: source, candidate: candidate, profile: 'mobile', target_policy: 'apple-silicon', experimental: experimental)
      host = JSON.parse(File.read(@host_file)).merge('upstream_selection' => selection)
      if profile != 'build-inputs'
        major = MobileSupport.new(source.root).declarations.fetch('swift_package_minimum').split('.').first.to_i
        host.merge!('required_ios_major' => major, 'macro_validation' => 'NO')
        host['cold_candidate_compile_sdk'] = 37 if %w[mobile android-packaging].include?(profile)
      end
      self.class.xcode_ready!(host.fetch('developer_dir')) if candidate == '0.13.0'
      @host_file = File.join(File.dirname(@host_file), Maintenance.digest(host) + '.json')
      raise Failure, 'Symlinked upstream host input' if File.symlink?(@host_file)
      RunStore.atomic(@host_file, host)
      @files += [__FILE__, @host_file, File.join(root, Compatibility::CONFIG)]
      @files += Dir.glob(File.join(root, 'scripts/maintenance/{lib,adapters}/**/*')).select { |p| File.file?(p) }
      @files << File.join(root, 'scripts/maintenance/compatibility_check.rb')
      @plan['edits'] += sdk_edits
      @plan.merge!('id' => 'compatibility-upstream-' + profile, 'scope' => 'retained_bridge_upstream_' + profile.tr('-', '_'),
                   'missing_capabilities' => Compatibility::UNPROVEN + DirectResolution::GAPS + BuildInputs::GAPS + %w[swiftpm_execution retirement_approval] + (selection['age_state'] == 'age_blocked' ? ['release_age'] : []),
                   'checks' => [{ 'id' => 'upstream-' + profile, 'required' => true, 'timeout_seconds' => 2400,
                                  'argv' => [File.realpath(RbConfig.ruby), File.join(root, 'scripts/maintenance/compatibility_check.rb'), '{source}', '{output}', '{cache}', @host_file, 'upstream-' + profile] }])
    end
  end
end
