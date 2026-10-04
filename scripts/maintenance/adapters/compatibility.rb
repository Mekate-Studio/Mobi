# frozen_string_literal: true

require_relative '../lib/core'
require_relative '../lib/kotlin_wrappers'
require_relative '../lib/build_inputs'
require 'yaml'
require 'rbconfig'
require 'uri'

module Maintenance
  class Compatibility
    PROFILES = %w[bridge-compile bridge-mobile bridge-review direct-facade direct-roundtrip direct-resolution direct-build-inputs direct-mobile].freeze
    CONFIG = 'maintenance-compatibility.json'
    CATALOG = 'gradle/libs.versions.toml'
    UNPROVEN = %w[device_execution release_archive signed_packaging cancellation_parity generic_export cold_direct_ci clean_clone_onboarding incremental_direct_build local_bridge_rollback complete_release_interval_review complete_bridge_target_graph advisory_review].freeze
    attr_reader :config, :root, :selection

    def initialize(root, now: Time.now.utc, experimental: false)
      @root = root
      raise Failure, 'Experimental mode must be explicit boolean' unless [true, false].include?(experimental)
      @config = JSON.parse(File.read(File.join(root, CONFIG)))
      valid = @config['schema'] == 1 && @config['automatic_adoption'] == false && %w[0.12.2 0.13.0].include?(@config['toolchain']) &&
              @config['minimum_release_age_days'].is_a?(Integer) && @config['minimum_release_age_days'] >= 7
      raise Failure, 'Unsupported compatibility policy' unless valid
      raise Failure, 'Compatibility review timestamp is in the future' if Time.iso8601(@config.fetch('reviewed_at')) > now
      sources = @config.fetch('sources')
      raise Failure, 'Duplicate compatibility source IDs' unless sources.map { |s| s.fetch('id') }.uniq.size == sources.size
      sources.each do |source|
        uri = URI(source.fetch('url'))
        unless uri.scheme == 'https' && uri.host && !uri.userinfo && source.fetch('sha256').match?(/\A[0-9a-f]{64}\z/) && Time.iso8601(source.fetch('retrieved_at')) <= now
          raise Failure, 'Invalid compatibility source evidence'
        end
      end
      observations = @config.fetch('capability_observations', [])
      unless observations.is_a?(Array) && observations.all? { |o| o.is_a?(Hash) && o['id'].to_s.match?(/\A[a-z][a-z0-9-]+\z/) && o['version'].to_s.match?(/\A\d+\.\d+\.\d+\z/) && o['state'] == 'documented_not_rehearsed' && o['scope'] == 'swiftpm_objective_c_visible_api_import_into_kotlin' && o['bridge_retirement'] == 'defer' && o['adoption_authorized'] == false && o['missing_capabilities'].is_a?(Array) && o['missing_capabilities'].include?('swiftpm_execution') && o['sources'].is_a?(Array) && !o['sources'].empty? && (o['sources'] - sources.map { |s| s['id'] }).empty? } && observations.map { |o| o['id'] }.uniq.size == observations.size
        raise Failure, 'Unsupported capability observation; executed claims require a reviewed adapter'
      end
      releases = @config.fetch('candidate').fetch('releases')
      raise Failure, 'Incomplete compatibility tuple' unless releases.keys.sort == %w[kotlin metro skie]
      thresholds = []
      releases.each_value do |release|
        raise Failure, 'Unsupported release version' unless release.fetch('version').match?(/\A\d+\.\d+\.\d+\z/)
        raise Failure, 'Candidate lacks captured release evidence' unless sources.any? { |s| s['id'] == release.fetch('source_id') }
        published = Time.iso8601(release.fetch('published_at'))
        raise Failure, 'Compatibility release publication is in the future' if published > now
        thresholds << published + @config['minimum_release_age_days'] * 86_400
      end
      unless File.file?(File.join(root, CATALOG))
        thresholds = releases.reject { |key, _| key == 'skie' }.values.map { |release| Time.iso8601(release.fetch('published_at')) + @config['minimum_release_age_days'] * 86_400 }
      end
      eligible_at = thresholds.max
      blocked = now < eligible_at
      raise Failure, 'Compatibility candidate is age-blocked' if blocked && !experimental
      @selection = { 'mode' => experimental ? 'experimental' : 'normal', 'age_state' => blocked ? 'age_blocked' : 'age_eligible',
                     'assessed_at' => now.iso8601, 'eligible_at' => eligible_at.iso8601, 'adoption_authorized' => false }
      unless @config.fetch('direct_paths').keys.sort == %w[skie swift-export] && @config['direct_paths'].values.all? { |p| p['status'] == 'missing' && p['reason'].is_a?(String) && !p.fetch('sources').empty? && (p['sources'] - sources.map { |s| s['id'] }).empty? }
        raise Failure, 'Unsupported direct prerequisite assessment; review the adapter before enabling a new path'
      end
    rescue KeyError, ArgumentError, URI::InvalidURIError
      raise Failure, 'Malformed compatibility evidence'
    end

    def assessment(source = Source.new(root))
      verify_baseline!(source)
      result = { 'schema' => 1, 'state' => 'assessed', 'source_sha256' => Maintenance.digest(source.files),
                 'config_sha256' => Maintenance.file_sha(File.join(root, CONFIG)), 'candidate' => config['candidate'],
                 'newer_releases' => config.fetch('newer_releases', []).map { |r| r.merge('age_state' => Time.now.utc - Time.iso8601(r.fetch('published_at')) >= config['minimum_release_age_days'] * 86_400 ? 'age_eligible_unrehearsed' : 'age_blocked') },
                 'direct_paths' => config['direct_paths'], 'capability_observations' => config.fetch('capability_observations', []), 'evidence_kind' => 'reviewed_sources_and_declarations',
                 'missing_capabilities' => UNPROVEN, 'bridge_retirement' => 'defer', 'adoption_authorized' => false }
      source.verify!
      unless source.files.key?(CATALOG)
        result['historical_retained_candidate'] = result['candidate']
        result['candidate'] = { 'releases' => config['candidate']['releases'].reject { |key, _| key == 'skie' } }
        result['baseline_scope'] = 'adopted_direct_development_tests_unsigned'
      end
      result
    end

    def verify_baseline!(source)
      if source.files.key?(CATALOG)
        catalog = File.read(File.join(source.root, CATALOG))
        config.fetch('baseline').each do |key, version|
          raise Failure, 'Bridge baseline differs from reviewed tuple' unless catalog.scan(/^#{Regexp.escape(key)} = "([^"]+)"$/).flatten == [version]
        end
      else
        paths = source.files.keys.select { |p| p.end_with?('/module.yaml') }
        declarations = paths.flat_map { |p| File.read(File.join(source.root, p)).scan(/dev\.zacsweers\.metro:(?:runtime|compiler):([^\s]+)/).flatten }
        raise Failure, 'Direct Metro baseline differs from reviewed tuple' unless !declarations.empty? && declarations.uniq == [config.fetch('baseline').fetch('metro')]
        raise Failure, 'Unexpected retained bridge on direct source' if File.exist?(File.join(source.root, 'gradle-bridge'))
      end
      version = File.read(File.join(source.root, 'kotlin'))[/^kotlin_cli_version=(.+)$/, 1]
      raise Failure, 'Toolchain differs from compatibility assessment' unless version == config['toolchain']
    end

    def edits(source, profile)
      raise Failure, 'Unknown compatibility profile' unless PROFILES.include?(profile)
      verify_baseline!(source)
      if !source.files.key?(CATALOG) && !%w[direct-mobile direct-resolution direct-build-inputs].include?(profile)
        raise Failure, 'Historical bridge/transform profile is unavailable on direct source; restore the complete published retained revision in an isolated copy'
      end
      return [] if profile.start_with?('direct-')
      paths = [CATALOG] + source.files.keys.select { |p| p.end_with?('/module.yaml') && File.read(File.join(source.root, p)).include?('dev.zacsweers.metro:') }
      paths.map do |path|
        before = File.read(File.join(source.root, path)); after = before.dup
        if path == CATALOG
          config['candidate']['releases'].each { |key, pin| after = after.sub(/^#{key} = "[^"]+"$/, %(#{key} = "#{pin['version']}")) }
        else
          old = config['baseline']['metro']; new_version = config['candidate']['releases']['metro']['version']
          found = before.scan(/dev\.zacsweers\.metro:(runtime|compiler):([^\s]+)/)
          raise Failure, 'Metro module runtime/compiler declarations differ from baseline' unless found.sort == [['compiler', old], ['runtime', old]]
          after = after.gsub(/dev\.zacsweers\.metro:(runtime|compiler):#{Regexp.escape(old)}\b/, 'dev.zacsweers.metro:\1:' + new_version)
        end
        { 'path' => path, 'before_sha256' => source.files.fetch(path)['sha256'], 'content' => after, 'after_sha256' => Digest::SHA256.hexdigest(after) }
      end
    end
  end

  class CompatibilityRehearsal
    attr_reader :host_file

    def initialize(root, source:, profile:, experimental: false)
      config = Compatibility.new(root, experimental: experimental)
      edits = config.edits(source, profile)
      raise Failure, 'Compatibility rehearsal requires an Apple Silicon macOS runtime' unless RUBY_PLATFORM.match?(/arm64.*darwin/)
      wrappers = KotlinWrappers.new(root); wrappers.verify!
      %w[kotlin kotlin.bat].each do |name|
        bytes = File.binread(wrappers.wrapper(config.config['toolchain'], name)).gsub("\r\n", "\n")
        raise Failure, 'Source wrapper differs from reviewed bytes' unless Digest::SHA256.hexdigest(bytes) == source.files.fetch(name)['sha256']
      end
      java, java_status = Open3.capture2('/usr/libexec/java_home', '-v', '21')
      xcode, xcode_status = Open3.capture2('/usr/bin/xcode-select', '-p')
      sdk = [ENV['ANDROID_SDK_ROOT'], ENV['ANDROID_HOME'], File.join(Dir.home, 'Library/Android/sdk')].compact.find { |p| File.directory?(File.join(p, 'platforms')) }
      raise Failure, 'Compatibility prerequisites missing: JDK 21, Xcode and Android SDK' unless java_status.success? && xcode_status.success? && sdk
      host = { 'schema' => 1, 'ruby' => File.realpath(RbConfig.ruby), 'profile' => profile, 'target_policy' => 'apple-silicon',
               'java_home' => File.realpath(java.strip), 'developer_dir' => File.realpath(xcode.strip), 'android_sdk' => File.realpath(sdk) }
      host['experimental'] = true if experimental
      inputs = File.join(root, '.maintenance', 'kotlin-inputs')
      raise Failure, 'Symlinked compatibility host-input store' if File.symlink?(File.dirname(inputs)) || File.symlink?(inputs)
      FileUtils.mkdir_p(inputs)
      @host_file = File.join(inputs, Maintenance.digest(host) + '.json')
      if File.exist?(@host_file)
        raise Failure, 'Host input identity changed' unless !File.symlink?(@host_file) && JSON.parse(File.read(@host_file)) == host
      else
        RunStore.atomic(@host_file, host)
      end
      @files = [__FILE__, @host_file, File.join(root, Compatibility::CONFIG), File.join(root, 'maintenance-kotlin-toolchains.json'), File.join(host['java_home'], 'bin/java')]
      @files += Dir.glob(File.join(root, 'scripts/maintenance/{lib,adapters,fixtures/interop}/**/*')).select { |p| File.file?(p) }
      @files += %w[compatibility_check.rb kotlin_check.rb].map { |p| File.join(root, 'scripts/maintenance', p) }
      @plan = { 'schema' => 1, 'id' => 'compatibility-' + profile, 'scope' => 'compatibility_' + profile.tr('-', '_'),
                'resource_types' => %w[filesystem process-group kotlin-native], 'edits' => edits,
                'missing_capabilities' => Compatibility::UNPROVEN + (%w[direct-resolution direct-build-inputs].include?(profile) ? %w[complete_direct_target_graph compiler_plugin_resolution artifact_attribution] : []) + (%w[bridge-compile direct-resolution direct-build-inputs].include?(profile) ? %w[native_tests application_builds] : []) + (profile == 'direct-build-inputs' ? BuildInputs::GAPS : []) + ['retirement_approval'] + (config.selection['age_state'] == 'age_blocked' ? ['release_age'] : []),
                'checks' => [{ 'id' => profile, 'required' => true, 'timeout_seconds' => %w[direct-roundtrip direct-build-inputs].include?(profile) ? 2400 : 1200,
                               'argv' => [File.realpath(RbConfig.ruby), File.join(root, 'scripts/maintenance/compatibility_check.rb'), '{source}', '{output}', '{cache}', @host_file, profile] }] }
    end

    def plan; @plan; end
    def code_files; @files; end
  end
end
