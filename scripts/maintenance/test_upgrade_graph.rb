# frozen_string_literal: true

require_relative 'lib/upgrade_graph'

module UpgradeGraphTest
  @tests = []
  def self.test(name, &block); @tests << [name, block]; end
  def self.assert(value); raise 'assertion failed' unless value; end
  def self.reject
    yield
    raise 'expected refusal'
  rescue Maintenance::Failure
    nil
  end
  def self.fixture
    component = { 'kind' => 'maven', 'group' => 'example', 'name' => 'library', 'version' => '1.0.0' }
    rows = %w[iosArm64CompileKlibraries iosArm64TestCompileKlibraries iosSimulatorArm64CompileKlibraries iosSimulatorArm64TestCompileKlibraries classpath].map do |name|
      { 'project' => ':shared-kit', 'owner' => name == 'classpath' ? 'buildscript' : 'project', 'configuration' => name,
        'resolvable' => true, 'attributes' => {}, 'state' => 'resolved', 'failures' => [],
        'nodes' => [{ 'component' => component, 'variants' => [] }], 'edges' => [],
        'artifacts' => [{ 'component' => component, 'name' => 'library.jar', 'variant' => { 'name' => 'runtime', 'attributes' => {} }, 'identity' => { 'kind' => 'file', 'sha256' => 'a' * 64, 'bytes' => 10 } }] }
    end
    { 'schema' => 1, 'gradle' => '9.6.1', 'configurations' => rows }
  end
  test('strict graph retains target/plugin scope and artifact hashes') do
    data = fixture
    parsed = Maintenance::UpgradeGraph.parse("diagnostic\nMOBI_RESOLUTION_JSON=#{JSON.generate(data)}\nBUILD SUCCESSFUL\n")
    assert(parsed == data)
    assert(Maintenance::UpgradeGraph.diff(data, data)['changed'].empty?)
  end
  test('directory artifacts require a complete tree fingerprint') do
    data = fixture
    identity = data['configurations'][0]['artifacts'][0]['identity']
    identity.merge!('kind' => 'directory', 'entries' => 3, 'digest_format' => 'sorted_relative_file_hashes_and_symlinks_v1')
    assert(Maintenance::UpgradeGraph.validate!(data) == data)
    identity.delete('entries')
    reject { Maintenance::UpgradeGraph.validate!(data) }
  end
  test('Gradle buildscript root components retain their explicit identity') do
    data = fixture
    root = { 'kind' => 'project', 'id' => 'root' }
    row = data['configurations'].last
    row['nodes'] << { 'component' => root, 'variants' => [] }
    row['edges'] << { 'from' => root, 'selected' => row['nodes'][0]['component'], 'requested' => 'example:library:1.0.0', 'variant' => { 'name' => 'runtime', 'attributes' => {} } }
    assert(Maintenance::UpgradeGraph.validate!(data) == data)
    root['id'] = '/Users/example/root'
    reject { Maintenance::UpgradeGraph.validate!(data) }
  end
  test('missing malformed or duplicate machine output refuses') do
    reject { Maintenance::UpgradeGraph.parse('BUILD SUCCESSFUL') }
    reject { Maintenance::UpgradeGraph.parse("MOBI_RESOLUTION_JSON={\n") }
    line = "MOBI_RESOLUTION_JSON=#{JSON.generate(fixture)}\n"
    reject { Maintenance::UpgradeGraph.parse(line + line) }
  end
  test('missing target test and plugin scope refuses') do
    [0, 1, 4].each do |index|
      data = fixture; data['configurations'].delete_at(index)
      reject { Maintenance::UpgradeGraph.validate!(data) }
    end
  end
  test('unresolved configuration and empty artifact identity cannot pass') do
    data = fixture; data['configurations'][0]['state'] = 'incomplete'
    reject { Maintenance::UpgradeGraph.validate!(data) }
    data = fixture; data['configurations'][0]['artifacts'][0]['identity']['sha256'] = ''
    reject { Maintenance::UpgradeGraph.validate!(data) }
    data = fixture; data['configurations'][0]['edges'] = [{ 'from' => { 'kind' => 'project', 'id' => 'project :shared-kit' }, 'requested' => 'unknown', 'failure' => 'Failure' }]
    reject { Maintenance::UpgradeGraph.validate!(data) }
  end
  test('duplicate scopes and private paths refuse') do
    data = fixture; data['configurations'] << data['configurations'][0]
    reject { Maintenance::UpgradeGraph.validate!(data) }
    data = fixture; data['configurations'][0]['attributes']['private'] = '/Users/example/cache'
    reject { Maintenance::UpgradeGraph.validate!(data) }
  end
  test('edges and artifacts cannot claim absent nodes or missing variants') do
    data = fixture
    data['configurations'][0]['artifacts'][0]['component'] = { 'kind' => 'maven', 'group' => 'example', 'name' => 'missing', 'version' => '1.0' }
    reject { Maintenance::UpgradeGraph.validate!(data) }
    data = fixture; data['configurations'][0]['artifacts'][0]['variant'] = {}
    reject { Maintenance::UpgradeGraph.validate!(data) }
    data = fixture
    node = data['configurations'][0]['nodes'][0]['component']
    data['configurations'][0]['edges'] << { 'from' => node, 'selected' => node.merge('name' => 'missing'), 'requested' => 'example:missing:1.0', 'variant' => { 'name' => 'runtime', 'attributes' => {} } }
    reject { Maintenance::UpgradeGraph.validate!(data) }
  end
  test('advisory requests use resolved versions and retain packaging normalization') do
    graph = { 'format' => 'toolchain-pretty-graph-v1', 'graphs' => [{ 'nodes' => [{ 'coordinate' => { 'group' => 'example', 'name' => 'library', 'selected' => '2.0.0@aar' } }] }] }
    graph['graphs'][0]['nodes'] << { 'constraint' => true, 'coordinate' => { 'group' => 'example', 'name' => 'library', 'selected' => '3.0.0' } }
    result = Maintenance::UpgradeGraph.maven_queries(fixture, graph)
    assert(result['queries'].map { |query| query['version'] } == %w[1.0.0 2.0.0])
    assert(result['normalizations'][0]['label_version'] == '2.0.0@aar')
    assert(result['constraint_nodes_excluded'] == 1)
    assert(result['provider_state'] == 'not_queried' && result['adoption_authorized'] == false)
    graph['graphs'][0]['nodes'][0]['coordinate']['selected'] = '2.0.0@unknown'
    reject { Maintenance::UpgradeGraph.maven_queries(fixture, graph) }
    reject { Maintenance::UpgradeGraph.maven_queries(fixture, {}) }
  end
  test('variant artifact and edge changes at unchanged version remain visible') do
    before = fixture
    after = fixture; after['configurations'][0]['artifacts'][0]['identity']['sha256'] = 'b' * 64
    assert(Maintenance::UpgradeGraph.diff(before, after)['changed'].size == 1)
    after = fixture; after['configurations'][1]['attributes']['usage'] = 'changed'
    assert(Maintenance::UpgradeGraph.diff(before, after)['changed'].size == 1)
    after = fixture; after['configurations'][2]['edges'] << { 'from' => after['configurations'][2]['nodes'][0]['component'], 'selected' => after['configurations'][2]['nodes'][0]['component'], 'requested' => 'example:library:1.0.0', 'variant' => { 'name' => 'runtime', 'attributes' => {} } }
    assert(Maintenance::UpgradeGraph.diff(before, after)['changed'].size == 1)
  end
  failures = 0
  @tests.each do |name, block|
    block.call; puts "PASS #{name}"
  rescue StandardError => error
    failures += 1; warn "FAIL #{name}: #{error.message}"
  end
  puts "#{@tests.size} tests, #{failures} failures"
  exit(failures.zero? ? 0 : 1)
end
