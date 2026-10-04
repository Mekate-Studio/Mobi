# frozen_string_literal: true

require_relative '../lib/kotlin_wrappers'
require_relative 'kotlin_targets'
require_relative 'mobile_support'
require 'rbconfig'

module Maintenance
  class KotlinRehearsal
    PROFILES = %w[inputs mobile].freeze
    attr_reader :host_file

    def initialize(root, source:, candidate:, profile:, target_policy: nil, support_policy: false, experimental: false)
      raise Failure, 'Use Kotlin profile inputs or mobile' unless PROFILES.include?(profile)
      @root = root
      wrappers = KotlinWrappers.new(root)
      baseline = wrappers.pins.fetch('baseline')
      if support_policy
        raise Failure, 'Support rehearsal must keep the current Toolchain' unless candidate == baseline
      else
        wrappers.candidate!(candidate, experimental: experimental)
      end
      wrappers.verify!
      target_policy ||= wrappers.pins.fetch('target_policy', 'current')
      target_edits = KotlinTargets.edits(source, target_policy)
      %w[kotlin kotlin.bat].each do |name|
        expected = File.binread(wrappers.wrapper(baseline, name)).gsub("\r\n", "\n")
        raise Failure, 'Caller wrapper differs from reviewed baseline' unless source.files.fetch(name)['sha256'] == Digest::SHA256.hexdigest(expected)
      end
      host = { 'schema' => 1, 'ruby' => File.realpath(RbConfig.ruby), 'profile' => profile, 'target_policy' => target_policy }
      support = MobileSupport.new(root) if support_policy
      support_edits = support ? support.edits(source) : []
      if support
        raise Failure, 'Support declarations already match; no candidate to rehearse' if support_edits.empty?
        assessment = support.assess(source: source)
        host.merge!('support_policy' => true, 'candidate_ios_minimum_major' => assessment['platforms']['ios']['proposed_major'].to_i)
      end
      if profile == 'mobile'
        raise Failure, 'Mobile rehearsal currently requires macOS' unless RUBY_PLATFORM.include?('darwin')
        raise Failure, 'Apple Silicon mobile rehearsal requires an ARM64 host runtime' if target_policy == 'apple-silicon' && !RUBY_PLATFORM.match?(/arm64|aarch64/)
        java, java_status = Open3.capture2({ 'PATH' => '/usr/bin:/bin' }, '/usr/libexec/java_home', '-v', '21', unsetenv_others: true)
        xcode, xcode_status = Open3.capture2({ 'PATH' => '/usr/bin:/bin' }, '/usr/bin/xcode-select', '-p', unsetenv_others: true)
        sdk = [ENV['ANDROID_SDK_ROOT'], ENV['ANDROID_HOME'], File.join(Dir.home, 'Library/Android/sdk')].compact.find { |path| File.directory?(File.join(path, 'platforms')) }
        raise Failure, 'Mobile prerequisites missing: JDK 21, Android SDK and Xcode are required' unless java_status.success? && xcode_status.success? && sdk
        host.merge!('java_home' => File.realpath(java.strip), 'developer_dir' => File.realpath(xcode.strip), 'android_sdk' => File.realpath(sdk))
      end
      inputs = File.join(root, '.maintenance', 'kotlin-inputs')
      raise Failure, 'Symlinked Kotlin host-input store' if File.symlink?(File.dirname(inputs)) || File.symlink?(inputs)
      FileUtils.mkdir_p(inputs)
      @host_file = File.join(inputs, Maintenance.digest(host) + '.json')
      if File.exist?(@host_file)
        raise Failure, 'Kotlin host input identity changed' unless !File.symlink?(@host_file) && JSON.parse(File.read(@host_file)) == host
      else
        RunStore.atomic(@host_file, host)
      end
      @files = [__FILE__, wrappers.path, @host_file, File.join(root, 'maintenance-policy.json')]
      @files += %w[kotlin_check.rb lib/kotlin_evidence.rb lib/kotlin_wrappers.rb lib/support_policy.rb adapters/mobile_support.rb adapters/kotlin_resources.rb adapters/kotlin_targets.rb].map { |name| File.join(root, 'scripts/maintenance', name) }
      @files += MobileSupport::INPUTS.map { |path| File.join(root, path) } if support
      @files += [baseline, candidate].flat_map { |version| %w[kotlin kotlin.bat].map { |name| wrappers.wrapper(version, name) } }
      @files << File.join(host['java_home'], 'bin/java') if profile == 'mobile'
      edits = %w[kotlin kotlin.bat].map do |name|
        content = File.binread(wrappers.wrapper(candidate, name)).gsub("\r\n", "\n").force_encoding(Encoding::UTF_8)
        raise Failure, 'Consumer wrapper is not UTF-8' unless content.valid_encoding?
        { 'path' => name, 'before_sha256' => source.files.fetch(name)['sha256'], 'content' => content, 'after_sha256' => Digest::SHA256.hexdigest(content) }
      end
      edits = edits.reject { |edit| edit['before_sha256'] == edit['after_sha256'] }
      edits += target_edits + support_edits
      missing = %w[authenticated_provider_evidence complete_bridge_target_graph signed_release_packaging direct_toolchain_parity intel_linux_hosted_execution]
      if target_policy == 'apple-silicon'
        missing.delete('intel_linux_hosted_execution')
        missing += %w[linux_execution cold_hosted_execution device_release_packaging]
      end
      missing += %w[native_tests native_builds compiler_artifacts] if profile == 'inputs'
      source_scope = source.files.key?(KotlinTargets::BRIDGE) ? 'retained_bridge_toolchain_' : 'direct_toolchain_'
      @plan = { 'schema' => 1, 'id' => 'kotlin-toolchain-' + profile, 'scope' => source_scope + profile,
                'resource_types' => %w[filesystem process-group] + (profile == 'mobile' ? ['kotlin-native'] : []),
                'missing_capabilities' => missing, 'edits' => edits,
                'checks' => [{ 'id' => 'toolchain-' + profile, 'required' => true, 'timeout_seconds' => profile == 'mobile' ? 1200 : 300,
                               'argv' => [File.realpath(RbConfig.ruby), File.join(root, 'scripts/maintenance/kotlin_check.rb'), '{source}', '{output}', '{cache}', @host_file, profile] }] }
      if target_policy == 'apple-silicon'
        @plan['id'] += '-apple-silicon'
        @plan['scope'] += '_apple_silicon'
      end
      if support
        @plan['id'] += '-support-policy'
        @plan['scope'] += '_support_policy'
        @plan['missing_capabilities'] += %w[android_device_runtime every_minimum_os_patch]
      end
    end

    def plan
      @plan
    end

    def code_files
      @files
    end
  end
end
