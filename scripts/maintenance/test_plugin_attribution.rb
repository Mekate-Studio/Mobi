# frozen_string_literal: true

require_relative 'lib/plugin_attribution'

module PluginAttributionTest
  @tests = []
  def self.test(name, &block); @tests << [name, block]; end
  def self.assert(value); raise 'assertion failed' unless value; end
  def self.reject
    yield; raise 'Expected refusal'
  rescue Maintenance::Failure
    true
  end
  def self.fixture
    c = { 'kind' => 'maven', 'group' => 'example', 'name' => 'plugin', 'version' => '1.0.0' }
    config = { 'schema' => 1, 'toolchain' => '0.12.2', 'automatic_adoption' => false, 'gradle' => { 'version' => '9.6.1' },
               'compose' => { 'group' => 'org.jetbrains.kotlin', 'name' => 'kotlin-compose-compiler-plugin-embeddable' },
               'sources' => [{ 'id' => 'mapping', 'url' => 'https://raw.githubusercontent.com/JetBrains/kotlin-toolchain/v0.12.2/sources/frontend/schema/src/org/jetbrains/amper/frontend/kotlin/CompilerPluginConfig.kt', 'sha256' => 'a' * 64 }] }
    settings = { 'shared-di' => { 'settings@android' => { 'kotlin' => { 'compilerPlugins' => [{ 'dependency' => { 'groupId' => 'example', 'artifactId' => 'plugin', 'version' => '1.0.0' } }], 'version' => '2.4.10' }, 'compose' => { 'enabled' => false } } } }
    identity = { 'sha256' => 'b' * 64, 'bytes' => 10 }
    build = { 'selected_plugin_artifacts' => { '{cache}/arbitrary-name.jar' => identity }, 'invocations' => [{ 'module' => 'shared-di', 'plugins' => ['{cache}/arbitrary-name.jar'] }] }
    input = { 'config' => config, 'original_run_id' => 'c' * 32, 'original_result_sha256' => 'd' * 64,
              'phases' => { 'candidate' => { 'build_inputs' => build, 'effective_settings' => settings, 'configuration' => Maintenance::PluginAttribution.roots(settings, config) } } }
    v = { 'name' => 'runtime', 'attributes' => { 'org.gradle.usage' => 'java-runtime' } }; root = { 'kind' => 'project', 'id' => 'root' }
    graph = { 'schema' => 1, 'state' => 'resolved', 'gradle' => '9.6.1', 'roots' => [{ 'requested' => c, 'failures' => [],
              'nodes' => [root, c].map { |n| { 'component' => n, 'variants' => [v] } },
              'edges' => [{ 'from' => root, 'selected' => c, 'requested' => 'example:plugin:1.0.0', 'variant' => v }],
              'artifacts' => [{ 'component' => c, 'variant' => v, 'name' => 'published-plugin.jar', 'identity' => identity.merge('kind' => 'file') }] }] }
    [input, graph]
  end
  test('phase mappings require the executed version and reviewed candidate source bytes') do
    input, = fixture
    config = input['config']
    reject { Maintenance::PluginAttribution.phase_mapping(config, '0.13.0') }
    candidate = JSON.parse(File.read(File.expand_path('../../maintenance-plugin-resolution.json', __dir__))).fetch('candidate_mappings').fetch('0.13.0')
    config['gradle'] = candidate['gradle']
    config['candidate_mappings'] = { '0.13.0' => candidate }
    selected = Maintenance::PluginAttribution.phase_mapping(config, '0.13.0')
    assert(selected['toolchain'] == '0.13.0')
    roots = Maintenance::PluginAttribution.roots(input['phases']['candidate']['effective_settings'], selected)
    assert(roots['roots'].size == 1)
    changed = Marshal.load(Marshal.dump(selected)); changed['sources'][0]['sha256'] = 'f' * 64
    reject { Maintenance::PluginAttribution.roots(input['phases']['candidate']['effective_settings'], changed) }
    reject { Maintenance::PluginAttribution.phase_mapping(config, '0.14.0') }
    changed['toolchain'] = '0.12.2'; config['candidate_mappings']['0.13.0'] = changed
    reject { Maintenance::PluginAttribution.phase_mapping(config, '0.13.0') }
  end
  test('fingerprints attribute arbitrary paths without inferring names') do
    input, graph = fixture
    proof = Maintenance::PluginAttribution.join(input, 'candidate', graph)
    assert(proof['attributions']['{cache}/arbitrary-name.jar']['component']['name'] == 'plugin')
    assert(proof['queries'].first['package']['name'] == 'example:plugin' && !proof['adoption_authorized'] && proof['missing_capabilities'].include?('shaded_code'))
  end
  test('missing or differing bytes refuse') do
    input, graph = fixture; graph['roots'][0]['artifacts'][0]['identity']['sha256'] = 'f' * 64
    reject { Maintenance::PluginAttribution.join(input, 'candidate', graph) }
    input, graph = fixture; graph['roots'][0]['artifacts'][0]['identity']['bytes'] = 11
    reject { Maintenance::PluginAttribution.join(input, 'candidate', graph) }
    input, graph = fixture; graph['roots'][0]['artifacts'].clear
    reject { Maintenance::PluginAttribution.join(input, 'candidate', graph) }
  end
  test('ambiguous coordinates or selected variants refuse') do
    input, graph = fixture; row = graph['roots'][0]
    other = { 'kind' => 'maven', 'group' => 'example', 'name' => 'other', 'version' => '1.0.0' }
    a = Marshal.load(Marshal.dump(row['artifacts'][0])); a['component'] = other
    row['nodes'] << { 'component' => other, 'variants' => [a['variant']] }
    row['edges'] << { 'from' => row['requested'], 'selected' => other, 'requested' => 'example:other:1.0.0', 'variant' => a['variant'] }
    row['artifacts'] << a
    reject { Maintenance::PluginAttribution.join(input, 'candidate', graph) }
    input, graph = fixture; a = Marshal.load(Marshal.dump(graph['roots'][0]['artifacts'][0])); a['variant']['name'] = 'different'
    graph['roots'][0]['artifacts'] << a
    reject { Maintenance::PluginAttribution.join(input, 'candidate', graph) }
  end
  test('extra retained transitives refuse and upstream compiler filter is explicit') do
    input, graph = fixture; row = graph['roots'][0]
    a = Marshal.load(Marshal.dump(row['artifacts'][0])); a['identity']['sha256'] = 'e' * 64; a['name'] = 'extra.jar'; row['artifacts'] << a
    reject { Maintenance::PluginAttribution.join(input, 'candidate', graph) }
    a['name'] = 'kotlin-compiler-embeddable-2.4.10.jar'
    r = Maintenance::PluginAttribution.join(input, 'candidate', graph)
    assert(r['excluded_artifacts'].size == 1 && r['queries'].size == 1)
  end
  test('incomplete disconnected changed or private graphs refuse') do
    input, graph = fixture; graph['roots'][0]['failures'] << 'Unresolved'
    reject { Maintenance::PluginAttribution.join(input, 'candidate', graph) }
    input, graph = fixture; graph['roots'][0]['edges'].clear
    reject { Maintenance::PluginAttribution.join(input, 'candidate', graph) }
    input, graph = fixture; graph['roots'][0]['requested']['version'] = '2.0.0'
    reject { Maintenance::PluginAttribution.join(input, 'candidate', graph) }
    input, graph = fixture; graph['roots'][0]['artifacts'][0]['variant']['name'] = '/Users/private'
    reject { Maintenance::PluginAttribution.join(input, 'candidate', graph) }
  end
  test('unconfigured invocation, extra measured file and platform-specific roots refuse') do
    input, graph = fixture; input['phases']['candidate']['build_inputs']['invocations'][0]['module'] = 'unknown'
    reject { Maintenance::PluginAttribution.join(input, 'candidate', graph) }
    input, graph = fixture; input['phases']['candidate']['build_inputs']['selected_plugin_artifacts']['{cache}/extra.jar'] = { 'sha256' => 'f' * 64, 'bytes' => 1 }
    reject { Maintenance::PluginAttribution.join(input, 'candidate', graph) }
    input, _graph = fixture; settings = input['phases']['candidate']['effective_settings']; v = Marshal.load(Marshal.dump(settings['shared-di'].values.first)); v['compose']['enabled'] = true
    settings['shared-di']['settings@iosArm64'] = v
    reject { Maintenance::PluginAttribution.roots(settings, input['config']) }
  end
  test('report replays joins even when altered summary digests are made consistent') do
    input, graph = fixture
    input['phases']['baseline'] = Marshal.load(Marshal.dump(input['phases']['candidate']))
    input['original_binding'] = { 'source_sha256' => 'e' * 64 }
    input['base_queries'] = []
    original_method = Maintenance::PluginAttribution.method(:input)
    Maintenance::PluginAttribution.define_singleton_method(:input) { |_store, _id, _config| input }
    Dir.mktmpdir do |root|
      store = Maintenance::RunStore.new(File.join(root, 'runs')); id = SecureRandom.hex(16)
      binding = { 'adapter' => 'plugin-attribution' }; journal = store.allocate(id, binding, {})
      steps = %w[baseline candidate].map do |phase|
        control = store.directory(journal, 'steps/' + phase + '-plugin-attribution', disposable: false)
        data = { 'input' => input, 'resolver' => graph, 'attribution' => Maintenance::PluginAttribution.join(input, phase, graph) }
        evidence = { 'phase' => phase, 'source_preservation' => 'verified' }
        data.each do |name, value|
          Maintenance::RunStore.atomic(File.join(control, name + '.json'), value)
          evidence[name + '_sha256'] = Maintenance.file_sha(File.join(control, name + '.json'))
        end
        File.write(File.join(control, 'resolver.log'), 'resolver evidence'); evidence['log_sha256'] = Maintenance.file_sha(File.join(control, 'resolver.log'))
        Maintenance::RunStore.atomic(File.join(control, 'evidence.json'), evidence)
        Maintenance::RunStore.atomic(File.join(control, 'check.json'), { 'phase' => phase, 'check' => 'plugin-attribution', 'status' => 'passed', 'evidence_sha256' => Maintenance.file_sha(File.join(control, 'evidence.json')) })
        %w[stdout.log stderr.log].each { |name| File.write(File.join(control, name), '') }
        hashes = %w[check.json stdout.log stderr.log].to_h { |name| [name, Maintenance.file_sha(File.join(control, name))] }
        journal['steps'] << { 'id' => phase + '-plugin-attribution', 'path' => 'steps/' + phase + '-plugin-attribution', 'state' => 'stopped', 'process_exit' => 0, 'output_sha256' => hashes }
        { 'phase' => phase, 'check' => 'plugin-attribution', 'status' => 'passed', 'exit' => 0, 'output_sha256' => hashes }
      end
      store.result(journal, { 'state' => 'checks_passed', 'ended_at' => Time.now.utc.iso8601, 'run_id' => id, 'binding' => binding, 'adoption_authorized' => false, 'steps' => steps })
      report = Maintenance::PluginAttribution.report(store, id)
      assert(report['plugin_attribution'].size == 2 && report['direct_resolution']['candidate']['advisory_queries']['queries'].size == 1)
      control = File.join(store.path(id), 'steps/candidate-plugin-attribution')
      path = File.join(control, 'attribution.json'); value = JSON.parse(File.read(path)); value['queries'].clear; Maintenance::RunStore.atomic(path, value)
      path = File.join(control, 'evidence.json'); value = JSON.parse(File.read(path)); value['attribution_sha256'] = Maintenance.file_sha(File.join(control, 'attribution.json')); Maintenance::RunStore.atomic(path, value)
      path = File.join(control, 'check.json'); value = JSON.parse(File.read(path)); value['evidence_sha256'] = Maintenance.file_sha(File.join(control, 'evidence.json')); Maintenance::RunStore.atomic(path, value)
      sha = Maintenance.file_sha(path); journal['steps'].last['output_sha256']['check.json'] = sha; store.save(journal)
      result_path = store.path(id, '.result.json'); result = JSON.parse(File.read(result_path)); result['steps'].last['output_sha256']['check.json'] = sha; Maintenance::RunStore.atomic(result_path, result)
      reject { Maintenance::PluginAttribution.report(store, id) }
    end
  ensure
    Maintenance::PluginAttribution.define_singleton_method(:input, original_method) if original_method
  end
  failures = 0
  @tests.each do |name, block|
    block.call; puts "PASS #{name}"
  rescue StandardError => e
    failures += 1; warn "FAIL #{name}: #{e.message}"
  end
  puts "#{@tests.size} plugin attribution contracts, #{failures} failures"
  exit(failures.zero? ? 0 : 1)
end
