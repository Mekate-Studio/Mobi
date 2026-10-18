# frozen_string_literal: true

require_relative '../core'

module Maintenance
  module SwiftExport
    # Paths are locators. The receipt binds their bytes and settings, never their
    # absolute installation location. Production configuration has no defaults.
    class Descriptor
      PROFILES = %w[coroutine-swift5 generated-swift5].freeze
      POLICIES = %w[main-confined shared-operation-mutex].freeze
      NAME = /\A[A-Za-z][A-Za-z0-9_]*\z/
      SHA = /\A[0-9a-f]{64}\z/
      attr_reader :root, :data, :profile, :repository_policy, :path

      def self.relative!(value)
        parts = value.is_a?(String) ? value.split('/', -1) : []
        raise Failure, 'Invalid relative input path' if parts.empty? || value.start_with?('/') || value.include?("\0") || parts.any? { |p| p.empty? || %w[. ..].include?(p) }
        value
      end

      def self.safe(root, relative)
        relative!(relative)
        relative.split('/').each_index do |i|
          raise Failure, "Symlink input forbidden: #{relative}" if File.symlink?(File.join(root, *relative.split('/').take(i + 1)))
        end
        File.join(root, relative)
      end

      def self.inventory(root, relatives)
        result = {}
        relatives.each do |relative|
          path = safe(root, relative)
          raise Failure, "Missing input: #{relative}" unless File.exist?(path)
          paths = File.directory?(path) ? Dir.glob(File.join(path, '**', '*'), File::FNM_DOTMATCH) : [path]
          paths.each do |member|
            next if %w[. ..].include?(File.basename(member))
            name = member.delete_prefix(root + '/')
            safe(root, name) # Reject directory symlinks too, before file filtering.
            next if File.directory?(member)
            raise Failure, "Non-regular input: #{name}" unless File.file?(member)
            result[name] = { 'sha256' => Maintenance.file_sha(member), 'executable' => (File.stat(member).mode & 0o111) != 0 }
          end
        end
        result.sort.to_h
      end

      def initialize(root:, path:, profile:, repository_policy:)
        raise Failure, 'An explicit supported Swift profile is required' unless PROFILES.include?(profile)
        raise Failure, 'An explicit repository policy is required' unless POLICIES.include?(repository_policy)
        @root = File.realpath(root)
        @path = self.class.safe(@root, path)
        @profile, @repository_policy = profile, repository_policy
        @data = JSON.parse(File.read(@path))
        validate!
      rescue JSON::ParserError, Errno::ENOENT => e
        raise Failure, "Invalid Swift export descriptor: #{e.class}"
      end

      def validate!
        required = %w[schema id purpose target wire_schema modules inputs artifacts compiler native diagnostics runtime_settings cache_policy]
        raise Failure, 'Unsupported descriptor shape' unless data.is_a?(Hash) && (required - data.keys).empty? && data['schema'] == 1 && data['purpose'] == 'diagnostic-candidate'
        raise Failure, 'Invalid candidate ID' unless data['id'].is_a?(String) && data['id'].match?(/\A[a-z][a-z0-9-]{1,63}\z/)
        target = data.fetch('target')
        raise Failure, 'Unsupported candidate target' unless target == { 'kotlin' => 'ios_simulator_arm64', 'swift' => 'arm64-apple-ios26.0-simulator', 'sdk' => 'iphonesimulator', 'minimum_ios' => '26.0', 'single_scene' => true }
        raise Failure, 'Missing wire schema identity' unless data['wire_schema'].is_a?(String) && !data['wire_schema'].empty?
        modules = data.fetch('modules')
        raise Failure, 'Missing module graph' unless modules.is_a?(Array) && !modules.empty?
        names = modules.map { |m| m.fetch('name') }
        raise Failure, 'Invalid/duplicate modules' unless names.uniq == names && names.all? { |n| n.match?(NAME) }
        modules.each do |m|
          raise Failure, 'Invalid module contract' unless %w[partial full].include?(m['visibility']) && m['dependencies'].is_a?(Array) && (m['dependencies'] - names).empty? && m['inputs'].is_a?(Array) && !m['inputs'].empty?
          m['inputs'].each { |p| self.class.relative!(p) }
        end
        ordered = []
        until ordered.size == names.size
          next_module = modules.find { |m| !ordered.include?(m['name']) && (m['dependencies'] - ordered).empty? }
          raise Failure, 'Cyclic module closure' unless next_module
          ordered << next_module['name']
        end
        inputs = data.fetch('inputs')
        raise Failure, 'Missing input cohorts' unless inputs.is_a?(Hash) && %w[generator schema native build].all? { |k| inputs[k].is_a?(Array) && !inputs[k].empty? }
        inputs.each_value { |list| list.each { |p| self.class.relative!(p) } }
        artifacts = data.fetch('artifacts')
        raise Failure, 'Missing public artifacts' unless artifacts.is_a?(Array) && !artifacts.empty?
        raise Failure, 'Duplicate artifact paths' unless artifacts.map { |a| a['path'] }.uniq.size == artifacts.size
        artifacts.each do |a|
          self.class.relative!(a['path'])
          raise Failure, 'Unpinned/non-public artifact' unless a['sha256'].is_a?(String) && a['sha256'].match?(SHA) && a['url'].is_a?(String) && a['url'].match?(%r{\Ahttps://(?:repo.maven.apache.org/maven2|packages.jetbrains.team/maven/p/ij/intellij-dependencies)/})
        end
        compiler = data.fetch('compiler')
        raise Failure, 'Unsupported producer compiler contract' unless compiler['kotlin'] == '2.4.20' && compiler['jdk_major'] == 26 && compiler['toolchain'] == '0.13.0' && compiler['export_jars'].is_a?(Array) && !compiler['export_jars'].empty? && (compiler['export_jars'] - artifacts.map { |a| a['path'] }).empty?
        raise Failure, 'Missing compiler flags' unless compiler['archive_flags'].is_a?(Array) && compiler['swift_flags'].is_a?(Array)
        raise Failure, 'Blanket diagnostic suppression forbidden' if (compiler['archive_flags'] + compiler['swift_flags']).any? { |f| !f.is_a?(String) || f.match?(/nowarn|suppress|disable.*(warning|concurrency)/i) }
        raise Failure, 'Missing external dependency locks' unless compiler['external_libraries'].is_a?(Array) && !compiler['external_libraries'].empty?
        (compiler['external_libraries'] + [compiler.fetch('compose_plugin'), compiler.fetch('metro_plugin')]).each do |locked|
          self.class.relative!(locked.fetch('relative_path'))
          raise Failure, 'Invalid compiler/dependency checksum' unless locked['sha256'].to_s.match?(SHA)
        end
        native = data.fetch('native')
        %w[package lock plist assets].each { |k| self.class.relative!(native.fetch(k)) }
        raise Failure, 'Missing native source closure' unless native['sources'].is_a?(Array) && !native['sources'].empty?
        native['sources'].each { |p| self.class.relative!(p) }
        raise Failure, 'Missing native publisher checksums' unless native['binary_artifacts'].is_a?(Array) && !native['binary_artifacts'].empty? && native['binary_artifacts'].all? { |a| a['url'].to_s.start_with?('https://github.com/maplibre/maplibre-native/releases/download/') && a['sha256'].to_s.match?(SHA) }
        settings = data.fetch('runtime_settings')
        %w[parent_reservations compose_jobs_per_owner polling_nanoseconds backoff_nanoseconds shutdown_observation_nanoseconds].each do |key|
          raise Failure, "Explicit positive diagnostic setting required: #{key}" unless settings[key].is_a?(Integer) && settings[key] > 0 && settings[key] <= 2**63 - 1
        end
        raise Failure, 'Diagnostic limits cannot select production policy' unless settings['scope'] == 'diagnostic-only'
        cache = data.fetch('cache_policy')
        raise Failure, 'Explicit logical cache policy required' unless cache['logical_payload_byte_limit'].is_a?(Integer) && cache['logical_payload_byte_limit'] > 0 && cache['minimum_age_seconds'].is_a?(Integer) && cache['minimum_age_seconds'] >= 0
        raise Failure, 'Missing diagnostic contract' unless data['diagnostics'] == { 'native_warnings' => 'fail', 'generated' => 'fingerprint-review', 'runtime' => 'fingerprint-review', 'inheritance' => 'unresolved-adoption-gate' }
        true
      rescue KeyError, NoMethodError, TypeError
        raise Failure, 'Malformed Swift export descriptor field'
      end

      def inspection
        selected = data['inputs'].values.flatten + data['modules'].flat_map { |m| m['inputs'] } + data['native']['sources'] + data['native'].values_at('lock', 'plist', 'assets') + [data['native']['package'] + '/Package.swift', data['native']['package'] + '/Sources']
        inventory = self.class.inventory(root, selected.uniq)
        lock = JSON.parse(File.read(self.class.safe(root, data['native']['lock'])))
        raise Failure, 'Missing locked native dependency revisions' unless lock['pins'].is_a?(Array) && !lock['pins'].empty? && lock['pins'].all? { |p| p.dig('state', 'revision').to_s.match?(/\A[0-9a-f]{40}\z/) }
        contract = { 'schema' => 1, 'descriptor' => data, 'descriptor_sha256' => Maintenance.file_sha(path), 'selected_files' => inventory,
                     'profile' => profile, 'repository_policy' => repository_policy, 'consumer_mode' => '6', 'native_pins' => lock['pins'] }
        contract.merge('identity' => Maintenance.digest(contract), 'adoption_authorized' => false)
      rescue JSON::ParserError
        raise Failure, 'Malformed native lock'
      end

      def modes(names)
        raise Failure, 'Missing support module' unless names.include?('KotlinCoroutineSupport') && names.uniq == names && names.all? { |n| n.match?(NAME) }
        names.to_h { |n| [n, profile == 'generated-swift5' || n == 'KotlinCoroutineSupport' ? '5' : '6'] }
      end
    end
  end
end
