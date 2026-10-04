# frozen_string_literal: true

require_relative 'kotlin_evidence'
require_relative 'upgrade_graph'

module Maintenance
  module DirectResolution
    GAPS = %w[native_tests application_builds complete_direct_target_graph compiler_plugin_resolution artifact_attribution].freeze
    NATIVE_CELLS = %w[native_library_compile framework_link android-test android-build-debug ios-test ios-build-debug].freeze

    def self.coverage!(graphs, declarations)
      modules = declarations.keys.grep(%r{/module\.yaml\z}).map { |path| path.split('/').first }.sort
      declared = YAML.safe_load(declarations.fetch('project.yaml')).fetch('modules')
      raise Failure, 'Missing resolution declarations' unless !modules.empty? && declared.is_a?(Array) && declared.sort == modules && declared.uniq == declared
      modules.each do |name|
        product = YAML.safe_load(declarations.fetch(name + '/module.yaml')).fetch('product')
        platforms = if product.is_a?(Hash) && product['type'] == 'kmp/lib'
                      product.fetch('platforms')
                    elsif (product.is_a?(Hash) ? product['type'] : product) == 'ios/app'
                      %w[iosArm64 iosSimulatorArm64]
                    elsif product == 'android/app'
                      ['android']
                    else
                      raise Failure, 'Unsupported resolution product'
                    end
        raise Failure, 'Invalid declared resolution platforms' unless platforms.is_a?(Array) && !platforms.empty? && platforms.all? { |p| p.is_a?(String) && p.match?(/\A[A-Za-z0-9]+\z/) } && platforms.uniq == platforms
        platforms.product(%w[main test], %w[compile runtime]).each do |platform, usage, scope|
          unless graphs.fetch('graphs').any? { |g| g['module'] == name && g['usage'] == usage && g['scope'] == scope && g.fetch('platforms').include?(platform) }
            raise Failure, 'Missing declared platform/main/test/compile/runtime resolution scope'
          end
        end
      end
      modules
    rescue KeyError, TypeError, NoMethodError, Psych::Exception
      raise Failure, 'Malformed resolution declarations'
    end

    def self.verify!(control, evidence)
      read = lambda do |name|
        ref = evidence.fetch(name)
        JSON.parse(File.read(File.join(control, ref.fetch('file'))))
      end
      declarations = read.call('resolution-declarations')
      manifest = read.call(evidence['phase'] == 'candidate' && evidence['profile'] != 'upstream-build-inputs' ? 'direct-source-manifest' : 'source-manifest')
      declarations.each do |path, content|
        unless content.is_a?(String) && manifest.fetch(path).fetch('sha256') == Digest::SHA256.hexdigest(content)
          raise Failure, 'Resolution declaration differs from authored manifest'
        end
      end
      graphs = read.call('resolved-graphs')
      modules = coverage!(graphs, declarations)
      version = declarations.fetch('kotlin')[/^kotlin_cli_version=(.+)$/, 1]
      commands = evidence.fetch('commands').select { |c| c['check'] == 'dependencies' }
      raise Failure, 'Missing direct dependency command binding' unless commands.size == 1 && commands.first['exit'] == 0 && commands.first['capability'] == 'toolchain_resolution'
      replay = KotlinEvidence.graphs(File.read(File.join(control, commands.first.fetch('log')), encoding: 'UTF-8'), modules: modules, version: version)
      raise Failure, 'Parsed resolution differs from captured output' unless replay == graphs
      artifacts = read.call('downloaded-artifacts')
      raise Failure, 'Missing artifact fingerprint scopes' unless artifacts.keys.sort == %w[cache home]
      artifacts.each_value do |files|
        raise Failure, 'Invalid artifact fingerprint inventory' unless files.is_a?(Hash)
        files.each do |path, identity|
          unless path.is_a?(String) && !path.start_with?('/') && (path.split('/') & %w[. ..]).empty? && identity['sha256'].to_s.match?(/\A[0-9a-f]{64}\z/) && identity['bytes'].is_a?(Integer) && identity['bytes'] >= 0 && identity.keys.sort == %w[bytes sha256]
            raise Failure, 'Invalid downloaded artifact identity'
          end
        end
      end
      { 'scope' => 'declared_module_main_test_compile_runtime_platform_roots', 'modules' => modules, 'roots' => graphs['graphs'].size,
        'graph_sha256' => Maintenance.digest(graphs), 'fingerprints_sha256' => Maintenance.digest(artifacts),
        'fingerprint_count' => artifacts.values.sum(&:size), 'artifact_attribution' => 'unproven',
        'advisory_queries' => UpgradeGraph.toolchain_queries(graphs),
        'missing_capabilities' => GAPS, 'adoption_authorized' => false }
    end
  end
end
