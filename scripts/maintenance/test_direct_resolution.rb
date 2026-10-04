# frozen_string_literal: true

require_relative 'test_compatibility'

module DirectResolutionTest
  @tests = []
  def self.test(name, &block); @tests << [name, block]; end
  def self.assert(value); raise 'assertion failed' unless value; end
  def self.reject(&block); CompatibilityTest.reject(/resolution|graph|advisory|Advisory|Graph-only|artifact|Parsed|Malformed/i, &block); end
  def self.graph_text
    "Dependencies of module sample:\n" + %w[main test].product(%w[COMPILE RUNTIME]).map do |usage, scope|
      "Module sample\n│ - #{usage}\n│ - scope = #{scope}\n│ - platforms = [android, iosArm64, iosSimulatorArm64]\n├─── example:lib:1.0.0 -> 2.0.0@aar\n╰─── example:constraint:3.0.0 (c)\n"
    end.join("\n")
  end
  def self.references
    graphs = Maintenance::KotlinEvidence.graphs(graph_text, modules: ['sample'], version: '0.12.2')
    declarations = { 'project.yaml' => "modules: [sample]\n", 'kotlin' => "kotlin_cli_version=0.12.2\n", 'sample/module.yaml' => "product:\n  type: kmp/lib\n  platforms: [android, iosArm64, iosSimulatorArm64]\n" }
    manifest = declarations.to_h { |path, value| [path, { 'sha256' => Digest::SHA256.hexdigest(value), 'executable' => false }] }
    refs = { 'source-manifest' => manifest, 'direct-source-manifest' => manifest, 'resolved-graphs' => graphs, 'resolution-declarations' => declarations, 'downloaded-artifacts' => { 'cache' => {}, 'home' => { 'lib.jar' => { 'sha256' => 'a' * 64, 'bytes' => 5 } } } }
    %w[baseline candidate].to_h { |phase| [phase, Marshal.load(Marshal.dump(refs))] }
  end
  def self.report
    { 'state' => 'checks_passed', 'run_id' => 'a' * 32, 'result_sha256' => 'b' * 64,
      'direct_resolution' => { 'candidate' => { 'advisory_queries' => { 'queries' => [{ 'package' => { 'ecosystem' => 'Maven', 'name' => 'example:lib' }, 'version' => '2.0.0' }] } } } }
  end
  def self.transport(results: [{}], status: 200)
    lambda do |url, payload|
      body = JSON.generate(payload ? { 'results' => results } : { 'id' => url.split('/').last, 'affected' => [{ 'package' => { 'name' => 'example:lib' } }], 'modified' => '2026-10-02T00:00:00Z' })
      { 'url' => url, 'request' => payload, 'status' => status, 'retrieved_at' => Time.now.utc.iso8601, 'body' => body, 'response_sha256' => Digest::SHA256.hexdigest(body) }
    end
  end
  test('graph-only worker uses captured project declarations and skips native setup') do
    CompatibilityTest.fixture do |root|
      FileUtils.mkdir_p(File.join(root, 'sample'))
      File.write(File.join(root, 'sample/module.yaml'), references['baseline']['resolution-declarations']['sample/module.yaml'])
      File.write(File.join(root, 'project.yaml'), "modules: [sample]\n")
      Dir.mktmpdir do |control|
        worker = Maintenance::CompatibilityCheck.allocate
        { work: root, control: control, output: control, cache: control, modules: ['sample'], version: '0.12.2',
          profile: 'direct-resolution', resolution_only: true, collect_resolution: true, direct: false, env: {}, host: { 'java_home' => control, 'developer_dir' => control },
          manifest: {}, report: { 'phase' => 'baseline', 'cells' => {}, 'commands' => [], 'missing_capabilities' => Maintenance::DirectResolution::GAPS } }.each do |name, value|
          worker.instance_variable_set('@' + name.to_s, value)
        end
        worker.define_singleton_method(:verify_source!) {}
        worker.define_singleton_method(:native_setup) { raise 'Native setup must not run' }
        worker.define_singleton_method(:bridge_compile) { raise 'Bridge compile must not run' }
        worker.define_singleton_method(:cli) do |name, *_args|
          case name
          when 'version' then 'Kotlin Toolchain version 0.12.2 test'
          when 'settings' then "Module: sample\nsettings:\n  kotlin:\n    version: 2.4.10\n"
          when 'dependencies' then DirectResolutionTest.graph_text
          else raise 'Unexpected CLI call'
          end
        end
        previous_home = ENV['HOME']
        begin
          ENV['HOME'] = control
          status = worker.run
        ensure
          ENV['HOME'] = previous_home
        end
        raise JSON.generate(worker.report.slice('failure', 'exception_class', 'evidence_error')) unless status == 'passed'
        assert(worker.report['source_preservation'] == 'verified')
        declared = JSON.parse(File.read(File.join(control, 'resolution-declarations.json')))
        assert(declared['project.yaml'] == "modules: [sample]\n")
        assert(worker.report['cells']['ios-test']['status'] == 'not_attempted')
      end
    end
  end
  test('graph-only report verifies selected queries and retains native/artifact gaps') do
    CompatibilityTest.report_fixture('direct-resolution', references: references) do |store, id, _profile|
      result = Maintenance::CompatibilityReport.read(store, id)
      direct = result['direct_resolution']['candidate']
      assert(direct['roots'] == 4 && direct['fingerprint_count'] == 1)
      assert(direct['advisory_queries']['queries'].map { |q| q['version'] } == ['2.0.0'])
      assert(direct['advisory_queries']['constraint_nodes_excluded'] == 4)
      assert((Maintenance::DirectResolution::GAPS - result['missing_capabilities']).empty?)
      assert(result['phases'].all? { |p| p['cells']['ios-test']['status'] == 'not_attempted' })
    end
  end
  test('declared target omission refuses even with complete module roots') do
    refs = references
    refs['candidate']['resolved-graphs']['graphs'].each { |g| g['platforms'].delete('iosArm64') }
    CompatibilityTest.report_fixture('direct-resolution', references: refs) { |store, id, _p| reject { Maintenance::CompatibilityReport.read(store, id) } }
  end
  test('rewritten parsed graph hashes cannot bypass raw output replay') do
    refs = references
    refs['candidate']['resolved-graphs']['graphs'][0]['nodes'][0]['coordinate']['selected'] = '9.0.0'
    CompatibilityTest.report_fixture('direct-resolution', references: refs) { |store, id, _p| reject { Maintenance::CompatibilityReport.read(store, id) } }
  end
  test('graph-only reports refuse invented native success and absent bridge proof') do
    CompatibilityTest.report_fixture('direct-resolution', references: references) do |store, id, profile|
      CompatibilityTest.change_phase_evidence(store, id, profile, 'candidate') { |e| e['cells']['ios-test']['status'] = 'passed' }
      reject { Maintenance::CompatibilityReport.read(store, id) }
    end
    CompatibilityTest.report_fixture('direct-resolution', references: references) do |store, id, profile|
      CompatibilityTest.change_phase_evidence(store, id, profile, 'candidate') { |e| e['bridge_unavailable'] = false }
      CompatibilityTest.reject(/bridge absence/) { Maintenance::CompatibilityReport.read(store, id) }
    end
  end
  test('unsafe cache fingerprint identity refuses') do
    refs = references
    refs['candidate']['downloaded-artifacts']['home']['../lib.jar'] = refs['candidate']['downloaded-artifacts']['home'].delete('lib.jar')
    CompatibilityTest.report_fixture('direct-resolution', references: refs) { |store, id, _p| reject { Maintenance::CompatibilityReport.read(store, id) } }
  end
  test('complete exact provider lookup still preserves surface coverage gaps') do
    checkpoints = []
    receipt = Maintenance::AdvisoryReview.collect(report, transport: transport, checkpoint: ->(packet) { checkpoints << Marshal.load(Marshal.dump(packet)) })
    assert(checkpoints.first['batches'].empty? && checkpoints.last == receipt)
    summary = Maintenance::AdvisoryReview.verify!(receipt, report)
    assert(summary['state'] == 'provider_complete' && summary['query_count'] == 1)
    assert(summary['dependency_surface'] == 'incomplete' && !summary['adoption_authorized'])
  end
  test('findings fetch full records and require triage') do
    receipt = Maintenance::AdvisoryReview.collect(report, transport: transport(results: [{ 'vulns' => [{ 'id' => 'GHSA-test', 'modified' => '2026-10-02T00:00:00Z' }] }]))
    summary = Maintenance::AdvisoryReview.verify!(receipt, report)
    assert(receipt['records'].size == 1 && summary['state'] == 'triage_required')
    receipt['records'].clear
    assert(Maintenance::AdvisoryReview.verify!(receipt, report)['state'] == 'incomplete')
  end
  test('HTTP malformed cardinality and pagination failures never mean no findings') do
    [transport(status: 403), transport(results: []), transport(results: [{ 'error' => 'unknown' }]), transport(results: [{ 'next_page_token' => 'more' }])].each do |provider|
      receipt = Maintenance::AdvisoryReview.collect(report, transport: provider)
      assert(Maintenance::AdvisoryReview.verify!(receipt, report)['state'] == 'incomplete')
    end
  end
  test('advisory binding response digests future time and freshness are checked') do
    receipt = Maintenance::AdvisoryReview.collect(report, transport: transport)
    changed = Marshal.load(Marshal.dump(receipt)); changed['queries_sha256'] = 'c' * 64
    reject { Maintenance::AdvisoryReview.verify!(changed, report) }
    changed = Marshal.load(Marshal.dump(receipt)); changed['batches'][0]['body'] = '{}'
    reject { Maintenance::AdvisoryReview.verify!(changed, report) }
    changed = Marshal.load(Marshal.dump(receipt)); changed['batches'][0]['retrieved_at'] = (Time.now.utc + 60).iso8601
    reject { Maintenance::AdvisoryReview.verify!(changed, report) }
    assert(Maintenance::AdvisoryReview.verify!(receipt, report, now: Time.now.utc + 86_401)['state'] == 'incomplete')
  end
  test('baseline advisory receipt cannot be relabeled as a candidate lookup') do
    pair = report
    pair['direct_resolution']['baseline'] = { 'advisory_queries' => { 'queries' => [{ 'package' => { 'ecosystem' => 'Maven', 'name' => 'example:baseline' }, 'version' => '1.0.0' }] } }
    receipt = Maintenance::AdvisoryReview.collect(pair, phase: 'baseline', transport: transport)
    assert(Maintenance::AdvisoryReview.verify!(receipt, pair)['scope'] == 'baseline_named_resolved_maven_packages_only')
    receipt.delete('phase')
    reject { Maintenance::AdvisoryReview.verify!(receipt, pair) }
  end
  test('reference byte attributed queries retain their explicit scope and cannot be relabeled resolved') do
    pair = report; pair['bundled_settings_inputs'] = { 'matches' => [{ 'evidence_kind' => 'unique_baseline_component_byte_match' }] }
    receipt = Maintenance::AdvisoryReview.collect(pair, transport: transport)
    assert(Maintenance::AdvisoryReview.verify!(receipt, pair)['scope'] == 'candidate_named_and_reference_byte_attributed_packages_only')
    receipt.delete('query_evidence')
    reject { Maintenance::AdvisoryReview.verify!(receipt, pair) }
  end
  failures = 0
  @tests.each do |name, block|
    block.call; puts "PASS #{name}"
  rescue StandardError => error
    failures += 1; warn "FAIL #{name}: #{error.message}\n#{error.backtrace.first(3).join("\n")}"
  end
  puts "#{@tests.size} direct-resolution contracts, #{failures} failures"
  exit(failures.zero? ? 0 : 1)
end
