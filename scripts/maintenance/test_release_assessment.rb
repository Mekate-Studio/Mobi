# frozen_string_literal: true

require_relative 'assessment_cli'
require_relative 'lib/assessment_packet'
require_relative 'lib/assessment_security'
require_relative 'assessment_check'
require_relative 'test_build_inputs'
require 'tmpdir'

module ReleaseAssessmentTest
  @tests = []
  def self.test(name, &block); @tests << [name, block]; end
  def self.assert(value); raise 'assertion failed' unless value; end
  def self.reject(reason)
    yield
    raise 'expected refusal'
  rescue Maintenance::Failure => error
    assert(error.message.include?(reason))
  end
  NOW = Time.utc(2026, 11, 22)
  def self.release(version, **options)
    { 'tag_name' => 'v' + version, 'draft' => false, 'prerelease' => false, 'published_at' => (NOW - 10 * 86_400).iso8601,
      'body' => 'Fix API cancellation handling', 'html_url' => 'https://github.com/example/owner/releases/tag/v' + version }.merge(options.transform_keys(&:to_s))
  end
  def self.http(&transport)
    Dir.mktmpdir('mobi-assessment-contract-') do |dir|
      yield_http = Maintenance::AssessmentHTTP.new(dir, transport: transport)
      yield_http
    end
  end
  def self.catalog(pages, count: 4)
    transport = Object.new
    transport.define_singleton_method(:get) do |url|
      page = pages.fetch(url[/page=(\d+)\z/, 1].to_i - 1)
      page.size < 100 ? page + [ReleaseAssessmentTest.release('1.0.0')] : page
    end
    Maintenance::AssessmentCatalog.collect(transport, 'example/owner', '1.0.0', now: NOW, pages: count)
  end

  test('all published channels and numeric prerelease ordering survive catalog normalization') do
    value = catalog([[release('1.1.0-Beta10'), release('1.1.0-Beta2'), release('1.1.0'), release('2.0.0', draft: true)]])
    assert(value['state'] == 'collected')
    assert(value['releases'].map { |r| r['version'] } == %w[1.1.0-Beta2 1.1.0-Beta10 1.1.0])
    assert(value['releases'].first['channel'] == 'prerelease')
  end
  test('catalog walks past older records and marks a full-page bound incomplete') do
    full = Array.new(100) { release('0.9.0') }
    assert(catalog([full, [release('1.1.0')]])['releases'].size == 1)
    value = catalog([full], count: 1)
    assert(value['state'] == 'incomplete' && value['gaps'].include?('release_catalog_page_limit'))
  end
  test('malformed, future and note-free newer releases cannot mean clean no-updates') do
    [release('1.1.0', published_at: (NOW + 1).iso8601), release('1.1.0', body: ''), release('not-a-version')].each do |row|
      assert(catalog([[row]])['state'] == 'incomplete')
    end
  end
  test('provider HTTP budget, byte limit, allowlist and per-payload cache are enforced') do
    Dir.mktmpdir do |dir|
      calls = 0
      transport = ->(_url, _payload = nil) { calls += 1; '{}' }
      http = Maintenance::AssessmentHTTP.new(dir, transport: transport, max_requests: 2)
      http.get('https://api.github.com/repos/example/owner')
      http.get('https://api.github.com/repos/example/owner')
      http.packet('https://api.osv.dev/v1/querybatch', { 'queries' => [] })
      assert(calls == 2 && http.receipts.size == 2)
      reject('budget') { http.get('https://api.github.com/other') }
      reject('Unsupported') { http.get('https://api.github.com.evil.invalid/') }
      reject('Unsupported') { http.get('https://user:pass@api.github.com/') }
      assert(!JSON.generate(http.failures).include?('user:pass'))
      large = Maintenance::AssessmentHTTP.new(dir, transport: ->(_url) { 'x' * (Maintenance::AssessmentHTTP::MAX_BYTES + 1) })
      reject('size') { large.get('https://api.github.com/large') }
    end
  end
  test('tag and Maven-only prereleases remain visible and missing publication evidence blocks them') do
    http = Object.new
    http.define_singleton_method(:get) do |url, **_options|
      if url.include?('/tags?')
        [{ 'name' => 'v1.1.0-Beta2', 'commit' => { 'sha' => 'a' * 40 } }]
      else
        '<metadata><groupId>example</groupId><artifactId>api</artifactId><versioning><versions><version>1.0.0</version><version>1.1.0-Beta10</version></versions></versioning></metadata>'
      end
    end
    seed = { 'state' => 'collected', 'releases' => [], 'gaps' => [] }
    result = Maintenance::AssessmentCatalog.channels(http, 'example/owner', '1.0.0', seed, maven: ['example:api'])
    assert(result['channels_cross_checked'] && result['releases'].map { |row| row['version'] } == %w[1.1.0-Beta2 1.1.0-Beta10])
    assert(result['releases'].all? { |row| row['channel'] == 'prerelease' && row['published_at'].nil? && !row['gaps'].empty? })
    http.define_singleton_method(:get) { |_url, **_options| [] }
    missing = Maintenance::AssessmentCatalog.channels(http, 'example/owner', '1.0.0', seed, maven: ['example:api'])
    assert(missing['state'] == 'incomplete')
    versions = (1..4001).map { |i| '<version>1.1.0-Beta' + i.to_s + '</version>' }.join
    http.define_singleton_method(:get) do |url, **_options|
      url.include?('/tags?') ? [] : '<metadata><groupId>example</groupId><artifactId>api</artifactId><versioning><versions>' + versions + '</versions></versioning></metadata>'
    end
    bounded = Maintenance::AssessmentCatalog.channels(http, 'example/owner', '1.0.0', seed, maven: ['example:api'])
    assert(bounded['state'] == 'incomplete' && bounded['gaps'].include?('maven_version_count_limit') && bounded['releases'].size == 4000)
  end
  test('provider responses are digest-bound and payload cache does not cross query sets') do
    Dir.mktmpdir do |dir|
      http = Maintenance::AssessmentHTTP.new(dir, transport: ->(_url, payload = nil) { JSON.generate(payload || {}) })
      first = http.packet('https://api.osv.dev/v1/querybatch', { 'queries' => ['a'] })
      second = http.packet('https://api.osv.dev/v1/querybatch', { 'queries' => ['b'] })
      assert(first['response_sha256'] != second['response_sha256'])
      assert(first['response_sha256'] == Digest::SHA256.hexdigest(first['body']))
      assert(http.receipts.all? { |r| File.file?(File.join(dir, r['sha256'] + '.body')) })
    end
  end
  test('diverged or truncated compare responses cannot complete upstream evidence') do
    http = Object.new
    http.define_singleton_method(:get) do |url|
      if url.include?('/compare/')
        { 'base_commit' => { 'sha' => 'a' * 40 }, 'merge_base_commit' => { 'sha' => 'b' * 40 }, 'status' => 'diverged',
          'files' => [{ 'filename' => 'Api.kt' }] }
      else
        { 'sha' => url.end_with?('1.0.0') ? 'a' * 40 : 'c' * 40 }
      end
    end
    value = Maintenance::AssessmentCatalog.interval(http, 'example/owner', '1.0.0', { 'tag' => '1.1.0' })
    assert(value['state'] == 'incomplete' && value['gaps'].include?('source_interval_diverged') && value['gaps'].include?('source_interval_patch_missing'))
  end
  def self.stages
    Maintenance::AssessmentDecision::REQUIRED.to_h { |key| [key, { 'state' => 'complete' }] }.merge('security' => { 'state' => 'complete', 'blocking_findings' => [] })
  end
  test('every required incomplete stage and source drift refuse adoption recommendation') do
    Maintenance::AssessmentDecision::REQUIRED.each do |name|
      value = stages; value[name]['state'] = 'incomplete'
      result = Maintenance::AssessmentDecision.evaluate(value, age_eligible: true, source_verified: true)
      assert(result['recommendation'] == 'incomplete' && !result['adoption_authorized'])
    end
    assert(Maintenance::AssessmentDecision.evaluate(stages, age_eligible: true, source_verified: false)['recommendation'] == 'incomplete')
  end
  test('baseline failure is inconclusive and cannot label the candidate regressed') do
    value = stages; value['qualification'].merge!('baseline' => 'failed', 'candidate' => 'not_attempted')
    assert(Maintenance::AssessmentDecision.evaluate(value, age_eligible: true, source_verified: true)['reason'] == 'baseline_inconclusive')
    value['qualification']['baseline'] = 'inconclusive'
    assert(Maintenance::AssessmentDecision.evaluate(value, age_eligible: true, source_verified: true)['reason'] == 'baseline_inconclusive')
    assert(Maintenance::AssessmentDecision.next_slices('stages' => value).first['action'] == 'repair_baseline_qualification_prerequisites')
    value['qualification'].merge!('baseline' => 'passed', 'candidate' => 'failed')
    assert(Maintenance::AssessmentDecision.evaluate(value, age_eligible: true, source_verified: true)['recommendation'] == 'reject')
  end
  test('harness and interrupted candidate checks cannot be labelled native regressions or unattempted') do
    check = Maintenance::AssessmentCheck.allocate
    assert(check.classify_command('maintenance-contracts', 'FAIL reviewed tuple differs', 1) == 'infrastructure')
    assert(check.classify_command('ios-test', '** TEST FAILED **', 1) == 'failed')
    result = { 'reason' => 'candidate_infrastructure', 'steps' => [{ 'phase' => 'baseline', 'status' => 'passed' }],
      'attempts' => [{ 'id' => 'baseline-toolchain-mobile' }, { 'id' => 'candidate-toolchain-mobile' }] }
    assert(Maintenance::AssessmentQualification.phase_outcome(result, 'baseline') == 'passed')
    assert(Maintenance::AssessmentQualification.phase_outcome(result, 'candidate') == 'inconclusive')
    result['reason'] = 'candidate_regression'
    assert(Maintenance::AssessmentQualification.phase_outcome(result, 'candidate') == 'failed')
    result['attempts'].pop; result['reason'] = 'baseline_infrastructure'; result['steps'] = []
    assert(Maintenance::AssessmentQualification.phase_outcome(result, 'candidate') == 'not_attempted')
  end
  test('contract subprocesses cannot overwrite the enclosing executor control file') do
    Dir.mktmpdir do |root|
      marker = File.join(root, 'outer-check.json'); File.write(marker, 'outer executor')
      native = { 'PATH' => '/usr/bin:/bin', 'HOME' => root, 'TMPDIR' => root,
        'MOBI_RESULT_PATH' => marker, 'MOBI_PHASE' => 'candidate', 'MOBI_RESOURCE_NONCE' => 'a' * 32 }
      child = Maintenance::AssessmentCheck.prerequisite_environment(native)
      script = 'File.write(ENV.fetch("MOBI_RESULT_PATH"), "clobbered") if ENV["MOBI_RESULT_PATH"]; abort("nonce leaked") if ENV["MOBI_RESOURCE_NONCE"] || ENV["MOBI_PHASE"]'
      _output, error, status = Open3.capture3(child, RbConfig.ruby, '-e', script, unsetenv_others: true)
      assert(status.success? && File.read(marker) == 'outer executor')
      assert(child['HOME'] == root && child['TMPDIR'] == root && native['MOBI_RESULT_PATH'] == marker)
    end
  end
  test('complete packet can recommend adoption but never authorize it; age and findings defer') do
    assert(Maintenance::AssessmentDecision.evaluate(stages, age_eligible: true, source_verified: true)['recommendation'] == 'adopt')
    assert(Maintenance::AssessmentDecision.evaluate(stages, age_eligible: false, source_verified: true)['recommendation'] == 'defer')
    assert(Maintenance::AssessmentDecision.evaluate(stages, age_eligible: true, source_verified: true, channel: 'prerelease')['reason'] == 'prerelease_adoption_requires_decision')
    value = stages; value['security']['blocking_findings'] = ['finding']
    result = Maintenance::AssessmentDecision.evaluate(value, age_eligible: true, source_verified: true)
    assert(result['recommendation'] == 'defer' && !result['pr_creation_authorized'] && !result['retirement_authorized'])
  end
  test('impact assessment finds lowercase consumed API removal and preserves source and effect evidence') do
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, 'ios-app/src'))
      File.write(File.join(root, 'ios-app/src/Home.swift'), 'client.refreshNow()')
      File.write(File.join(root, 'maintenance-interop-workarounds.json'), JSON.generate('entries' => [
        { 'id' => 'IOS-13', 'recheck_on' => ['tca'], 'replacement' => 'Supported executor ownership', 'retirement_checks' => ['Keep actual tests'], 'paths' => ['ios-app/src/Home.swift'] }
      ]))
      source = Struct.new(:files).new({ 'ios-app/src/Home.swift' => { 'sha256' => 'a' * 64 } })
      interval = { 'state' => 'collected', 'gaps' => [], 'files' => [{ 'filename' => 'Sources/Client.swift',
        'patch' => "-public func refreshNow() async {}\n+public func reload() async {}\n" }] }
      impact = Maintenance::AssessmentImpact.analyze(root, source, 'tca', interval)
      assert(impact['state'] == 'complete' && impact['findings'].first['risk'] == 'possible_consumed_api_removed_or_renamed')
      assert(impact['findings'].first['effect_changes'].include?('async'))
      assert(impact['workarounds'].first['id'] == 'IOS-13' && !impact['retirement_authorized'])
      noise = (0...1100).map { |i| "+class UnusedUpstream#{i}" }.join("\n")
      interval['files'] << { 'filename' => 'Sources/Unused.swift', 'patch' => noise }
      wide = Maintenance::AssessmentImpact.analyze(root, source, 'tca', interval)
      assert(wide['state'] == 'complete' && wide['actual_source_matches'].first['symbols'].include?('refreshNow'))
      interval['files'] << { 'filename' => 'binary.data', 'patch' => nil }
      incomplete = Maintenance::AssessmentImpact.analyze(root, source, 'tca', interval)
      assert(incomplete['state'] == 'incomplete' && incomplete['gaps'].include?('missing_source_patch'))
    end
  end

  test('Toolchain patches require consistent official wrappers and never edit exporter guards') do
    Dir.mktmpdir do |root|
      File.write(File.join(root, 'kotlin'), "kotlin_cli_version=0.14.1\n")
      File.write(File.join(root, 'kotlin.bat'), "set kotlin_cli_version=0.14.1\n")
      files = %w[kotlin kotlin.bat].to_h { |path| [path, { 'sha256' => Maintenance.file_sha(File.join(root, path)) }] }
      source = Struct.new(:root, :files).new(root, files)
      reject('provider_required') { Maintenance::AssessmentPatch.prepare(source, 'toolchain', '0.14.1', { 'version' => '0.15.0' }, {}) }
      http = Object.new
      http.define_singleton_method(:get) do |url, **_options|
        prefix = url.end_with?('.bat') ? 'set ' : ''
        "#{prefix}kotlin_cli_version=0.15.0\n#{prefix}kotlin_cli_sha256=#{'a' * 64}\n"
      end
      edits = Maintenance::AssessmentPatch.prepare(source, 'toolchain', '0.14.1', { 'version' => '0.15.0' }, {}, http: http)
      assert(edits.map { |e| e['path'] } == %w[kotlin kotlin.bat])
      assert(File.read(File.join(root, 'kotlin')).include?('0.14.1'))
      http.define_singleton_method(:get) do |url, **_options|
        prefix = url.end_with?('.bat') ? 'set ' : ''
        "#{prefix}kotlin_cli_version=0.15.0\n#{prefix}kotlin_cli_sha256=#{(prefix.empty? ? 'a' : 'b') * 64}\n"
      end
      reject('distributions_disagree') { Maintenance::AssessmentPatch.prepare(source, 'toolchain', '0.14.1', { 'version' => '0.15.0' }, {}, http: http) }
    end
  end
  test('disk bound refuses paired native allocation and missing measurements fail closed') do
    ok = Object.new
    ok.define_singleton_method(:success?) { true }
    low = ->(_root) { ["Filesystem 1024-blocks Used Available Capacity Mounted\n/dev/test 1000 999 1 99% /\n", ok] }
    reject('14_gib') { Maintenance::AssessmentQualification.disk_preflight!('.', probe: low) }
    malformed = ->(_root) { ['invalid', ok] }
    reject('unavailable') { Maintenance::AssessmentQualification.disk_preflight!('.', probe: malformed) }
    enough = ->(_root) { ["Filesystem 1024-blocks Used Available Capacity Mounted\n/dev/test 999999999 0 14680064 0% /\n", ok] }
    assert(Maintenance::AssessmentQualification.disk_preflight!('.', probe: enough) == 14 * 1024 * 1024)
    assert(Maintenance::AssessmentQualification.maven_endpoint(nil).nil?)
    assert(Maintenance::AssessmentQualification.maven_endpoint('https://repo.maven.apache.org/maven2/') == 'https://repo.maven.apache.org/maven2')
    %w[https://user:secret@repo.maven.apache.org/maven2 https://repo.maven.apache.org/maven2?token=secret http://repo.maven.apache.org/maven2].each do |url|
      reject('supported_public_maven_endpoint') { Maintenance::AssessmentQualification.maven_endpoint(url) }
    end
  end

  test('end-to-end packet binds an isolated patch and recommendation never authorizes adoption') do
    Dir.mktmpdir('mobi-assessment-app-') do |root|
      system('/usr/bin/git', 'init', '--quiet', root) || raise('git init failed')
      File.write(File.join(root, '.gitignore'), ".maintenance/\nevidence/\n")
      File.write(File.join(root, 'kotlin'), "kotlin_cli_version=0.14.1\n")
      File.write(File.join(root, 'maintenance-policy.json'), JSON.generate('automatic_adoption' => false, 'minimum_release_age_days' => 7))
      File.write(File.join(root, 'maintenance-interop-workarounds.json'), JSON.generate('entries' => []))
      Dir.mkdir(File.join(root, 'shared-core'))
      File.write(File.join(root, 'shared-core/module.yaml'), "dependencies:\n  - dev.zacsweers.metro:runtime:1.5.0\n  - org.jetbrains.kotlin:swift-export-embeddable:2.5.0-RC\n")
      File.write(File.join(root, 'shared-core/FeedApi.kt'), 'class FeedApi')
      Dir.mkdir(File.join(root, 'evidence'))
      transport = lambda do |url|
        if url.end_with?('maven-metadata.xml')
          group, artifact, versions = if url.include?('/dev/zacsweers/metro/')
                                       ['dev.zacsweers.metro', url.include?('/compiler/') ? 'compiler' : 'runtime', %w[1.5.0 1.6.0]]
                                     elsif url.include?('/kotlin-cli/')
                                       ['org.jetbrains.kotlin', 'kotlin-cli', ['0.14.1']]
                                     else
                                       ['org.jetbrains.kotlin', 'swift-export-embeddable', ['2.5.0-RC']]
                                     end
          '<metadata><groupId>' + group + '</groupId><artifactId>' + artifact + '</artifactId><versioning><versions>' + versions.map { |value| '<version>' + value + '</version>' }.join + '</versions></versioning></metadata>'
        elsif url.include?('/tags?')
          '[]'
        elsif url.include?('/releases?')
          version = url.include?('ZacSweers/metro') ? '1.5.0' : url.include?('kotlin-toolchain') ? '0.14.1' : '2.5.0-RC'
          rows = [release(version)]
          rows << release('1.6.0') if version == '1.5.0'
          JSON.generate(rows)
        elsif url.include?('/compare/')
          JSON.generate('base_commit' => { 'sha' => 'a' * 40 }, 'merge_base_commit' => { 'sha' => 'a' * 40 }, 'status' => 'ahead',
            'files' => [{ 'filename' => 'FeedApi.kt', 'status' => 'modified', 'patch' => '+ class FeedApi', 'additions' => 1, 'deletions' => 0 }])
        else
          JSON.generate('sha' => url.end_with?('v1.5.0') ? 'a' * 40 : 'b' * 40)
        end
      end
      http = Maintenance::AssessmentHTTP.new(File.join(root, 'evidence'), transport: transport)
      called = 0
      qualifier = lambda do |_root, source, edits, _store, **_options|
        called += 1
        assert(edits.size == 1 && edits.first['content'].include?('metro:runtime:1.6.0'))
        assert(File.read(File.join(source.root, 'shared-core/module.yaml')).include?('metro:runtime:1.5.0'))
        [{ 'state' => 'complete', 'baseline' => 'passed', 'candidate' => 'passed' },
          { 'state' => 'complete', 'blocking_findings' => [] }, { 'state' => 'complete' }]
      end
      runner = Maintenance::ReleaseAssessment.new(root, http: http, qualifier: qualifier, now: NOW)
      result = runner.run
      row = result['assessments'].find { |r| r['component'] == 'metro' }
      assert(called == 1 && row['decision']['recommendation'] == 'adopt')
      assert(row['stages']['impact']['actual_source_matches'].any? { |r| r['path'] == 'shared-core/FeedApi.kt' })
      assert(!result['assessment_prerequisite_complete'] && !result['adoption_authorized'] && !result['pr_creation_authorized'])
      assert(File.file?(File.join(runner.output, row.fetch('patch_file'))) && File.file?(File.join(runner.output, 'summary.md')))
      assert(result['packet_sha256'] == Maintenance.digest(result.reject { |key, _| key == 'packet_sha256' }))
      second = Maintenance::ReleaseAssessment.new(root, http: http, qualifier: qualifier, now: NOW + 1).run
      assert(second['history_state'] == 'restored' && second['selection_order'].first == 'tca')
      assert(called == 2)
      broken = Maintenance::ReleaseAssessment.new(root, http: http, qualifier: ->(*_args, **_options) { raise IOError, 'fixture failure' }, now: NOW + 2)
      begin
        broken.run
        raise 'expected operation failure'
      rescue IOError
        failure = JSON.parse(File.read(File.join(broken.output, 'report.json')))
        assert(failure['state'] == 'incomplete' && failure['operation_state'] == 'assessment_operation_failed' && !failure['adoption_authorized'])
      end
    end
  end

  test('packet verification rejects stale, modified and source-drifted evidence without authorizing adoption') do
    Dir.mktmpdir do |root|
      root = File.realpath(root)
      system('/usr/bin/git', 'init', '--quiet', root) || raise('git init failed')
      File.write(File.join(root, '.gitignore'), ".maintenance/\n")
      File.write(File.join(root, 'maintenance-policy.json'), JSON.generate('release_evidence_max_age_hours' => 24, 'advisory_max_age_hours' => 24))
      source = Maintenance::Source.new(root)
      directory = File.join(root, '.maintenance', 'release-assessments', 'a' * 32)
      FileUtils.mkdir_p(File.join(directory, 'evidence'))
      body = '{}'; sha = Digest::SHA256.hexdigest(body)
      body_path = File.join(directory, 'evidence', sha + '.body'); File.write(body_path, body)
      packet = { 'schema' => 1, 'kind' => 'local_release_assessment', 'state' => 'incomplete',
        'source_sha256' => Maintenance.digest(source.files), 'git' => source.git_identity, 'policy_sha256' => Maintenance.file_sha(File.join(root, 'maintenance-policy.json')),
        'adoption_authorized' => false, 'retirement_authorized' => false, 'pr_creation_authorized' => false, 'assessments' => [],
        'provider_evidence' => [{ 'url' => 'https://api.github.com/repos/example/owner', 'retrieved_at' => NOW.iso8601, 'sha256' => sha }] }
      packet['packet_sha256'] = Maintenance.digest(packet)
      path = File.join(directory, 'report.json'); File.write(path, JSON.generate(packet))
      verified = Maintenance::AssessmentPacket.verify(root, path, now: NOW)
      assert(verified['state'] == 'packet_verified' && verified['assessment_state'] == 'incomplete' && !verified['adoption_authorized'])
      stale = Maintenance::AssessmentPacket.verify(root, path, now: NOW + 86_401)
      assert(stale['state'] == 'incomplete' && stale['reasons'] == ['provider_evidence_stale'])
      File.write(body_path, 'changed')
      reject('changed') { Maintenance::AssessmentPacket.verify(root, path, now: NOW) }
      File.write(body_path, body)
      system('/usr/bin/git', '-C', root, 'add', '--all') || raise('git add failed')
      reject('Git identity') { Maintenance::AssessmentPacket.verify(root, path, now: NOW) }
      File.write(File.join(root, 'new-source.kt'), 'changed source')
      reject('source changed') { Maintenance::AssessmentPacket.verify(root, path, now: NOW) }
    end
  end

  test('archive provenance scanner refuses changed bytes and never promotes embedded claims') do
    assert(system({ 'PYTHONDONTWRITEBYTECODE' => '1' }, '/usr/bin/python3', File.join(__dir__, 'test_assessment_provenance.py')))
  end

  test('security queries include selected Swift commits and label embedded claims separately') do
    graph = { 'format' => 'toolchain-pretty-graph-v1', 'graphs' => [{ 'nodes' => [
      { 'coordinate' => { 'group' => 'example', 'name' => 'api', 'selected' => '1.0.0' } }
    ] }] }
    provenance = { 'archives' => [{ 'identity' => { 'sha256' => 'b' * 64, 'bytes' => 10 }, 'metadata' => [{ 'component' => { 'group' => 'example', 'name' => 'launcher', 'version' => '2.0.0' } }], 'gaps' => [] }],
      'swift_locks' => { 'Package.resolved' => { 'pins' => [{ 'identity' => 'swift-api', 'kind' => 'remoteSourceControl',
        'location' => 'https://github.com/example/swift-api', 'state' => { 'revision' => 'a' * 40 } }] } },
      'selected_classpath_proven' => false, 'identity_authority' => 'embedded_claims_not_independent_byte_attribution' }
    inputs = Maintenance::AssessmentSecurity.queries(graph, provenance)
    assert(inputs['queries'].size == 3 && inputs['queries'].include?('commit' => 'a' * 40))
    assert(inputs['gaps'].include?('embedded_claims_need_independent_byte_attribution'))
    assert(inputs['gaps'].include?('selected_build_owner_classpaths_unproven'))
    query = { 'package' => { 'ecosystem' => 'Maven', 'name' => 'example:launcher' }, 'version' => '2.0.0' }
    assert(inputs['origins'][Maintenance.digest(query)] == ['embedded_archive_claim'])
  end

  test('partial provider coverage cannot turn missing records into resolved or introduced findings') do
    summaries = { 'baseline' => { 'state' => 'provider_complete', 'findings' => [{ 'id' => 'GHSA-baseline' }, { 'id' => 'GHSA-both' }] },
      'candidate' => { 'state' => 'incomplete', 'findings' => [{ 'id' => 'GHSA-candidate' }, { 'id' => 'GHSA-both' }] } }
    delta = Maintenance::AssessmentSecurity.finding_delta(summaries)
    assert(delta['state'] == 'incomplete' && delta['resolved_ids'].empty? && delta['introduced_ids'].empty?)
    assert(delta['retained_ids'] == ['GHSA-both'] && delta['observed_baseline_only_ids'] == ['GHSA-baseline'])
    assert(delta['observed_candidate_only_ids'] == ['GHSA-candidate'])
    summaries['candidate']['state'] = 'provider_complete'
    delta = Maintenance::AssessmentSecurity.finding_delta(summaries)
    assert(delta['state'] == 'complete' && delta['resolved_ids'] == ['GHSA-baseline'] && delta['introduced_ids'] == ['GHSA-candidate'])
    summaries['baseline']['state'] = 'incomplete'
    delta = Maintenance::AssessmentSecurity.finding_delta(summaries)
    assert(delta['state'] == 'incomplete' && delta['resolved_ids'].empty? && delta['introduced_ids'].empty?)
  end

  test('both advisory phases and shared records precede checksum budget exhaustion') do
    Dir.mktmpdir do |root|
      calls = []
      transport = lambda do |url, payload = nil|
        calls << [url, payload]
        if url.end_with?('querybatch')
          JSON.generate('results' => payload.fetch('queries').map { { 'vulns' => [{ 'id' => 'GHSA-aaaa-bbbb-cccc' }] } })
        elsif url.include?('/vulns/')
          JSON.generate('id' => 'GHSA-aaaa-bbbb-cccc', 'modified' => NOW.iso8601, 'affected' => [{}], 'database_specific' => { 'severity' => 'HIGH' })
        else
          'c' * 64
        end
      end
      http = Maintenance::AssessmentHTTP.new(root, max_requests: 4, transport: transport)
      inputs = %w[baseline candidate].each_with_index.to_h do |phase, index|
        [phase, { 'queries' => [{ 'commit' => (index.zero? ? 'a' : 'b') * 40 }], 'origins' => {},
          'archive_claims' => [{ 'component' => { 'group' => 'example', 'name' => phase, 'version' => '1.0.0' },
            'identity' => { 'sha256' => 'c' * 64, 'bytes' => 100 } }] }]
      end
      receipts = Maintenance::AssessmentSecurity.collect_pair(http, inputs)
      assert(http.requests == 4 && calls.map { |url, _| url.split('/').last } == %w[querybatch querybatch GHSA-aaaa-bbbb-cccc baseline-1.0.0.jar.sha256])
      receipts.each do |phase, receipt|
        assert(receipt['advisory_state'] == 'complete' && receipt['findings'].size == 1)
        assert(receipt['findings'].first['queries'] == inputs.fetch(phase).fetch('queries'))
        assert(receipt['queries_sha256'] == Maintenance.digest(inputs.fetch(phase).fetch('queries')))
      end
      assert(receipts['baseline']['records'].first == receipts['candidate']['records'].first)
      assert(receipts['candidate']['state'] == 'incomplete' && receipts['candidate']['reasons'].include?('provider_request_budget'))
      assert(Maintenance::AssessmentSecurity.finding_delta(receipts)['state'] == 'incomplete')
    end
  end

  test('pair query failure stays attributed to its phase without hiding candidate findings') do
    Dir.mktmpdir do |root|
      transport = lambda do |url, payload = nil|
        if url.end_with?('querybatch')
          raise Maintenance::Failure, 'provider_http_503' if payload.fetch('queries').first['commit'] == 'a' * 40
          JSON.generate('results' => [{ 'vulns' => [{ 'id' => 'GHSA-aaaa-bbbb-cccc' }] }])
        else
          JSON.generate('id' => 'GHSA-aaaa-bbbb-cccc', 'modified' => NOW.iso8601, 'affected' => [{}], 'database_specific' => { 'severity' => 'CRITICAL' })
        end
      end
      http = Maintenance::AssessmentHTTP.new(root, transport: transport)
      inputs = { 'baseline' => { 'queries' => [{ 'commit' => 'a' * 40 }], 'origins' => {} },
        'candidate' => { 'queries' => [{ 'commit' => 'b' * 40 }], 'origins' => {} } }
      receipts = Maintenance::AssessmentSecurity.collect_pair(http, inputs)
      assert(receipts['baseline']['advisory_state'] == 'incomplete' && receipts['baseline']['reasons'].include?('provider_http_503'))
      assert(receipts['candidate']['advisory_state'] == 'complete' && receipts['candidate']['findings'].first['severity'] == 'critical')
      assert(receipts['candidate']['reasons'].empty? && receipts['baseline']['findings'].empty?)
      assert(Maintenance::AssessmentSecurity.finding_delta(receipts)['introduced_ids'].empty?)
    end
  end

  test('a failed shared record is fetched once and remains missing in both receipts') do
    Dir.mktmpdir do |root|
      calls = []
      http = Maintenance::AssessmentHTTP.new(root, transport: lambda do |url, payload = nil|
        calls << url
        raise Maintenance::Failure, 'provider_http_503' if url.include?('/vulns/')
        JSON.generate('results' => payload.fetch('queries').map { { 'vulns' => [{ 'id' => 'GHSA-aaaa-bbbb-cccc' }] } })
      end)
      inputs = { 'baseline' => { 'queries' => [{ 'commit' => 'a' * 40 }], 'origins' => {} },
        'candidate' => { 'queries' => [{ 'commit' => 'b' * 40 }], 'origins' => {} } }
      receipts = Maintenance::AssessmentSecurity.collect_pair(http, inputs)
      assert(calls.count { |url| url.include?('/vulns/') } == 1)
      receipts.each_value do |receipt|
        assert(receipt['advisory_state'] == 'incomplete' && receipt['findings'].empty?)
        assert(receipt['reasons'].include?('provider_http_503') && receipt['reasons'].include?('finding_record_coverage_incomplete'))
      end
      reject('phase') { Maintenance::AssessmentSecurity.collect_pair(http, inputs.reject { |phase, _| phase == 'candidate' }, now: NOW) }
    end
  end

  test('an advisory record budget gap cannot become a complete pair or a cleared finding') do
    Dir.mktmpdir do |root|
      http = Maintenance::AssessmentHTTP.new(root, max_requests: 2, transport: lambda do |url, payload = nil|
        raise 'Unexpected record transport after the budget cap' unless url.end_with?('querybatch')
        JSON.generate('results' => payload.fetch('queries').map { { 'vulns' => [{ 'id' => 'GHSA-aaaa-bbbb-cccc' }] } })
      end)
      receipts = Maintenance::AssessmentSecurity.collect_pair(http, {
        'baseline' => { 'queries' => [{ 'commit' => 'a' * 40 }], 'origins' => {} },
        'candidate' => { 'queries' => [{ 'commit' => 'b' * 40 }], 'origins' => {} } })
      assert(http.requests == 2)
      receipts.each_value { |r| assert(r['advisory_state'] == 'incomplete' && r['reasons'].include?('provider_request_budget')) }
      delta = Maintenance::AssessmentSecurity.finding_delta(receipts)
      assert(delta['state'] == 'incomplete' && delta['resolved_ids'].empty? && delta['introduced_ids'].empty?)
    end
  end

  test('security collector retains findings and cannot accept omitted records or pagination') do
    http = Object.new
    http.define_singleton_method(:packet) do |url, request|
      data = if url.end_with?('querybatch')
               { 'results' => [{ 'vulns' => [{ 'id' => 'GHSA-aaaa-bbbb-cccc' }], 'next_page_token' => 'more' }] }
             else
               { 'id' => 'GHSA-aaaa-bbbb-cccc', 'modified' => NOW.iso8601, 'affected' => [{}], 'database_specific' => { 'severity' => 'HIGH' } }
             end
      body = JSON.generate(data)
      { 'url' => url, 'request' => request, 'body' => body, 'response_sha256' => Digest::SHA256.hexdigest(body), 'retrieved_at' => NOW.iso8601, 'status' => 200 }
    end
    inputs = { 'queries' => [{ 'commit' => 'a' * 40 }], 'origins' => {} }
    report = Maintenance::AssessmentSecurity.collect(http, inputs, now: NOW)
    assert(report['state'] == 'incomplete' && report['reasons'].include?('pagination_incomplete'))
    assert(report['findings'].first['severity'] == 'high' && !report['adoption_authorized'])
    http.define_singleton_method(:packet) { |_url, _request| raise Maintenance::Failure, 'provider_request_budget' }
    missing = Maintenance::AssessmentSecurity.collect(http, inputs, now: NOW)
    assert(missing['state'] == 'incomplete' && missing['reasons'].include?('provider_request_budget'))
  end

  test('published checksum references distinguish matched, changed and unavailable archive bytes') do
    component = { 'group' => 'example', 'name' => 'api', 'version' => '1.0.0' }
    claim = { 'component' => component, 'identity' => { 'sha256' => 'a' * 64, 'bytes' => 100 } }
    http = Object.new
    http.define_singleton_method(:get) { |_url, **_options| 'a' * 64 + "\n" }
    matched = Maintenance::AssessmentSecurity.byte_references(http, [claim])
    assert(matched['gaps'].empty? && matched['references'].first['state'] == 'published_checksum_matches' && !matched['selected_classpath_proven'])
    http.define_singleton_method(:get) { |_url, **_options| 'b' * 64 }
    assert(Maintenance::AssessmentSecurity.byte_references(http, [claim])['references'].first['state'] == 'published_bytes_differ')
    http.define_singleton_method(:get) { |_url, **_options| raise Maintenance::Failure, 'provider_http_404' }
    missing = Maintenance::AssessmentSecurity.byte_references(http, [claim])
    assert(missing['references'].first['state'] == 'incomplete' && !missing['gaps'].empty?)
  end

  test('actual delegated configuration queries reuse validated producers without upgrading condition coverage') do
    graph = { 'format' => 'toolchain-pretty-graph-v1', 'graphs' => [{ 'nodes' => [{ 'coordinate' => { 'group' => 'example', 'name' => 'api', 'selected' => '1.0.0' } }] }] }
    delegated = BuildInputsTest.delegated
    delegated['gradle'] = '9.8'
    provenance = { 'archives' => [], 'owner_inputs' => { 'state' => 'collected', 'compiler_version' => '2.4.10',
      'selected_plugin_artifacts' => {}, 'delegated_graphs' => [{ 'data' => delegated }], 'complete_target_graph' => false } }
    result = Maintenance::AssessmentSecurity.queries(graph, provenance)
    query = { 'package' => { 'ecosystem' => 'Maven', 'name' => 'org.jetbrains.kotlin:kotlin-gradle-plugin' }, 'version' => '2.4.10' }
    assert(result['queries'].include?(query) && result['origins'][Maintenance.digest(query)] == ['observed_delegated_configuration'])
    assert(result['gaps'].include?('delegated_transform_or_agp_conditions_unproven') && result['gaps'].include?('selected_build_owner_classpaths_unproven'))
    delegated['configurations'][0]['state'] = 'incomplete'
    reject('Incomplete delegated') { Maintenance::AssessmentSecurity.queries(graph, provenance) }
  end

  test('owner capture binds actual compiler arguments and refuses settings/telemetry disagreement') do
    Dir.mktmpdir do |root|
      work, cache, home, control = %w[work cache home control].map { |name| File.join(root, name) }
      FileUtils.mkdir_p([File.join(work, 'build/logs'), File.join(cache, 'gradle/mobi-delegated-evidence'), home, control])
      File.write(File.join(cache, 'selected.jar'), 'plugin bytes')
      trace = BuildInputsTest.traces.first.fetch('payloads').first
      trace_path = File.join(work, 'build/logs/kotlin_cli_traces.jsonl')
      File.write(trace_path, JSON.generate(trace) + "\n")
      File.write(File.join(cache, 'gradle/mobi-delegated-evidence/build.json'), JSON.generate(BuildInputsTest.delegated))
      File.write(File.join(control, 'effective-settings.json'), JSON.generate('shared-core' => { 'settings' => { 'kotlin' => { 'version' => '2.4.10' } } }))
      check = Maintenance::AssessmentCheck.allocate
      { work: work, cache: cache, control: control, env: { 'HOME' => home }, report: {} }.each { |name, value| check.instance_variable_set('@' + name.to_s, value) }
      result = check.capture_owner_inputs
      assert(result['state'] == 'collected' && result['invocations'].size == 15 && !result['complete_target_graph'])
      assert(result['selected_plugin_artifacts']['{cache}/selected.jar']['sha256'] == Maintenance.file_sha(File.join(cache, 'selected.jar')))
      File.write(trace_path, JSON.generate(trace).gsub('2.4.10', '2.4.20') + "\n")
      assert(check.capture_owner_inputs['state'] == 'incomplete')
      raw = JSON.parse(File.read(File.join(control, 'owner-producers.json')))
      assert(raw['files'].any? { |file| Base64.strict_decode64(file['base64']).include?('2.4.20') && Digest::SHA256.hexdigest(Base64.strict_decode64(file['base64'])) == file['sha256'] })
    end
  end

  test('Swift export authority uses dated primary docs, supporting sample and issue identities without retirement') do
    http = Object.new
    body = 'Official Swift export API documentation'
    http.define_singleton_method(:get) do |url|
      if url.include?('youtrack.jetbrains.com')
        { 'idReadable' => url[/KT-\d+/], 'summary' => 'Issue', 'updated' => 1 }
      elsif url.include?('/contents/')
        { 'path' => Maintenance::AssessmentAuthorities::DOC_PATH, 'encoding' => 'base64', 'content' => Base64.strict_encode64(body),
          'sha' => Digest::SHA1.hexdigest("blob #{body.bytesize}\0" + body) }
      elsif url.include?('/compare/')
        { 'files' => [], 'status' => 'identical', 'base_commit' => { 'sha' => 'a' * 40 }, 'merge_base_commit' => { 'sha' => 'a' * 40 } }
      else
        [{ 'sha' => 'a' * 40 }]
      end
    end
    result = Maintenance::AssessmentAuthorities.collect(http, baseline_published: (NOW - 100).iso8601, candidate_published: NOW.iso8601)
    assert(result['state'] == 'complete' && !result['retirement_authorized'])
    assert(result['primary_document']['baseline']['body'] == body && result['issues'].map { |row| row['id'] } == %w[KT-64572 KT-80305])
    assert(result['supporting_sample']['role'].include?('not_primary'))
    http.define_singleton_method(:get) { |_url| [] }
    assert(Maintenance::AssessmentAuthorities.collect(http, baseline_published: nil, candidate_published: NOW.iso8601)['state'] == 'incomplete')
  end

  test('hosted evidence bundle retains hashes and excludes disposable workspaces') do
    Dir.mktmpdir do |root|
      root = File.realpath(root)
      id = 'a' * 32
      store = File.join(root, '.maintenance/runs-release-assessment')
      step = File.join(store, id, 'steps/baseline-toolchain-mobile')
      work = File.join(store, id, 'work/baseline')
      output = File.join(root, 'report')
      FileUtils.mkdir_p([step, work, output])
      File.write(File.join(store, id + '.result.json'), '{}')
      File.write(File.join(step, 'evidence.json'), '{}')
      File.write(File.join(work, 'disposable-cache'), 'not evidence')
      qualification = { 'run_id' => id, 'result_sha256' => Maintenance.file_sha(File.join(store, id + '.result.json')) }
      bundle = Maintenance::AssessmentBundle.export(root, output, qualification)
      assert(bundle['state'] == 'complete' && bundle['files'].size == 2)
      assert(bundle['files'].all? { |path, sha| Maintenance.file_sha(File.join(output, path)) == sha && !path.include?('/work/') })
      File.write(File.join(store, id + '.result.json'), 'changed result')
      drift = Maintenance::AssessmentBundle.export(root, output, qualification)
      assert(drift['state'] == 'incomplete' && drift['gaps'].include?('Bound qualification evidence drift'))
      File.write(File.join(store, id + '.result.json'), '{}')
      File.symlink(File.join(work, 'disposable-cache'), File.join(step, 'unsafe.log'))
      assert(Maintenance::AssessmentBundle.export(root, output, qualification)['state'] == 'incomplete')
    end
  end

  test('dependency ceilings expose an existing baseline inconsistency without widening policy') do
    Dir.mktmpdir do |root|
      path = File.join(root, 'renovate.json')
      File.write(path, JSON.generate('packageRules' => [{ 'matchDatasources' => ['maven'], 'matchPackageNames' => ['/^dev\\.zacsweers\\.metro:/'], 'allowedVersions' => '<=1.4.5' }]))
      before = File.binread(path)
      result = Maintenance::AssessmentConstraints.evaluate(root, 'metro', '1.5.0', '1.6.0')
      assert(result['state'] == 'complete' && result['decisions_required'] == ['adopted_tuple_already_exceeds_ceiling'])
      value = stages; value['constraints'] = result
      decision = Maintenance::AssessmentDecision.evaluate(value, age_eligible: true, source_verified: true)
      assert(decision['recommendation'] == 'defer' && decision['reason'] == 'dependency_ceiling_decision_required')
      assert(File.binread(path) == before && !result['policy_changed'])
    end
  end

  test('full Git endpoint evidence covers more than 300 files and preserves spaced paths and binary identities') do
    Dir.mktmpdir('mobi-source-diff-contract-') do |repo|
      env = { 'PATH' => '/usr/bin:/bin', 'HOME' => repo, 'GIT_CONFIG_GLOBAL' => File::NULL, 'GIT_CONFIG_NOSYSTEM' => '1' }
      git = lambda do |*args, input: ''|
        output, error, status = Open3.capture3(env, '/usr/bin/git', '-c', 'maintenance.auto=false', '-c', 'gc.auto=0', '-C', repo, *args, stdin_data: input, unsetenv_others: true)
        raise error unless status.success?
        output.strip
      end
      git.call('init', '--quiet')
      # Packed imports mirror production's fetched object stores and make this
      # endpoint-diff fixture independent of worktree indexing.
      stream = +''
      2.times do |generation|
        stream << "commit refs/heads/main\nmark :#{generation + 1}\ncommitter Fixture <fixture@example.invalid> #{generation + 1} +0000\ndata 7\nfixture\n"
        stream << "from :1\n" if generation == 1
        files = 301.times.to_h { |i| ["Sources/Api#{i}.kt", "class Api#{i}#{generation == 1 ? 'New' : ''}\n"] }
        files['Sources/Caller space.kt'] = generation.zero? ? "fun oldCall() {}\n" : "fun newCall() {}\n"
        files['docs/image.png'] = generation.zero? ? "\0old" : "\0new"
        files.each { |path, body| stream << "M 100644 inline #{JSON.generate(path)}\ndata #{body.bytesize}\n#{body}\n" }
        stream << "\n"
      end
      stream << "done\n"
      git.call('fast-import', '--quiet', input: stream)
      before = git.call('rev-parse', 'refs/heads/main~1')
      after = git.call('rev-parse', 'refs/heads/main')
      files = Maintenance::AssessmentGit.read_repository(repo, before, after, deadline: Process.clock_gettime(Process::CLOCK_MONOTONIC) + 120)
      assert(files.size == 303)
      assert(files.find { |f| f['filename'] == 'Sources/Caller space.kt' }['patch'].include?('+fun newCall()'))
      image = files.find { |f| f['filename'] == 'docs/image.png' }
      assert(image['binary'] && image['baseline_blob'] != image['candidate_blob'] && image['patch'].empty?)
    end
  end

  test('separate command stderr cannot contaminate machine-readable source output') do
    Dir.mktmpdir do |root|
      out = File.join(root, 'stdout'); err = File.join(root, 'stderr')
      status = Maintenance.run([RbConfig.ruby, '-e', 'STDOUT.write("payload"); STDERR.write("diagnostic")'],
        cwd: root, env: { 'PATH' => '/usr/bin:/bin' }, log: out, stderr_log: err, timeout: 10)
      assert(status.success? && File.read(out) == 'payload' && File.read(err) == 'diagnostic')
    end
  end

  test('owned assessment source index stays independent of an ignored ancestor checkout') do
    Dir.mktmpdir do |parent|
      parent = File.realpath(parent)
      env = { 'PATH' => '/usr/bin:/bin', 'HOME' => parent, 'GIT_CONFIG_GLOBAL' => File::NULL, 'GIT_CONFIG_NOSYSTEM' => '1' }
      _out, _err, status = Open3.capture3(env, '/usr/bin/git', 'init', '--quiet', parent, unsetenv_others: true)
      assert(status.success?)
      File.write(File.join(parent, '.gitignore'), "copies/\n")
      File.write(File.join(parent, 'ancestor.kt'), 'parent source')
      _out, _err, status = Open3.capture3(env, '/usr/bin/git', '-C', parent, 'add', '--all', unsetenv_others: true)
      assert(status.success?)
      before = Maintenance::Source.new(parent).public_identity
      work = File.join(parent, 'copies', 'project'); control = File.join(parent, 'copies', 'control')
      FileUtils.mkdir_p(work); FileUtils.mkdir_p(control)
      File.write(File.join(work, '.gitignore'), ".quality/\n")
      File.write(File.join(work, 'candidate.kt'), 'candidate source')
      FileUtils.mkdir_p(File.join(work, '.quality')); File.write(File.join(work, '.quality', 'private-cache'), 'managed tool bytes')
      Maintenance::AssessmentCheck.prepare_index(work, %w[.gitignore candidate.kt], control)
      inputs = Maintenance::Source.new(work)
      assert(inputs.files.keys.sort == %w[.gitignore candidate.kt])
      assert(Maintenance::Source.new(parent).public_identity == before)
    end
  end

  def self.run
    failed = []
    @tests.each do |name, block|
      block.call
      puts 'PASS ' + name
    rescue StandardError => error
      failed << name; warn 'FAIL ' + name + ': ' + error.full_message
    end
    puts "#{@tests.size} release-assessment contracts, #{failed.size} failures"
    exit(failed.empty? ? 0 : 1)
  end
end
ReleaseAssessmentTest.run if $PROGRAM_NAME == __FILE__
