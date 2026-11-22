# frozen_string_literal: true

require_relative 'lib/toolchain_risk_packet'

module ToolchainRiskPacketTest
  NOW = Time.utc(2026, 11, 22, 12)
  @tests = []
  def self.test(name, &block); @tests << [name, block]; end
  def self.assert(value); raise 'assertion failed' unless value; end
  def self.packet(url, body, request = nil)
    raw = JSON.generate(body)
    { 'url' => url, 'request' => request, 'body' => raw, 'status' => 200,
      'retrieved_at' => NOW.iso8601, 'response_sha256' => Digest::SHA256.hexdigest(raw) }
  end
  def self.fixture
    Dir.mktmpdir('risk-packet-') do |root|
      system('/usr/bin/git', 'init', '-q', root, exception: true)
      File.write(File.join(root, '.gitignore'), "/.maintenance/\n")
      File.write(File.join(root, 'kotlin'), "kotlin_cli_version=0.14.1\nkotlin_cli_sha256=#{'a' * 64}\n")
      dir = File.join(root, '.maintenance/review'); FileUtils.mkdir_p(dir)
      write = lambda do |name, data|
        path = File.join(dir, name); File.write(path, JSON.generate(data))
        { 'path' => name, 'sha256' => Maintenance.file_sha(path) }
      end
      artifact = { 'component' => { 'kind' => 'maven', 'group' => 'example', 'name' => 'input', 'version' => '1' },
                   'identity' => { 'kind' => 'file', 'sha256' => 'b' * 64, 'bytes' => 42 } }
      query = { 'package' => { 'ecosystem' => 'Maven', 'name' => 'example:input' }, 'version' => '1' }
      inputs = { 'phases' => { 'candidate' => { 'version' => '0.14.1', 'owners' => { 'named' => { 'queries' => [query] } } } } }
      input_ref = write.call('inputs.json', inputs)
      finding = { 'id' => 'GHSA-test-test-test', 'modified' => NOW.iso8601,
                  'affected' => [{ 'package' => query['package'] }], 'database_specific' => { 'severity' => 'HIGH' } }
      receipt = { 'schema' => 1, 'input_evidence_sha256' => input_ref['sha256'], 'queries' => [query],
                  'queries_sha256' => Maintenance.digest([query]), 'adoption_authorized' => false,
                  'batches' => [packet(Maintenance::AdvisoryReview::API + 'querybatch', { 'results' => [{ 'vulns' => [finding.slice('id', 'modified')] }] }, { 'queries' => [query] })],
                  'records' => [packet(Maintenance::AdvisoryReview::API + 'vulns/' + finding['id'], finding)] }
      advisory_ref = write.call('advisories.json', receipt)
      evidence = {
        'schema' => 1, 'toolchain' => '0.14.1', 'source_binding_sha256' => Maintenance.digest(Maintenance::Source.new(root).files),
        'applied_patch' => write.call('adoption.patch', 'exact reviewed patch'),
        'captures' => %w[distribution delegated].to_h { |key| [key, { 'inputs' => input_ref, 'advisories' => advisory_ref }] },
        'attribution' => write.call('attribution.json', { 'version' => '0.14.1', 'archive' => { 'sha256' => 'a' * 64 }, 'jars' => [artifact.merge('state' => 'maven_byte_reference')] }),
        'delegated_graphs' => write.call('delegated.json', [{ 'data' => { 'configurations' => [{ 'artifacts' => [artifact] }] } }]),
        'qualification_receipts' => [write.call('qualification.json', { 'state' => 'checks_passed', 'limits' => ['unsigned debug only'] })],
        'coverage_gaps' => Maintenance::RiskAcceptance::CANDIDATE_GAPS,
        'release_receipt' => packet('https://api.github.com/repos/JetBrains/kotlin-toolchain/releases/tags/v0.14.1',
                                    { 'tag_name' => 'v0.14.1', 'published_at' => '2026-11-19T17:46:59Z', 'prerelease' => false, 'draft' => false })
      }
      ref = write.call('packet.json', evidence)
      decision = {
        'schema' => 1, 'state' => 'approved_conditional', 'approved' => true, 'revoked' => false, 'approval_reference' => 'TEST ONLY',
        'reason' => 'test bounded review', 'controls' => ['owned public tests only'], 'starts_at' => NOW.iso8601, 'expires_at' => (NOW + 86_400).iso8601,
        'allowed_operations' => ['public_source_development_builds'], 'toolchain' => '0.14.1', 'distribution_sha256' => 'a' * 64,
        'source_binding_sha256' => evidence['source_binding_sha256'], 'applied_patch_sha256' => evidence['applied_patch']['sha256'],
        'review_packet_sha256' => ref['sha256'], 'acknowledged_coverage_gaps' => evidence['coverage_gaps'], 'qualification_receipts_reviewed' => true,
        'known_findings' => [finding.slice('id').merge('severity' => 'HIGH')], 'findings' => [finding.slice('id').merge('severity' => 'HIGH', 'artifacts' => [artifact])],
        'age_exception' => { 'approved' => true, 'scope' => 'scoped_manual_risk_use', 'version' => '0.14.1', 'published_at' => '2026-11-19T17:46:59Z', 'decision_at' => NOW.iso8601 }
      }
      decision_ref = write.call('decision.json', decision)
      yield root, File.join(dir, 'packet.json'), File.join(dir, decision_ref['path'])
    end
  end
  test('exact candidate packet joins raw providers and measured artifacts under its own manual decision') do
    fixture do |root, evidence, decision|
      result = Maintenance::ToolchainRiskPacket.review(root, evidence, decision_path: decision, now: NOW)
      assert(result['state'] == 'accepted_risk_for_scoped_manual_use' && result['findings'].size == 1 && result['query_count'] == 2)
      assert(!result['adoption_authorized'] && !result['remediation_verified'] && result['coverage_gaps'] == Maintenance::RiskAcceptance::CANDIDATE_GAPS)
    end
  end
  def self.change(path)
    data = JSON.parse(File.read(path)); yield data
    File.write(path, JSON.generate(data))
  end
  def self.refuses
    fixture do |root, packet, decision|
      yield root, packet, decision
      begin
        Maintenance::ToolchainRiskPacket.review(root, packet, decision_path: decision, now: NOW)
        raise 'Expected packet refusal'
      rescue Maintenance::Failure
        # Invalid evidence is refused before any risk grant.
      end
    end
  end
  test('owner omissions, empty qualification and a non-candidate checkout refuse') do
    refuses { |_, p, _| change(p) { |v| v['captures'].delete('delegated') } }
    refuses { |_, p, _| change(p) { |v| v['qualification_receipts'] = [] } }
    refuses { |root, _, _| File.write(File.join(root, 'kotlin'), 'kotlin_cli_version=0.13.0') }
  end
  test('unapproved evidence remains reviewable with provider findings and incomplete-evidence reasons') do
    fixture do |root, packet, _|
      change(File.join(File.dirname(packet), 'advisories.json')) { |v| v['records'] = [] }
      change(packet) { |v| v['captures'].each_value { |c| c['advisories']['sha256'] = Maintenance.file_sha(File.join(File.dirname(packet), 'advisories.json')) } }
      r = Maintenance::ToolchainRiskPacket.review(root, packet, now: NOW)
      assert(r['state'] == 'blocked' && r['reasons'].include?('approval_missing_or_revoked') && r['reasons'].include?('advisory_evidence_incomplete'))
    end
  end
  test('changed bytes, external paths and symlinked evidence refuse') do
    refuses { |_, p, _| File.write(File.join(File.dirname(p), 'attribution.json'), '{}') }
    refuses do |_, p, _|
      original = File.join(File.dirname(p), 'attribution.json')
      FileUtils.cp(original, File.join(File.dirname(p), '..', 'outside.json'))
      change(p) { |v| v['attribution']['path'] = '../outside.json' }
    end
    refuses do |_, p, _|
      original = File.join(File.dirname(p), 'attribution.json'); FileUtils.mv(original, original + '.saved'); File.symlink(original + '.saved', original)
    end
  end
  test('a changed distribution or candidate attribution cannot borrow the reviewed file map') do
    ['version', 'archive'].each do |key|
      refuses do |_, p, _|
        path = File.join(File.dirname(p), 'attribution.json')
        change(path) { |v| key == 'version' ? v[key] = '0.14.0' : v[key]['sha256'] = 'c' * 64 }
        change(p) { |v| v['attribution']['sha256'] = Maintenance.file_sha(path) }
      end
    end
  end
  test('stale, missing and altered raw provider responses stay blocked or refuse') do
    fixture do |root, p, d|
      change(File.join(File.dirname(p), 'advisories.json')) { |v| (v['batches'] + v['records']).each { |r| r['retrieved_at'] = (NOW - 86_401).iso8601 } }
      change(p) { |v| v['captures'].each_value { |c| c['advisories']['sha256'] = Maintenance.file_sha(File.join(File.dirname(p), 'advisories.json')) } }
      change(d) { |v| v['review_packet_sha256'] = Maintenance.file_sha(p) }
      r = Maintenance::ToolchainRiskPacket.review(root, p, decision_path: d, now: NOW)
      assert(r['state'] == 'blocked' && r['reasons'].include?('advisory_evidence_incomplete'))
    end
    refuses do |_, p, _|
      path = File.join(File.dirname(p), 'advisories.json')
      change(path) { |v| v['records'][0]['body'] = '{}' }
      change(p) { |v| v['captures'].each_value { |c| c['advisories']['sha256'] = Maintenance.file_sha(path) } }
    end
  end
  test('empty or wrong-version capture queries cannot narrow a packet') do
    ['queries', 'version'].each do |key|
      refuses do |_, p, _|
        path = File.join(File.dirname(p), 'inputs.json')
        change(path) do |v|
          c = v['phases']['candidate']
          key == 'queries' ? c['owners']['named']['queries'] = [] : c['version'] = '0.14.0'
        end
        change(p) { |v| v['captures'].each_value { |c| c['inputs']['sha256'] = Maintenance.file_sha(path) } }
        path2 = File.join(File.dirname(p), 'advisories.json')
        change(path2) { |v| v['input_evidence_sha256'] = Maintenance.file_sha(path) }
        change(p) { |v| v['captures'].each_value { |c| c['advisories']['sha256'] = Maintenance.file_sha(path2) } }
      end
    end
  end
  test('uncollected delegated configurations remain a coverage gap rather than an empty graph claim') do
    fixture do |root, p, d|
      graph = File.join(File.dirname(p), 'delegated.json')
      change(graph) { |v| v[0]['data']['configurations'] << { 'state' => 'not_collected', 'reason' => 'outside_android_debug_main_scope' } }
      change(p) { |v| v['delegated_graphs']['sha256'] = Maintenance.file_sha(graph) }
      change(d) { |v| v['review_packet_sha256'] = Maintenance.file_sha(p) }
      r = Maintenance::ToolchainRiskPacket.review(root, p, decision_path: d, now: NOW)
      assert(r['state'] == 'accepted_risk_for_scoped_manual_use' && r['coverage_gaps'].include?('configurations_outside_android_debug'))
    end
  end
  test('baseline-only findings remain in provider comparison without becoming candidate grants') do
    fixture do |root, p, d|
      dir = File.dirname(p)
      query = { 'package' => { 'ecosystem' => 'Maven', 'name' => 'zzz:legacy' }, 'version' => '1' }
      finding = { 'id' => 'GHSA-oldx-oldx-oldx', 'modified' => NOW.iso8601, 'affected' => [{ 'package' => query['package'] }], 'database_specific' => { 'severity' => 'HIGH' } }
      change(File.join(dir, 'inputs.json')) { |v| v['phases']['baseline'] = { 'version' => '0.13.0', 'owners' => { 'named' => { 'queries' => [query] } } } }
      change(File.join(dir, 'advisories.json')) do |v|
        v['input_evidence_sha256'] = Maintenance.file_sha(File.join(dir, 'inputs.json'))
        v['queries'] << query; v['queries_sha256'] = Maintenance.digest(v['queries'])
        original = JSON.parse(v['batches'][0]['body']); original['results'] << { 'vulns' => [finding.slice('id', 'modified')] }
        v['batches'] = [packet(Maintenance::AdvisoryReview::API + 'querybatch', original, { 'queries' => v['queries'] })]
        v['records'] << packet(Maintenance::AdvisoryReview::API + 'vulns/' + finding['id'], finding)
      end
      change(p) { |v| v['captures'].each_value { |c| c.each_value { |ref| ref['sha256'] = Maintenance.file_sha(File.join(dir, ref['path'])) } } }
      change(d) { |v| v['review_packet_sha256'] = Maintenance.file_sha(p) }
      r = Maintenance::ToolchainRiskPacket.review(root, p, decision_path: d, now: NOW)
      assert(r['state'] == 'accepted_risk_for_scoped_manual_use' && r['findings'].size == 1 && r['providers'].all? { |v| v['finding_ids'].include?(finding['id']) })
    end
  end
  test('changed source, changed packet and unreviewed qualification never transfer approval') do
    fixture do |root, p, d|
      change(d) { |v| v['qualification_receipts_reviewed'] = false }
      r = Maintenance::ToolchainRiskPacket.review(root, p, decision_path: d, now: NOW)
      assert(r['state'] == 'blocked' && r['reasons'].include?('compatibility_not_passed'))
    end
    fixture do |root, p, d|
      change(p) { |v| v['coverage_gaps'] << 'additional_unmeasured_surface' }
      r = Maintenance::ToolchainRiskPacket.review(root, p, decision_path: d, now: NOW)
      assert(r['state'] == 'blocked' && r['reasons'].include?('review_packet_drift'))
    end
    refuses { |root, _, _| File.write(File.join(root, 'new-source.txt'), 'changed') }
  end
  failures = @tests.count do |name, block|
    block.call; puts "PASS #{name}"; false
  rescue StandardError => error
    warn "FAIL #{name}: #{error.message}"; true
  end
  puts "#{@tests.size} toolchain risk packet contracts, #{failures} failures"
  exit 1 unless failures.zero?
end
