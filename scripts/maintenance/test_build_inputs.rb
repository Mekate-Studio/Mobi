# frozen_string_literal: true

require_relative 'lib/build_inputs'
require_relative 'test_compatibility'

module BuildInputsTest
  @tests = []
  def self.test(name, &block); @tests << [name, block]; end
  def self.assert(value); raise 'assertion failed' unless value; end
  def self.reject
    yield; raise 'Expected refusal'
  rescue Maintenance::Failure
    true
  end
  def self.span(module_name, platform, plugin = '{cache}/selected.jar')
    native = platform != 'android'
    args = ['-Xplugin=' + plugin]
    args += ['-target', platform == 'iosArm64' ? 'ios_arm64' : 'ios_simulator_arm64'] if native
    attrs = { 'amper-module' => module_name, native ? 'version' : 'compiler-version' => '2.4.10', native ? 'args' : 'compiler-args' => args }
    attrs['exit-code'] = 0 if native
    { 'name' => native ? 'konanc' : 'kotlin-compilation', 'spanId' => 'a' * 16, 'status' => {},
      'attributes' => attrs.map { |key, value| { 'key' => key, 'value' => value.is_a?(Array) ? { 'arrayValue' => { 'values' => value.map { |v| { 'stringValue' => v } } } } : value.is_a?(Integer) ? { 'intValue' => value.to_s } : { 'stringValue' => value } } } }
  end
  def self.traces
    spans = Maintenance::BuildInputs::MODULES.flat_map { |name| %w[android iosArm64 iosSimulatorArm64].map { |p| span(name, p) } }
    [{ 'source' => 'build/logs/telemetry/kotlin_cli_traces.jsonl', 'raw_sha256' => 'a' * 64, 'payloads' => [{ 'resourceSpans' => [{ 'scopeSpans' => [{ 'spans' => spans }] }] }] }]
  end
  def self.delegated
    c = { 'kind' => 'maven', 'group' => 'org.jetbrains.kotlin', 'name' => 'kotlin-gradle-plugin', 'version' => '2.4.10' }
    v = { 'name' => 'runtime', 'attributes' => {} }
    rows = %w[classpath debugCompileClasspath debugRuntimeClasspath].map do |name|
      { 'project' => ':', 'owner' => name == 'classpath' ? 'settings' : 'project', 'configuration' => name,
        'resolvable' => true, 'state' => 'resolved', 'failures' => [], 'attributes' => {},
        'nodes' => [{ 'component' => c, 'variants' => [v] }], 'edges' => [],
        'artifacts' => [{ 'component' => c, 'name' => 'plugin.jar', 'variant' => v, 'identity' => { 'kind' => 'file', 'sha256' => 'b' * 64, 'bytes' => 5 } }] }
    end
    { 'schema' => 1, 'gradle' => '9.6.1', 'generated_task' => '_android-app_buildAndroidDebug', 'build_outcome' => 'passed', 'configurations' => rows }
  end
  def self.fixture
    Dir.mktmpdir do |root|
      Maintenance::RunStore.atomic(File.join(root, 'compiler-traces.json'), traces)
      Maintenance::RunStore.atomic(File.join(root, 'selected-plugin-artifacts.json'), { '{cache}/selected.jar' => { 'sha256' => 'c' * 64, 'bytes' => 10 } })
      Maintenance::RunStore.atomic(File.join(root, 'delegated-graphs.json'), [{ 'data' => delegated }])
      yield root
    end
  end
  test('actual invocation scope and artifact fingerprints remain separate from coordinates') do
    fixture do |root|
      r = Maintenance::BuildInputs.read(root)
      assert(r['invocations'].size == 15 && r['selected_plugin_artifacts'].size == 1)
      assert(r['delegated_queries'].first['package']['name'] == 'org.jetbrains.kotlin:kotlin-gradle-plugin')
      assert(r['missing_capabilities'].include?('compiler_plugin_coordinate_attribution') && !r['adoption_authorized'])
    end
  end
  test('new compiler selection requires a version-bound producer and rejects stale invocation versions') do
    t = traces
    t[0]['payloads'][0]['resourceSpans'][0]['scopeSpans'][0]['spans'].each do |span|
      span['attributes'].select { |a| %w[version compiler-version].include?(a['key']) }.each { |a| a['value']['stringValue'] = '2.4.20' }
    end
    assert(Maintenance::BuildInputs.invocations(t, compiler_version: '2.4.20').size == 15)
    reject { Maintenance::BuildInputs.invocations(t) }
    reject { Maintenance::BuildInputs.invocations(traces, compiler_version: '2.4.20') }
  end

  test('native joined target arguments match real telemetry and ambiguity refuses') do
    t = traces
    t[0]['payloads'][0]['resourceSpans'][0]['scopeSpans'][0]['spans'].each do |s|
      next unless s['name'] == 'konanc'
      values = s['attributes'].find { |a| a['key'] == 'args' }['value']['arrayValue']['values']
      target = values.pop['stringValue']; values.pop
      values << { 'stringValue' => '-target=' + target }
    end
    assert(Maintenance::BuildInputs.invocations(t).map { |c| c['platform'] }.uniq.sort == %w[android iosArm64 iosSimulatorArm64].sort)
    s = t[0]['payloads'][0]['resourceSpans'][0]['scopeSpans'][0]['spans'].find { |entry| entry['name'] == 'konanc' }
    s['attributes'].find { |a| a['key'] == 'args' }['value']['arrayValue']['values'] << { 'stringValue' => '-target=ios_simulator_arm64' }
    reject { Maintenance::BuildInputs.invocations(t) }
  end
  test('missing target module arguments and failed compiler exit refuse') do
    t = traces; t[0]['payloads'][0]['resourceSpans'][0]['scopeSpans'][0]['spans'][0]['attributes'].reject! { |a| a['key'] == 'compiler-args' }
    reject { Maintenance::BuildInputs.invocations(t) }
    s = span('shared-di', 'iosArm64'); s['attributes'].find { |a| a['key'] == 'exit-code' }['value']['intValue'] = '1'
    t = traces; t[0]['payloads'][0]['resourceSpans'][0]['scopeSpans'][0]['spans'] = [s]
    reject { Maintenance::BuildInputs.invocations(t) }
    s['attributes'].find { |a| a['key'] == 'exit-code' }['value']['intValue'] = 'invalid'
    reject { Maintenance::BuildInputs.invocations(t) }
    fixture do |root|
      t = traces; t[0]['payloads'][0]['resourceSpans'][0]['scopeSpans'][0]['spans'].pop
      Maintenance::RunStore.atomic(File.join(root, 'compiler-traces.json'), t)
      reject { Maintenance::BuildInputs.read(root) }
    end
  end
  test('extra missing and escaping plugin fingerprints refuse') do
    fixture do |root|
      Maintenance::RunStore.atomic(File.join(root, 'selected-plugin-artifacts.json'), {})
      reject { Maintenance::BuildInputs.read(root) }
    end
    Dir.mktmpdir do |root|
      File.symlink('/etc/hosts', File.join(root, 'escape.jar'))
      reject { Maintenance::BuildInputs.safe_file!(File.join(root, 'escape.jar'), root) }
    end
  end
  test('missing settings debug graphs unresolved edges and empty artifact hashes refuse') do
    d = delegated; d['configurations'] << { 'project' => ':android-app', 'owner' => 'project', 'configuration' => 'releaseCompileClasspath', 'resolvable' => true, 'attributes' => {}, 'state' => 'not_collected', 'reason' => 'outside_android_debug_main_scope' }
    Maintenance::BuildInputs.delegated!(d)
    d['configurations'].last['configuration'] = 'debugCompileClasspath'
    reject { Maintenance::BuildInputs.delegated!(d) }
    d = delegated; d['configurations'].shift; reject { Maintenance::BuildInputs.delegated!(d) }
    d = delegated; d['configurations'].pop; reject { Maintenance::BuildInputs.delegated!(d) }
    d = delegated; d['configurations'][0]['state'] = 'incomplete'; reject { Maintenance::BuildInputs.delegated!(d) }
    d = delegated; d['configurations'][0]['artifacts'][0]['identity']['sha256'] = ''; reject { Maintenance::BuildInputs.delegated!(d) }
    d = delegated; d['configurations'][0]['edges'] << { 'failure' => 'Unresolved' }; reject { Maintenance::BuildInputs.delegated!(d) }
  end
  test('opaque file injection retains fingerprints without invented Maven identity') do
    d = delegated; d['configurations'][0]['artifacts'][0]['component'] = { 'kind' => 'maven', 'group' => 'localModule', 'name' => '.m2.cache/selected.jar', 'version' => 'unspecified' }
    reject { Maintenance::BuildInputs.delegated!(d) }
    d = delegated; d['configurations'][1]['artifacts'][0]['component'] = { 'kind' => 'opaque', 'id' => 'd' * 64 }
    d['configurations'][1]['artifacts'][0]['identity'].merge!('kind' => 'directory', 'entries' => 2, 'digest_format' => 'sorted_relative_file_hashes_and_symlinks_v1')
    assert(Maintenance::BuildInputs.delegated!(d).size == 3)
    d['configurations'][1]['artifacts'][0]['identity'].delete('entries')
    reject { Maintenance::BuildInputs.delegated!(d) }
    d['configurations'][1]['artifacts'][0]['identity']['entries'] = 2
    d['configurations'][1]['artifacts'][0]['component']['id'] = '/Users/private.jar'
    reject { Maintenance::BuildInputs.delegated!(d) }
  end
  test('private content duplicate scopes and failed delegated builds refuse') do
    d = delegated; d['configurations'][0]['attributes']['path'] = '/Users/private'; reject { Maintenance::BuildInputs.delegated!(d) }
    d = delegated; d['configurations'] << d['configurations'][0]; reject { Maintenance::BuildInputs.delegated!(d) }
    d = delegated; d['build_outcome'] = 'failed'; reject { Maintenance::BuildInputs.delegated!(d) }
  end
  test('paired build reports replay producers extend queries and retain capability gaps') do
    modules = Maintenance::BuildInputs::MODULES
    log = modules.map do |name|
      "Dependencies of module #{name}:\n" + %w[main test].product(%w[COMPILE RUNTIME]).map do |usage, scope|
        "Module #{name}\n│ - #{usage}\n│ - scope = #{scope}\n│ - platforms = [android, iosArm64, iosSimulatorArm64]\n╰─── example:runtime:1.0.0\n"
      end.join("\n")
    end.join("\n")
    declarations = modules.to_h { |name| [name + '/module.yaml', "product:\n  type: kmp/lib\n  platforms: [android, iosArm64, iosSimulatorArm64]\n"] }
    declarations['project.yaml'] = "modules: [#{modules.join(', ')}]\n"; declarations['kotlin'] = "kotlin_cli_version=0.12.2\n"
    manifest = declarations.to_h { |p, content| [p, { 'sha256' => Digest::SHA256.hexdigest(content), 'executable' => false }] }
    fixture do |control|
      refs = { 'source-manifest' => manifest, 'direct-source-manifest' => manifest, 'resolution-declarations' => declarations,
               'resolved-graphs' => Maintenance::KotlinEvidence.graphs(log, modules: modules, version: '0.12.2'),
               'downloaded-artifacts' => { 'cache' => {}, 'home' => {} }, 'build-inputs' => Maintenance::BuildInputs.read(control) }
      %w[compiler-traces selected-plugin-artifacts delegated-graphs].each { |name| refs[name] = JSON.parse(File.read(File.join(control, name + '.json'))) }
      phases = %w[baseline candidate].to_h { |phase| [phase, Marshal.load(Marshal.dump(refs))] }
      CompatibilityTest.report_fixture('direct-build-inputs', references: phases, dependency_log: log) do |store, id, profile|
        report = Maintenance::CompatibilityReport.read(store, id)
        assert(report['build_inputs']['candidate']['invocations'].size == 15)
        assert(report['direct_resolution']['candidate']['advisory_queries']['queries'].size == 2)
        assert(report['missing_capabilities'].include?('compiler_plugin_resolution') && report['bridge_retirement'] == 'defer')
        file = File.join(store.path(id), 'steps', 'candidate-' + profile, 'build-inputs.json')
        data = JSON.parse(File.read(file)); data['delegated_queries'].clear; Maintenance::RunStore.atomic(file, data)
        CompatibilityTest.change_phase_evidence(store, id, profile, 'candidate') { |e| e['build-inputs']['sha256'] = Maintenance.file_sha(file) }
        reject { Maintenance::CompatibilityReport.read(store, id) }
      end
    end
  end
  test('retained upstream report refuses bridge absence claims') do
    modules = Maintenance::BuildInputs::MODULES
    log = modules.map do |name|
      "Dependencies of module #{name}:\n" + %w[main test].product(%w[COMPILE RUNTIME]).map do |usage, scope|
        "Module #{name}\n│ - #{usage}\n│ - scope = #{scope}\n│ - platforms = [android, iosArm64, iosSimulatorArm64]\n╰─── example:runtime:1.0.0\n"
      end.join("\n")
    end.join("\n")
    declarations = modules.to_h { |name| [name + '/module.yaml', "product:\n  type: kmp/lib\n  platforms: [android, iosArm64, iosSimulatorArm64]\n"] }
    declarations['project.yaml'] = "modules: [#{modules.join(', ')}]\n"; declarations['kotlin'] = "kotlin_cli_version=0.12.2\n"
    manifest = declarations.to_h { |p, content| [p, { 'sha256' => Digest::SHA256.hexdigest(content), 'executable' => false }] }
    fixture do |control|
      refs = { 'source-manifest' => manifest, 'direct-source-manifest' => manifest, 'resolution-declarations' => declarations,
               'resolved-graphs' => Maintenance::KotlinEvidence.graphs(log, modules: modules, version: '0.12.2'),
               'downloaded-artifacts' => { 'cache' => {}, 'home' => {} }, 'build-inputs' => Maintenance::BuildInputs.read(control) }
      %w[compiler-traces selected-plugin-artifacts delegated-graphs].each { |name| refs[name] = JSON.parse(File.read(File.join(control, name + '.json'))) }
      phases = %w[baseline candidate].to_h { |phase| [phase, Marshal.load(Marshal.dump(refs))] }
      CompatibilityTest.report_fixture('upstream-build-inputs', references: phases, dependency_log: log) do |store, id, profile|
        report = Maintenance::CompatibilityReport.read(store, id)
        assert(report['build_inputs']['candidate']['invocations'].size == 15)
        assert(report['direct_resolution']['candidate']['advisory_queries']['queries'].size == 2)
        assert(report['missing_capabilities'].include?('compiler_plugin_resolution') && report['bridge_retirement'] == 'defer')
        CompatibilityTest.change_phase_evidence(store, id, profile, 'candidate') { |e| e['bridge_unavailable'] = true }
        reject { Maintenance::CompatibilityReport.read(store, id) }
      end
    end
  end
  test('bundled files use unique baseline component bytes and never bundled filename versions') do
    base = delegated; candidate = delegated
    candidate['configurations'][0]['artifacts'][0]['component'] = { 'kind' => 'opaque', 'id' => 'd' * 64 }
    candidate['configurations'][0]['artifacts'][0]['name'] = 'looks-like-999.0.0.jar'
    report = Maintenance::BundledInputs.match([{ 'data' => base }], [{ 'data' => candidate }])
    assert(report['matches'].size == 1 && report['advisory_queries'][0]['version'] == '2.4.10')
    assert(report['candidate_maven_resolution'] == 'not_inferred' && !report['remediation_verified'])
    assert(report['producer_sha256']['candidate'] == Maintenance.digest([{ 'data' => candidate }]))
  end
  test('changed bytes and ambiguous reference components remain unassigned and unqueried') do
    base = delegated; candidate = delegated
    artifact = candidate['configurations'][0]['artifacts'][0]
    artifact['component'] = { 'kind' => 'opaque', 'id' => 'd' * 64 }
    artifact['identity']['sha256'] = 'e' * 64
    report = Maintenance::BundledInputs.match([{ 'data' => base }], [{ 'data' => candidate }])
    assert(report['advisory_queries'].empty? && report['unassigned'][0]['state'] == 'unattributed')
    artifact['identity']['sha256'] = 'b' * 64
    other = Marshal.load(Marshal.dump(base['configurations'][0]['artifacts'][0]))
    other['component'] = { 'kind' => 'maven', 'group' => 'example', 'name' => 'other', 'version' => '1.0.0' }
    base['configurations'][0]['nodes'] << { 'component' => other['component'], 'variants' => [other['variant']] }
    base['configurations'][0]['artifacts'] << other
    report = Maintenance::BundledInputs.match([{ 'data' => base }], [{ 'data' => candidate }])
    assert(report['state'] == 'attribution_incomplete' && report['advisory_queries'].empty? && report['unassigned'][0]['state'] == 'ambiguous_reference')
    base['configurations'][0]['state'] = 'incomplete'
    reject { Maintenance::BundledInputs.match([{ 'data' => base }], [{ 'data' => candidate }]) }
  end
  if $PROGRAM_NAME == __FILE__
    failures = 0
    @tests.each do |name, block|
      block.call; puts "PASS #{name}"
    rescue StandardError => e
      failures += 1; warn "FAIL #{name}: #{e.message}\n#{e.backtrace.first(2).join("\n")}"
    end
    puts "#{@tests.size} build input contracts, #{failures} failures"
    exit(failures.zero? ? 0 : 1)
  end
end
