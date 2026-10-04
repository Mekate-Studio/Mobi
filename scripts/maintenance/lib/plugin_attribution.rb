# frozen_string_literal: true

require_relative 'compatibility_report'
require_relative 'bundled_attribution'

module Maintenance
  module PluginAttribution
    GAPS = %w[shaded_code native_bundle_internals native_test_compiler_inputs complete_direct_target_graph artifact_attribution advisory_review].freeze

    def self.roots(settings, config)
      raise Failure, 'Unreviewed plugin mapping' unless config['schema'] == 1 && ['0.12.2', '0.13.0'].include?(config['toolchain']) && config['automatic_adoption'] == false && config['compose'] == { 'group' => 'org.jetbrains.kotlin', 'name' => 'kotlin-compose-compiler-plugin-embeddable' }
      raise Failure, 'Missing plugin mapping evidence' unless config.fetch('sources').any? { |s| s['id'] == 'mapping' && s['url'] == 'https://raw.githubusercontent.com/JetBrains/kotlin-toolchain/v' + config['toolchain'] + '/sources/frontend/schema/src/org/jetbrains/amper/frontend/kotlin/CompilerPluginConfig.kt' && s['sha256'].to_s.match?(/\A[0-9a-f]{64}\z/) }
      if config['toolchain'] == '0.13.0'
        pinned_sources = {
          'https://raw.githubusercontent.com/JetBrains/kotlin-toolchain/v0.13.0/sources/frontend/schema/src/org/jetbrains/amper/frontend/kotlin/CompilerPluginConfig.kt' => 'be05f876194e1e4103f1d942ebb5138865f5585b9d5f32807902f1e08fe5d58c',
          'https://raw.githubusercontent.com/JetBrains/kotlin-toolchain/v0.13.0/sources/amper-cli/src/org/jetbrains/amper/compilation/KotlinArtifactsDownloader.kt' => 'af6d92c7d659ffab501b3ec6dfe78fc6d8b08390246efdff54918e93fb9ef3b2'
        }
        raise Failure, 'Candidate plugin mapping or classpath source differs' unless pinned_sources.all? { |url, sha| config['sources'].any? { |row| row['url'] == url && row['sha256'] == sha } }
      end
      modules = settings.to_h do |name, fragments|
        lists = fragments.values.map do |fragment|
          kotlin = fragment.fetch('kotlin')
          list = kotlin.fetch('compilerPlugins').map do |plugin|
            d = plugin.fetch('dependency')
            raise Failure, 'Unsupported plugin classifier or packaging' if d['classifier'] || d['packagingType']
            { 'kind' => 'maven', 'group' => d.fetch('groupId'), 'name' => d.fetch('artifactId'), 'version' => d.fetch('version') }
          end
          list << config.fetch('compose').merge('kind' => 'maven', 'version' => kotlin.fetch('version')) if fragment.dig('compose', 'enabled')
          list.each { |c| UpgradeGraph.component!(c) }
          list.uniq.sort_by { |c| [c['group'], c['name'], c['version']] }
        end.uniq
        raise Failure, 'Platform-specific plugin roots require a reviewed scope adapter' unless lists.size == 1
        [name, lists.first]
      end
      { 'modules' => modules, 'roots' => modules.values.flatten.uniq.sort_by { |c| [c['group'], c['name'], c['version']] } }
    rescue KeyError, TypeError, NoMethodError
      raise Failure, 'Malformed effective plugin configuration'
    end

    def self.phase_mapping(config, version)
      mapping = config['toolchain'] == version ? config : config.fetch('candidate_mappings', {}).fetch(version) { raise Failure, 'Missing reviewed candidate plugin mapping' }
      raise Failure, 'Plugin mapping version differs from executed Toolchain' unless mapping['toolchain'] == version
      raise Failure, 'Candidate resolver Gradle pin differs' unless mapping['gradle'] == config['gradle']
      mapping
    end

    def self.input(store, id, config)
      report = CompatibilityReport.read(store, id)
      raise Failure, 'Attribution requires a passing paired build-input proof' unless report['state'] == 'checks_passed' && report.fetch('build_inputs').keys.sort == %w[baseline candidate]
      profile = report.dig('binding', 'adapter').to_s.delete_prefix('compatibility-')
      raise Failure, 'Unsupported plugin producer profile' unless %w[direct-build-inputs upstream-build-inputs].include?(profile)
      upstream = profile == 'upstream-build-inputs'
      report = BundledAttribution.report(File.expand_path('../../..', __dir__), store, id) if upstream
      phases = %w[baseline candidate].to_h do |phase|
        control = File.join(store.path(id), 'steps', phase + '-' + profile)
        settings = JSON.parse(File.read(File.join(control, 'effective-settings.json')))
        mapping = config
        if upstream || config.key?('candidate_mappings')
          declarations = JSON.parse(File.read(File.join(control, 'resolution-declarations.json')))
          version = declarations.fetch('kotlin')[/^kotlin_cli_version=(.+)$/, 1]
          raise Failure, 'Missing executed Toolchain declaration' unless version
          mapping = phase_mapping(config, version)
        end
        data = { 'build_inputs' => report['build_inputs'][phase], 'effective_settings' => settings, 'configuration' => roots(settings, mapping) }
        data['mapping'] = mapping if upstream || config.key?('candidate_mappings')
        [phase, data]
      end
      packet = { 'schema' => 1, 'original_run_id' => id, 'original_result_sha256' => report['result_sha256'], 'original_binding' => report['binding'],
        'config' => config, 'phases' => phases, 'base_queries' => report['direct_resolution']['candidate']['advisory_queries']['queries'], 'adoption_authorized' => false }
      packet['bundled_input_evidence_sha256'] = report.fetch('input_evidence_sha256') if upstream
      packet
    rescue KeyError, JSON::ParserError
      raise Failure, 'Missing paired build-input producers'
    end

    def self.join(input, phase, graph)
      spec = input.fetch('phases').fetch(phase)
      configuration = roots(spec.fetch('effective_settings'), spec.fetch('mapping', input.fetch('config')))
      raise Failure, 'Plugin configuration binding differs' unless configuration == spec['configuration']
      roots = configuration.fetch('roots')
      unless graph['schema'] == 1 && graph['gradle'] == input.dig('config', 'gradle', 'version') && graph['state'] == 'resolved' && graph['roots'].is_a?(Array) && graph['roots'].map { |r| r['requested'] } == roots
        raise Failure, 'Incomplete or different plugin resolver roots'
      end
      selected_by_root = {}
      excluded = []
      graph['roots'].each do |row|
        raise Failure, 'Incomplete plugin graph' unless row['failures'] == [] && %w[nodes edges artifacts].all? { |key| row[key].is_a?(Array) && !row[key].empty? }
        components = row['nodes'].map do |n|
          UpgradeGraph.component!(n.fetch('component')); n.fetch('variants').each { |v| UpgradeGraph.variant!(v) }; n['component']
        end
        row['edges'].each do |edge|
          UpgradeGraph.component!(edge.fetch('from')); UpgradeGraph.component!(edge.fetch('selected')); UpgradeGraph.variant!(edge.fetch('variant'))
          raise Failure, 'Unresolved plugin edge' unless edge['requested'].is_a?(String) && !edge['failure'] && components.include?(edge['from']) && components.include?(edge['selected'])
        end
        root_component = { 'kind' => 'project', 'id' => 'root' }
        reached = [root_component]
        loop do
          expanded = (reached + row['edges'].select { |e| reached.include?(e['from']) }.map { |e| e['selected'] }).uniq
          break if reached == expanded
          reached = expanded
        end
        coord = row['requested'].values_at('group', 'name', 'version').join(':')
        unless components.uniq.sort_by { |c| Maintenance.digest(c) } == reached.sort_by { |c| Maintenance.digest(c) } && row['edges'].any? { |e| e['from'] == root_component && e['requested'] == coord && e['selected'].values_at('group', 'name') == row['requested'].values_at('group', 'name') }
          raise Failure, 'Disconnected plugin graph or missing requested root'
        end
        keep = row['artifacts'].reject do |a|
          UpgradeGraph.component!(a.fetch('component')); UpgradeGraph.variant!(a.fetch('variant'))
          id = a.fetch('identity')
          raise Failure, 'Missing plugin artifact binding' unless a.dig('component', 'kind') == 'maven' && components.include?(a['component']) && a['name'].is_a?(String) && a['name'].match?(/\A[A-Za-z0-9_.+\-]+\z/) && id['kind'] == 'file' && id['bytes'].is_a?(Integer) && id['bytes'] > 0 && id['sha256'].to_s.match?(/\A[0-9a-f]{64}\z/)
          filtered = a['name'].start_with?('kotlin-compiler-embeddable')
          excluded << a.merge('reason' => 'upstream_plugin_classpath_filter', 'root' => row['requested']) if filtered
          filtered
        end
        raise Failure, 'Empty retained plugin root classpath' if keep.empty?
        selected_by_root[Maintenance.digest(row['requested'])] = keep
      end
      candidates = selected_by_root.values.flatten.uniq
      build = spec.fetch('build_inputs')
      identities = build.fetch('selected_plugin_artifacts')
      calls = build.fetch('invocations')
      raise Failure, 'Selected compiler inputs differ from invocation set' unless identities.keys.sort == calls.flat_map { |c| c.fetch('plugins') }.uniq.sort && !identities.empty?
      matched = identities.to_h do |path, identity|
        hits = candidates.select { |a| a['identity'].values_at('sha256', 'bytes') == identity.values_at('sha256', 'bytes') }
        bindings = hits.map { |a| a.slice('component', 'variant', 'identity') }.uniq
        raise Failure, 'Missing or ambiguous plugin fingerprint attribution' unless bindings.size == 1
        [path, bindings.first]
      end
      calls.each do |call|
        configured = configuration.fetch('modules').fetch(call.fetch('module'))
        expected = configured.flat_map { |r| selected_by_root.fetch(Maintenance.digest(r)) }.map { |a| a['identity'].values_at('sha256', 'bytes') }.uniq.sort
        actual = call.fetch('plugins').map { |p| identities.fetch(p).values_at('sha256', 'bytes') }.uniq.sort
        raise Failure, 'Compiler invocation plugin set differs from resolver classpath' unless actual == expected
      end
      queries = matched.values.map { |a| c = a['component']; { 'package' => { 'ecosystem' => 'Maven', 'name' => c['group'] + ':' + c['name'] }, 'version' => c['version'] } }.uniq.sort_by { |q| [q['package']['name'], q['version']] }
      raise Failure, 'Unsafe plugin resolver evidence' if JSON.generate(graph).match?(%r{/Users/|/home/|/private/|Bearer |github_pat_})
      { 'schema' => 1, 'state' => 'attributed', 'method' => 'independent_resolver_exact_compiler_fingerprint_join', 'phase' => phase,
        'original_run_id' => input['original_run_id'], 'original_result_sha256' => input['original_result_sha256'],
        'input_sha256' => Maintenance.digest(input), 'graph_sha256' => Maintenance.digest(graph), 'attributions' => matched,
        'excluded_artifacts' => excluded, 'queries' => queries, 'missing_capabilities' => GAPS, 'adoption_authorized' => false }
    rescue KeyError, TypeError, NoMethodError
      raise Failure, 'Malformed plugin attribution evidence'
    end

    def self.report(store, id)
      # Original producers are verified again; copied input packets cannot substitute
      # a new compilation or silently change the old proof's source identity.
      journal = store.load(id)
      result_path = store.path(id, '.result.json')
      result = JSON.parse(File.read(result_path))
      unless result['state'] == 'checks_passed' && result['binding'] == journal['binding'] && result.dig('binding', 'adapter') == 'plugin-attribution' && result['run_id'] == id && result['adoption_authorized'] == false && result['ended_at'] == journal['ended_at'] && result['state'] == journal['state'] && result['steps'].map { |s| s['phase'] }.sort == %w[baseline candidate]
        raise Failure, 'Plugin attribution run lacks a passing pair'
      end
      phases = {}; inputs = []
      result['steps'].each do |step|
        record = journal.fetch('steps').find { |s| s['id'] == step['phase'] + '-plugin-attribution' }
        raise Failure, 'Missing stopped attribution check' unless record && record['state'] == 'stopped' && record['process_exit'] == 0 && step['exit'] == 0 && step['status'] == 'passed' && step['check'] == 'plugin-attribution'
        control = store.safe_path(journal, record['path'])
        raise Failure, 'Missing attribution output digests' unless step['output_sha256'].keys.sort == %w[check.json stderr.log stdout.log]
        step['output_sha256'].each do |name, sha|
          CompatibilityReport.verify_file!(File.join(control, name), sha)
          raise Failure, 'Attribution journal digest differs' unless record['output_sha256'][name] == sha
        end
        check = JSON.parse(File.read(File.join(control, 'check.json')))
        raise Failure, 'Attribution check differs' unless check['phase'] == step['phase'] && check['check'] == 'plugin-attribution' && check['status'] == 'passed'
        evidence_path = File.join(control, 'evidence.json'); CompatibilityReport.verify_file!(evidence_path, check.fetch('evidence_sha256'))
        evidence = JSON.parse(File.read(evidence_path))
        data = %w[input resolver attribution].to_h do |name|
          CompatibilityReport.verify_file!(File.join(control, name + '.json'), evidence.fetch(name + '_sha256'))
          [name, JSON.parse(File.read(File.join(control, name + '.json')))]
        end
        CompatibilityReport.verify_file!(File.join(control, 'resolver.log'), evidence.fetch('log_sha256'))
        original = input(store, data['input'].fetch('original_run_id'), data['input'].fetch('config'))
        raise Failure, 'Plugin input packet differs from original proof' unless data['input'] == original
        replay = join(original, step['phase'], data['resolver'])
        raise Failure, 'Plugin summary differs from replay' unless data['attribution'] == replay && evidence['phase'] == step['phase'] && evidence['source_preservation'] == 'verified'
        phases[step['phase']] = replay; inputs << original
      end
      raise Failure, 'Paired attribution inputs differ' unless inputs.uniq.size == 1
      queries = (inputs.first['base_queries'] + phases['candidate']['queries']).uniq.sort_by { |q| [q['package']['name'], q['version']] }
      report = { 'schema' => 1, 'run_id' => id, 'state' => 'checks_passed', 'result_sha256' => Maintenance.file_sha(result_path), 'binding' => result['binding'],
                 'original_binding' => inputs.first['original_binding'], 'plugin_attribution' => phases,
                 'direct_resolution' => { 'candidate' => { 'advisory_queries' => { 'queries' => queries } } },
                 'missing_capabilities' => GAPS, 'bridge_retirement' => 'defer', 'adoption_authorized' => false }
      path = File.join(store.path(id), 'advisory-review.json')
      if File.exist?(path)
        raise Failure, 'Symlinked plugin advisory receipt' if File.symlink?(path)
        report['direct_advisories'] = AdvisoryReview.verify!(JSON.parse(File.read(path)), report)
      end
      report
    rescue KeyError, TypeError, NoMethodError, JSON::ParserError
      raise Failure, 'Malformed plugin attribution report'
    end
  end
end
