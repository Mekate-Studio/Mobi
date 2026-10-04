# frozen_string_literal: true

require_relative 'lib/recovery'
require_relative 'adapters/compatibility'
require_relative 'adapters/interop_experiment'
require_relative 'lib/compatibility_report'
require_relative 'compatibility_check'
require_relative 'adapters/upstream_remediation'

module CompatibilityTest
  ROOT = File.expand_path('../..', __dir__)
  @tests = []
  def self.test(name, &block); @tests << [name, block]; end
  def self.assert(value, message = 'assertion failed'); raise message unless value; end
  def self.reject(pattern)
    yield
    raise 'Expected refusal'
  rescue Maintenance::Failure => error
    assert(error.message.match?(pattern), error.message)
  end
  def self.fixture
    Dir.mktmpdir('mobi-compatibility-contract-') do |root|
      Maintenance::Source.new(ROOT).copy_to(root)
      _, status = Open3.capture2e('/usr/bin/git', 'init', '-q', root)
      assert(status.success?)
      yield root
    end
  end
  def self.config(root)
    file = File.join(root, Maintenance::Compatibility::CONFIG)
    data = JSON.parse(File.read(file)); yield data
    File.write(file, JSON.pretty_generate(data))
  end

  test('Xcode first-launch readiness refuses before another cold pair and does not run setup') do
    calls = []
    status = Struct.new(:exitstatus) { def success?; exitstatus.zero?; end }
    runner = lambda do |*args, **options|
      calls << [args, options]
      ['', '', status.new(69)]
    end
    reject(/first-launch readiness/) { Maintenance::UpstreamRemediationRehearsal.xcode_ready!('/Applications/Xcode.app/Contents/Developer', runner: runner) }
    assert(calls.first[0][1..] == ['/usr/bin/xcodebuild', '-checkFirstLaunchStatus'])
    assert(calls.first[1][:unsetenv_others])
    Maintenance::UpstreamRemediationRehearsal.xcode_ready!('/Applications/Xcode.app/Contents/Developer', runner: ->(*_args, **_options) { ['', '', status.new(0)] })
    assert(Maintenance::KotlinEvidence.classify('ERROR: Xcode first-launch setup could not be completed.', 1) == 'missing')
    assert(Maintenance::KotlinEvidence.classify('ERROR: Xcode first-launch setup could not be completed. HTTP 403', 1) == 'infrastructure')
  end

  test('compile SDK remediation is isolated and preserves minimum target and namespace declarations') do
    fixture do |root|
      source = Maintenance::Source.new(root)
      edits = Maintenance::UpstreamRemediationRehearsal.sdk_edits(source, 37)
      assert(edits.map { |e| e['path'] } == ['android-app/module.yaml'])
      android = YAML.safe_load(edits.first['content']).fetch('settings').fetch('android')
      assert(android.values_at('compileSdk', 'minSdk', 'targetSdk', 'namespace') == [37, 36, 36, 'studio.mekate.mobi'])
      source.verify!
      reject(/Only the reviewed/) { Maintenance::UpstreamRemediationRehearsal.sdk_edits(source, 38) }
      file = File.join(root, 'android-app/module.yaml'); File.write(file, File.read(file).sub('minSdk: 36', 'minSdk: 35'))
      reject(/baseline/) { Maintenance::UpstreamRemediationRehearsal.sdk_edits(Maintenance::Source.new(root), 37) }
    end
  end

  test('AAR compile SDK incompatibility is causal while unexplained and transport failures remain inconclusive') do
    log = "CheckAarMetadataWorkAction: Dependency requires libraries and applications that\n depend on it to compile against version 37 or later of the\n Android APIs.\n :android-app is currently compiled against android-36.0."
    assert(Maintenance::KotlinEvidence.classify(log, 1) == 'failed')
    assert(Maintenance::KotlinEvidence.classify('Unknown failure', 1) == 'infrastructure')
    assert(Maintenance::KotlinEvidence.classify(log + ' HTTP 403', 1) == 'infrastructure')
  end

  test('SwiftPM announcement cannot be promoted to passing execution or lose source binding') do
    fixture do |root|
      assessment = Maintenance::Compatibility.new(root).assessment
      observation = assessment['capability_observations'].first
      assert(observation['state'] == 'documented_not_rehearsed' && observation['missing_capabilities'].include?('swiftpm_execution'))
      config(root) { |c| c['capability_observations'][0]['state'] = 'passed' }
      reject(/Unsupported capability observation/) { Maintenance::Compatibility.new(root) }
      config(root) { |c| c['capability_observations'][0]['state'] = 'documented_not_rehearsed'; c['capability_observations'][0]['sources'] = ['unknown'] }
      reject(/Unsupported capability observation/) { Maintenance::Compatibility.new(root) }
    end
  end

  test('reviewed tuple creates isolated coupled edits without changing caller pins') do
    source = Maintenance::Source.new(ROOT)
    adapter = Maintenance::Compatibility.new(ROOT)
    edits = adapter.edits(source, 'bridge-mobile')
    assert(adapter.edits(source, 'bridge-review') == edits)
    assert(edits.size == 6)
    assert(edits.map { |e| e['path'] }.include?('shared-di/module.yaml'))
    edits.each do |edit|
      assert(edit['before_sha256'] == source.files.fetch(edit['path'])['sha256'])
      assert(edit['after_sha256'] == Digest::SHA256.hexdigest(edit['content']))
    end
    assert(edits.find { |e| e['path'].end_with?('.toml') }['content'].include?('compose = "1.9.0"'))
    source.verify!
  end

  test('baseline drift and unmatched Metro compiler/runtime refuse candidate edits') do
    fixture do |root|
      file = File.join(root, 'gradle/libs.versions.toml'); File.write(file, File.read(file).sub(/^kotlin = "[^"]+"$/, 'kotlin = "0.0.0"'))
      reject(/baseline differs/) { Maintenance::Compatibility.new(root).edits(Maintenance::Source.new(root), 'bridge-mobile') }
    end
    fixture do |root|
      file = File.join(root, 'shared-di/module.yaml'); File.write(file, File.read(file).sub(/compiler:[^\s]+/, 'compiler:0.0.0'))
      reject(/runtime\/compiler/) { Maintenance::Compatibility.new(root).edits(Maintenance::Source.new(root), 'bridge-mobile') }
    end
  end

  test('new releases are age-blocked even when a candidate is nominated') do
    fixture do |root|
      config(root) { |c| c['candidate']['releases']['skie']['published_at'] = Time.now.utc.iso8601 }
      reject(/age-blocked/) { Maintenance::Compatibility.new(root) }
    end
  end

  test('experimental assessment records the real age gate and never authorizes adoption') do
    fixture do |root|
      now = Time.now.utc
      config(root) { |c| c['candidate']['releases']['skie']['published_at'] = now.iso8601 }
      adapter = Maintenance::Compatibility.new(root, now: now, experimental: true)
      assert(adapter.selection['mode'] == 'experimental' && adapter.selection['age_state'] == 'age_blocked')
      assert(Time.iso8601(adapter.selection['eligible_at']) == Time.iso8601(now.iso8601) + 7 * 86_400)
      assert(adapter.selection['adoption_authorized'] == false)
      reject(/age-blocked/) { Maintenance::Compatibility.new(root, now: now) }
      assert(Maintenance::Compatibility.new(root, now: now + 7 * 86_400).selection['age_state'] == 'age_eligible')
      reject(/explicit boolean/) { Maintenance::Compatibility.new(root, experimental: 'true') }
      config(root) { |c| c['candidate']['releases']['skie']['published_at'] = (now + 60).iso8601 }
      reject(/publication is in the future/) { Maintenance::Compatibility.new(root, now: now, experimental: true) }
    end
  end

  test('missing source digests and invented supported direct paths refuse assessment') do
    fixture do |root|
      config(root) { |c| c['sources'][0]['sha256'] = 'missing' }
      reject(/source evidence/) { Maintenance::Compatibility.new(root) }
    end
    fixture do |root|
      config(root) { |c| c['direct_paths']['skie']['status'] = 'passed' }
      reject(/prerequisite assessment/) { Maintenance::Compatibility.new(root) }
    end
  end

  test('source assessment cannot prove local execution or authorize retirement') do
    result = Maintenance::Compatibility.new(ROOT).assessment
    assert(result['direct_paths'].values.all? { |p| p['status'] == 'missing' })
    assert(result['evidence_kind'] == 'reviewed_sources_and_declarations')
    assert(result['bridge_retirement'] == 'defer' && result['adoption_authorized'] == false)
  end

  test('direct copy keeps native tests, schemes and targets while removing its bridge') do
    fixture do |root|
      source = Maintenance::Source.new(root)
      tests = source.files.select { |path, _| path.start_with?('ios-app/tests/') || path.end_with?('.xcscheme', '.xctestplan') }
      assert(tests.keys.count { |path| path.start_with?('ios-app/tests/') } >= 2)
      original = File.read(File.join(root, Maintenance::InteropExperiment::PROJECT))
      experiment = Maintenance::InteropExperiment.new(root, File.join(root, 'scripts/maintenance/fixtures/interop'))
      changes = experiment.prepare!
      assert(!File.exist?(File.join(root, 'gradle-bridge')))
      assert(Maintenance::InteropExperiment.reachable_modules(root).include?('shared-di'))
      tests.each { |path, identity| assert(Maintenance.file_sha(File.join(root, path)) == identity['sha256']) }
      after = File.read(File.join(root, Maintenance::InteropExperiment::PROJECT))
      assert(original.scan(/name = app(?:Tests)?;/) == after.scan(/name = app(?:Tests)?;/))
      assert(after.include?('!KOTLIN INTEGRATION STEP!') && !after.include?('KOTLIN_IOS_BUILDER'))
      assert(changes.count { |change| change['after_sha256'].nil? } >= 5)
      FileUtils.mkdir_p(File.join(root, 'gradle-bridge'))
      reject(/restored/) { experiment.verify_absence! }
    end
  end

  test('stale products refuse a direct experiment') do
    fixture do |root|
      FileUtils.mkdir_p(File.join(root, 'build/stale.framework'))
      reject(/stale build products/) { Maintenance::InteropExperiment.new(root, '').prepare! }
    end
  end

  test('unrecognized native integration layout refuses instead of deleting targets') do
    fixture do |root|
      file = File.join(root, Maintenance::InteropExperiment::PROJECT)
      File.write(file, File.read(file).gsub('KOTLIN_IOS_BUILDER', 'UNKNOWN_BUILDER'))
      reject(/integration phase/) { Maintenance::InteropExperiment.new(root, '').prepare! }
      assert(File.read(file).include?('name = appTests;'))
    end
  end

  test('unknown profile and wrong Toolchain refuse assessment') do
    reject(/Unknown compatibility profile/) { Maintenance::Compatibility.new(ROOT).edits(Maintenance::Source.new(ROOT), 'guess') }
    fixture do |root|
      file = File.join(root, 'kotlin'); File.write(file, File.read(file).sub('kotlin_cli_version=0.12.2', 'kotlin_cli_version=0.12.1'))
      reject(/Toolchain differs/) { Maintenance::Compatibility.new(root).assessment }
    end
  end

  test('command failure keeps causal and infrastructure results distinct') do
    assert(Maintenance::KotlinEvidence.classify('Compilation failed: unresolved reference', 1) == 'failed')
    assert(Maintenance::KotlinEvidence.classify('Could not GET artifact: HTTP 503', 1) == 'infrastructure')
    assert(Maintenance::KotlinEvidence.classify('No matching iPhone simulator', 1) == 'missing')
  end

  test('altered evidence and symlinked receipts are refused') do
    Dir.mktmpdir do |root|
      file = File.join(root, 'evidence.json'); File.write(file, '{}')
      digest = Maintenance.file_sha(file)
      Maintenance::CompatibilityReport.verify_file!(file, digest)
      File.write(file, '{"status":"passed"}')
      reject(/digest mismatch/) { Maintenance::CompatibilityReport.verify_file!(file, digest) }
      link = File.join(root, 'link.json'); File.symlink(file, link)
      reject(/digest mismatch/) { Maintenance::CompatibilityReport.verify_file!(link, Maintenance.file_sha(file)) }
    end
  end

  test('public diagnostics preserve setup exception identity without raw messages or host paths') do
    input = { 'exception_class' => 'Errno::ENOSPC', 'setup_stage' => 'android_sdk_copy', 'failure_origin' => 'kotlin_check.rb:107',
              'failure' => 'private path and secret', 'workspace' => '/Users/private' }
    result = Maintenance::CompatibilityReport.diagnostic(input)
    assert(result.keys.sort == %w[exception_class failure_origin setup_stage])
    assert(!JSON.generate(result).include?('private'))
    reject(/Unsafe/) { Maintenance::CompatibilityReport.diagnostic(input.merge('failure_origin' => '/Users/private/check.rb:1')) }
    reject(/Unsafe/) { Maintenance::CompatibilityReport.diagnostic(input.merge('exception_class' => 'Error secret')) }
    reject(/Unsafe/) { Maintenance::CompatibilityReport.diagnostic(input.merge('setup_stage' => 'unreviewed')) }
    assert(Maintenance::CompatibilityReport.diagnostic({}).empty?)
  end

  test('declared input receipt preserves UTF-8 bytes under the executor C locale') do
    program = 'require "json"; require "yaml"; require ARGV.shift; root = ARGV.shift; modules = YAML.safe_load(File.read(File.join(root, "project.yaml"))).fetch("modules"); print JSON.generate(Maintenance::CompatibilityCheck.declared_inputs(root, modules))'
    output, status = Open3.capture2e({ 'LANG' => 'C', 'LC_ALL' => 'C' }, RbConfig.ruby, '-EUS-ASCII', '-e', program,
                                    File.join(ROOT, 'scripts/maintenance/compatibility_check.rb'), ROOT)
    assert(status.success?, output)
    assert(JSON.parse(output).fetch('kotlin').b == File.binread(File.join(ROOT, 'kotlin')))
  end

  test('a successful summary without both executed phases cannot become a matrix') do
    Dir.mktmpdir do |root|
      store = Maintenance::RunStore.new(File.join(root, 'runs'))
      id = SecureRandom.hex(16)
      binding = { 'adapter' => 'compatibility-bridge-compile' }
      policy = JSON.parse(File.read(File.join(ROOT, 'maintenance-execution-policy.json')))
      store.lock(id) do
        journal = store.allocate(id, binding, policy)
        store.result(journal, { 'run_id' => id, 'state' => 'checks_passed', 'binding' => binding, 'steps' => [], 'ended_at' => Time.now.utc.iso8601, 'adoption_authorized' => false })
      end
      reject(/lacks both passing phases/) { Maintenance::CompatibilityReport.read(store, id) }
    end
  end

  test('release-age reports reject false normal readiness and malformed timestamps') do
    [
      { 'mode' => 'normal', 'age_state' => 'age_blocked', 'assessed_at' => '2026-10-02T15:00:00Z', 'eligible_at' => '2026-10-02T17:59:28Z', 'adoption_authorized' => false },
      { 'mode' => 'experimental', 'age_state' => 'age_eligible', 'assessed_at' => '2026-10-02T15:00:00Z', 'eligible_at' => '2026-10-02T17:59:28Z', 'adoption_authorized' => false },
      { 'mode' => 'experimental', 'age_state' => 'age_blocked', 'assessed_at' => 'invalid', 'eligible_at' => '2026-10-02T17:59:28Z', 'adoption_authorized' => false }
    ].each do |selection|
      report_fixture do |store, id, profile|
        change_phase_evidence(store, id, profile, 'candidate') { |e| e['candidate_selection'] = selection }
        reject(/release-age|Malformed/) { Maintenance::CompatibilityReport.read(store, id) }
      end
    end
    report_fixture do |store, id, profile|
      change_phase_evidence(store, id, profile, 'candidate') do |e|
        e['candidate_selection'] = { 'mode' => 'experimental', 'age_state' => 'age_eligible', 'assessed_at' => '2026-10-02T18:00:00Z', 'eligible_at' => '2026-10-02T17:59:28Z', 'adoption_authorized' => false }
      end
      report = Maintenance::CompatibilityReport.read(store, id)
      assert(report['phases'].last['candidate_selection']['mode'] == 'experimental' && !report['adoption_authorized'])
    end
  end

  def self.report_fixture(profile = 'bridge-compile', references: nil, dependency_log: nil)
    Dir.mktmpdir('mobi-compatibility-report-') do |root|
      store = Maintenance::RunStore.new(File.join(root, 'runs')); id = SecureRandom.hex(16)
      binding = { 'adapter' => 'compatibility-' + profile }
      policy = JSON.parse(File.read(File.join(ROOT, 'maintenance-execution-policy.json')))
      store.lock(id) do
        journal = store.allocate(id, binding, policy)
        steps = %w[baseline candidate].map do |phase|
          control = store.directory(journal, 'steps/' + phase + '-' + profile, disposable: false)
          File.write(File.join(control, 'native_library_compile.log'), 'native compiler receipt')
          cells = %w[effective_toolchain native_library_compile framework_link android-test android-build-debug ios-test ios-build-debug].to_h { |cell| [cell, { 'status' => 'passed' }] }
          if profile == 'bridge-compile'
            %w[android-test android-build-debug ios-test ios-build-debug].each { |cell| cells[cell]['status'] = 'not_attempted' }
          end
          evidence = { 'schema' => 1, 'profile' => profile, 'phase' => phase, 'adoption_authorized' => false,
                       'cells' => cells, 'source_preservation' => 'verified', 'bridge_unavailable' => %w[direct-facade direct-roundtrip direct-resolution direct-build-inputs].include?(profile) && phase == 'candidate',
                       'di_reachable' => true, 'missing_capabilities' => %w[release_archive complete_bridge_target_graph],
                       'commands' => [{ 'log' => 'native_library_compile.log', 'sha256' => Maintenance.file_sha(File.join(control, 'native_library_compile.log')) }] }
          if %w[direct-resolution direct-build-inputs upstream-build-inputs].include?(profile)
            Maintenance::DirectResolution::NATIVE_CELLS.each { |cell| cells[cell]['status'] = 'not_attempted' }
            cells['toolchain_resolution'] = { 'status' => 'passed' }
            if %w[direct-build-inputs upstream-build-inputs].include?(profile)
              %w[android-test android-build-debug native_klib_iosarm64 native_klib_iossimulatorarm64 build_input_evidence].each { |name| cells[name] = { 'status' => 'passed' } }
            end
            evidence['missing_capabilities'] += Maintenance::DirectResolution::GAPS
            references.fetch(phase).each do |name, data|
              file = name + '.json'; Maintenance::RunStore.atomic(File.join(control, file), data)
              evidence[name] = { 'file' => file, 'sha256' => Maintenance.file_sha(File.join(control, file)) }
            end
            log = dependency_log || DirectResolutionTest.graph_text
            File.write(File.join(control, 'dependencies.log'), log)
            evidence['commands'] << { 'check' => 'dependencies', 'exit' => 0, 'capability' => 'toolchain_resolution', 'log' => 'dependencies.log', 'sha256' => Maintenance.file_sha(File.join(control, 'dependencies.log')) }
          end
          evidence['environment'] = { 'bridge' => 'gradle' } if profile == 'upstream-build-inputs'
          packaging_cells = { 'upstream-android-packaging' => %w[android-build-debug android_release android_aab],
                              'upstream-ios-release' => ['ios_release_simulator'], 'upstream-ios-archive' => ['ios_unsigned_archive'] }
          if packaging_cells.key?(profile)
            cells.each_value { |cell| cell['status'] = 'not_attempted' }
            (['effective_toolchain'] + packaging_cells.fetch(profile)).each { |name| cells[name] = { 'status' => 'passed' } }
          end
          if profile == 'bridge-review'
            %w[toolchain_resolution bridge_resolution].each { |cell| cells[cell] = { 'status' => 'passed' } }
            component = { 'kind' => 'maven', 'group' => 'example', 'name' => 'library', 'version' => '1.0.0' }
            rows = %w[iosArm64Compile iosArm64TestCompile iosSimulatorArm64Compile iosSimulatorArm64TestCompile classpath].map do |name|
              { 'project' => ':shared-kit', 'owner' => name == 'classpath' ? 'buildscript' : 'project', 'configuration' => name,
                'resolvable' => true, 'attributes' => {}, 'state' => 'resolved', 'failures' => [], 'edges' => [],
                'nodes' => [{ 'component' => component, 'variants' => [] }],
                'artifacts' => [{ 'component' => component, 'name' => 'library.jar', 'variant' => { 'name' => 'runtime', 'attributes' => {} },
                                 'identity' => { 'kind' => 'file', 'sha256' => 'a' * 64, 'bytes' => 10 } }] }
            end
            graphs = { 'bridge-resolution' => { 'schema' => 1, 'gradle' => '9.6.1', 'configurations' => rows },
                       'resolved-graphs' => { 'format' => 'toolchain-pretty-graph-v1', 'graphs' => [{ 'nodes' => [] }] } }
            graphs.each do |name, data|
              file = name + '.json'; Maintenance::RunStore.atomic(File.join(control, file), data)
              evidence[name] = { 'file' => file, 'sha256' => Maintenance.file_sha(File.join(control, file)) }
            end
          end
          if profile == 'direct-roundtrip'
            evidence['missing_capabilities'] += %w[incremental_direct_build local_bridge_rollback]
            if phase == 'candidate'
              Maintenance::RoundtripEvidence::CELLS.each { |cell| cells[cell] = { 'status' => 'passed' } }
              evidence['bridge_absence_scope'] = 'direct_checks_before_restoration'
            end
            references.fetch(phase).each do |name, data|
              file = name + '.json'; Maintenance::RunStore.atomic(File.join(control, file), data)
              evidence[name] = { 'file' => file, 'sha256' => Maintenance.file_sha(File.join(control, file)) }
            end
          end
          Maintenance::RunStore.atomic(File.join(control, 'evidence.json'), evidence)
          check = { 'schema' => 1, 'phase' => phase, 'check' => profile, 'status' => 'passed', 'evidence_sha256' => Maintenance.file_sha(File.join(control, 'evidence.json')) }
          Maintenance::RunStore.atomic(File.join(control, 'check.json'), check)
          %w[stdout.log stderr.log].each { |name| File.write(File.join(control, name), '') }
          hashes = %w[stdout.log stderr.log check.json].to_h { |name| [name, Maintenance.file_sha(File.join(control, name))] }
          journal['steps'] << { 'id' => phase + '-' + profile, 'path' => 'steps/' + phase + '-' + profile, 'state' => 'stopped', 'process_exit' => 0, 'output_sha256' => hashes }
          { 'phase' => phase, 'check' => profile, 'status' => 'passed', 'exit' => 0, 'output_sha256' => hashes }
        end
        store.save(journal)
        store.result(journal, { 'run_id' => id, 'state' => 'checks_passed', 'reason' => 'named_checks_passed', 'binding' => binding,
                               'steps' => steps, 'ended_at' => Time.now.utc.iso8601, 'adoption_authorized' => false, 'missing_capabilities' => %w[release_archive complete_bridge_target_graph] + (%w[direct-resolution direct-build-inputs upstream-build-inputs].include?(profile) ? Maintenance::DirectResolution::GAPS : []) + (profile == 'direct-roundtrip' ? %w[incremental_direct_build local_bridge_rollback] : []) })
      end
      yield store, id, profile
    end
  end

  def self.change_phase_evidence(store, id, profile, phase)
    control = File.join(store.path(id), 'steps', phase + '-' + profile)
    path = File.join(control, 'evidence.json'); evidence = JSON.parse(File.read(path)); yield evidence
    Maintenance::RunStore.atomic(path, evidence)
    path = File.join(control, 'check.json'); check = JSON.parse(File.read(path)); check['evidence_sha256'] = Maintenance.file_sha(File.join(control, 'evidence.json'))
    Maintenance::RunStore.atomic(path, check)
    digest = Maintenance.file_sha(path)
    journal = JSON.parse(File.read(store.path(id, '.json')))
    journal['steps'].find { |s| s['id'] == phase + '-' + profile }['output_sha256']['check.json'] = digest
    store.save(journal)
    path = store.path(id, '.result.json'); result = JSON.parse(File.read(path))
    result['steps'].find { |s| s['phase'] == phase }['output_sha256']['check.json'] = digest
    Maintenance::RunStore.atomic(path, result)
  end

  test('verified paired compile evidence keeps unexecuted mobile capabilities missing') do
    report_fixture do |store, id, profile|
      report = Maintenance::CompatibilityReport.read(store, id)
      assert(report['state'] == 'checks_passed' && report['bridge_retirement'] == 'defer' && !report['adoption_authorized'])
      assert(report['phases'].all? { |p| p['cells']['ios-test']['status'] == 'not_attempted' })
      log = File.join(store.path(id), 'steps', 'candidate-' + profile, 'native_library_compile.log')
      File.write(log, 'altered command')
      reject(/digest mismatch/) { Maintenance::CompatibilityReport.read(store, id) }
    end
  end

  test('removing output hashes cannot bypass receipt verification') do
    report_fixture do |store, id, _profile|
      path = store.path(id, '.result.json'); result = JSON.parse(File.read(path))
      result['steps'].first['output_sha256'].delete('check.json')
      Maintenance::RunStore.atomic(path, result)
      reject(/complete process\/output/) { Maintenance::CompatibilityReport.read(store, id) }
    end
  end

  test('packaging receipts require their actual jobs without crediting native tests') do
    { 'upstream-android-packaging' => 'android_aab', 'upstream-ios-release' => 'ios_release_simulator',
      'upstream-ios-archive' => 'ios_unsigned_archive' }.each do |profile, required|
      report_fixture(profile) do |store, id, _|
        report = Maintenance::CompatibilityReport.read(store, id)
        assert(report['state'] == 'checks_passed' && report['bridge_retirement'] == 'defer')
        assert(report['phases'].all? { |phase| phase['cells']['ios-test']['status'] == 'not_attempted' })
        change_phase_evidence(store, id, profile, 'candidate') { |e| e['cells'][required]['status'] = 'not_attempted' }
        reject(/required capability/) { Maintenance::CompatibilityReport.read(store, id) }
      end
    end
  end
  test('review report compares verified graphs without inventing advisory provider success') do
    report_fixture('bridge-review') do |store, id, profile|
      report = Maintenance::CompatibilityReport.read(store, id)
      assert(report['resolution']['bridge_diff']['changed'].empty?)
      assert(report['resolution']['candidate_advisory_queries']['queries'].size == 1)
      assert(report['resolution']['candidate_advisory_queries']['provider_state'] == 'not_queried')
      assert(report['missing_capabilities'] == ['release_archive'])
      assert(report['phases'].all? { |phase| phase['missing_capabilities'] == ['release_archive'] })
      change_phase_evidence(store, id, profile, 'candidate') { |e| e.delete('bridge-resolution') }
      reject(/Malformed compatibility evidence/) { Maintenance::CompatibilityReport.read(store, id) }
    end
  end

  test('consistent receipt hashes cannot turn a missing capability into a passing phase') do
    report_fixture('bridge-mobile') do |store, id, profile|
      change_phase_evidence(store, id, profile, 'candidate') { |e| e['cells']['ios-test']['status'] = 'not_attempted' }
      reject(/required capability/) { Maintenance::CompatibilityReport.read(store, id) }
    end
    report_fixture('direct-facade') do |store, id, profile|
      assert(Maintenance::CompatibilityReport.read(store, id)['state'] == 'checks_passed')
      change_phase_evidence(store, id, profile, 'candidate') { |e| e['bridge_unavailable'] = false }
      reject(/bridge absence/) { Maintenance::CompatibilityReport.read(store, id) }
    end
  end

  def self.run
    failures = @tests.map do |name, block|
      begin
        block.call; puts "PASS #{name}"; nil
      rescue StandardError => error
        warn "FAIL #{name}: #{error.message}\n#{error.backtrace.first(3).join("\n")}"
        name
      end
    end.compact
    puts "#{@tests.size} compatibility contracts, #{failures.size} failures"
    exit(failures.empty? ? 0 : 1)
  end
end

CompatibilityTest.run if $PROGRAM_NAME == __FILE__
