# frozen_string_literal: true

require_relative 'lib/risk_acceptance'

module RiskAcceptanceTest
  NOW = Time.utc(2026, 10, 4, 6)
  @tests = []
  def self.test(name, &block); @tests << [name, block]; end
  def self.assert(value); raise 'assertion failed' unless value; end
  def self.fixture
    artifact = { 'component' => { 'kind' => 'maven', 'group' => 'example', 'name' => 'input', 'version' => '1.0' }, 'identity' => { 'kind' => 'file', 'sha256' => 'a' * 64, 'bytes' => 10 } }
    finding = { 'id' => 'GHSA-test-test-test', 'severity' => 'CRITICAL', 'artifacts' => [artifact] }
    decision = { 'schema' => 1, 'state' => 'approved_conditional', 'approved' => true, 'revoked' => false, 'approval_reference' => 'explicit maintainer decision',
                 'reason' => 'bounded inherited risk', 'controls' => ['owned source builds'], 'starts_at' => NOW.iso8601, 'expires_at' => (NOW + 30 * 86_400).iso8601, 'allowed_operations' => ['repository_tests'],
                 'toolchain' => '0.13.0', 'distribution_sha256' => 'b' * 64, 'applied_patch_sha256' => 'c' * 64, 'source_binding_sha256' => 'd' * 64,
                 'known_findings' => [finding.slice('id', 'severity')], 'findings' => [finding],
                 'age_exception' => { 'approved' => true, 'version' => '0.13.0', 'published_at' => '2026-10-01T06:36:56Z', 'decision_at' => NOW.iso8601 } }
    evidence = decision.slice('toolchain', 'distribution_sha256', 'applied_patch_sha256', 'source_binding_sha256').merge(
      'operation' => 'repository_tests', 'compatibility' => 'passed', 'attribution' => 'measured_file_identities_accounted_for', 'findings' => [finding],
      'release' => { 'complete' => true, 'retrieved_at' => NOW.iso8601, 'response_sha256' => 'e' * 64, 'published_at' => '2026-10-01T06:36:56Z' },
      'advisory' => { 'complete' => true, 'retrieved_at' => NOW.iso8601, 'response_sha256' => 'f' * 64 })
    [decision, evidence]
  end
  def self.blocked
    d, e = fixture; yield d, e
    assert(Maintenance::RiskAcceptance.evaluate(d, e, now: NOW)['state'] == 'blocked')
  end
  test('exact approved scoped risk preserves findings, severity and real age without auto adoption') do
    d, e = fixture; r = Maintenance::RiskAcceptance.evaluate(d, e, now: NOW)
    assert(r['state'] == 'accepted_risk_for_scoped_manual_use' && r['findings'] == e['findings'] && !r['adoption_authorized'] && !r['remediation_verified'] && r['age_state'] == 'age_blocked_with_explicit_exception')
  end
  def self.candidate_fixture
    d, e = fixture
    d['toolchain'] = e['toolchain'] = '0.14.1'
    d['age_exception']['version'] = '0.14.1'
    d['age_exception']['scope'] = 'scoped_manual_risk_use'
    e['review_packet_sha256'] = d['review_packet_sha256'] = '1' * 64
    e['coverage_gaps'] = d['acknowledged_coverage_gaps'] = %w[unassigned_or_ambiguous_files shaded_or_native_code configurations_outside_android_debug unsupported_transform_observer device_exact_floor_signed_delivery]
    [d, e]
  end
  test('0.14.1 requires its own exact packet and explicit coverage-gap acknowledgement') do
    d, e = candidate_fixture
    r = Maintenance::RiskAcceptance.evaluate(d, e, now: NOW)
    assert(r['state'] == 'accepted_risk_for_scoped_manual_use' && !r['adoption_authorized'])
  end
  test('0.14.1 cannot reuse an old approval or omit, change or hide packet coverage') do
    d, e = candidate_fixture
    old, = fixture
    assert(Maintenance::RiskAcceptance.evaluate(old, e, now: NOW)['state'] == 'blocked')
    [->(x) { x.delete('review_packet_sha256') }, ->(x) { x['review_packet_sha256'] = '2' * 64 },
     ->(x) { x['acknowledged_coverage_gaps'] = [] }].each do |change|
      decision = Marshal.load(Marshal.dump(d)); change.call(decision)
      assert(Maintenance::RiskAcceptance.evaluate(decision, e, now: NOW)['state'] == 'blocked')
    end
    e['coverage_gaps'] = []
    d['acknowledged_coverage_gaps'] = []
    assert(Maintenance::RiskAcceptance.evaluate(d, e, now: NOW)['state'] == 'blocked')
  end
  test('qualification-only age waiver cannot authorize candidate manual risk use') do
    d, e = candidate_fixture; d['age_exception']['scope'] = 'isolated_compatibility_assessment'
    assert(Maintenance::RiskAcceptance.evaluate(d, e, now: NOW)['state'] == 'blocked')
  end
  test('a blocked candidate cannot claim an approved age exception or accepted risks') do
    d, e = candidate_fixture; d['age_exception']['approved'] = false
    r = Maintenance::RiskAcceptance.evaluate(d, e, now: NOW)
    assert(r['state'] == 'blocked' && r['age_state'] == 'age_blocked' && r['accepted_risk_ids'].empty?)
  end
  test('nearby unqualified releases remain unsupported') do
    %w[0.14.0 0.14.2 0.15.0].each do |version|
      d, e = candidate_fixture; d['toolchain'] = e['toolchain'] = version
      begin
        Maintenance::RiskAcceptance.evaluate(d, e, now: NOW); raise 'Expected version refusal'
      rescue Maintenance::Failure
      end
    end
  end
  test('pending or revoked approval refuses') { blocked { |d, _| d['approved'] = false }; blocked { |d, _| d['revoked'] = true } }
  test('missing rationale or controls refuse') { blocked { |d, _| d['reason'] = '' }; blocked { |d, _| d['controls'] = [] } }
  test('expiry, future and oversized windows refuse') do
    blocked { |d, _| d['expires_at'] = NOW.iso8601 }
    blocked { |d, _| d['starts_at'] = (NOW + 1).iso8601 }
    blocked { |d, _| d['expires_at'] = (NOW + 31 * 86_400).iso8601 }
  end
  test('distribution, patch and source drift refuse') { %w[distribution_sha256 applied_patch_sha256 source_binding_sha256].each { |k| blocked { |_, e| e[k] = '0' * 64 } } }
  test('new finding and changed severity refuse') do
    blocked { |_, e| e['findings'] = Marshal.load(Marshal.dump(e['findings'])); e['findings'][0]['id'] = 'GHSA-newx-newx-newx' }
    blocked { |_, e| e['findings'] = Marshal.load(Marshal.dump(e['findings'])); e['findings'][0]['severity'] = 'unknown' }
  end
  test('changed artifact bytes or version refuses') do
    %w[bytes version].each do |key|
      blocked do |_, e|
        e['findings'] = Marshal.load(Marshal.dump(e['findings'])); a = e['findings'][0]['artifacts'][0]
        key == 'bytes' ? a['identity']['bytes'] = 11 : a['component']['version'] = '2.0'
      end
    end
  end
  test('provider incompleteness, staleness and future timestamps refuse') do
    blocked { |_, e| e['advisory']['complete'] = false }
    blocked { |_, e| e['release']['retrieved_at'] = (NOW - 86_401).iso8601 }
    blocked { |_, e| e['advisory']['retrieved_at'] = (NOW + 1).iso8601 }
  end
  test('compatibility and attribution remain independent required gates') { blocked { |_, e| e['compatibility'] = 'failed' }; blocked { |_, e| e['attribution'] = 'incomplete' } }
  test('credentialed release and bridge transitions remain outside scope') { %w[credentialed_release_delivery bridge_default_switch physical_bridge_deletion].each { |o| blocked { |_, e| e['operation'] = o } } }
  test('age waiver must match exact release and decision') { blocked { |d, _| d['age_exception']['approved'] = false }; blocked { |d, _| d['age_exception']['version'] = '0.13.1' } }
  test('malformed and duplicate decisions cannot become accepted') do
    [nil, {}].each do |d|
      begin; Maintenance::RiskAcceptance.evaluate(d, {}, now: NOW); raise 'Expected refusal'; rescue Maintenance::Failure; end
    end
    d, e = fixture; d['known_findings'] *= 2
    begin; Maintenance::RiskAcceptance.evaluate(d, e, now: NOW); raise 'Expected refusal'; rescue Maintenance::Failure; end
  end
  failures = @tests.count do |name, block|
    block.call; puts "PASS #{name}"; false
  rescue StandardError => error
    warn "FAIL #{name}: #{error.message}"; true
  end
  puts "#{@tests.size} risk acceptance contracts, #{failures} failures"
  exit 1 unless failures.zero?
end
