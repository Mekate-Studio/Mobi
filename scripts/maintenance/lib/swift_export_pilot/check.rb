# frozen_string_literal: true

require_relative '../swift_export/assemble'
require_relative '../swift_export/registry'
require_relative '../swift_export/diagnostics'
require_relative 'descriptor'
require_relative 'review'
require_relative '../../adapters/kotlin_resources'
require 'rbconfig'
require_relative '../swift_export/tool_identity'

source, output, cache, profile, policy, compose, java, gem_path, tools_json, settings_path, action, experimental, simulator_major = ARGV
phase = ENV.fetch('MOBI_PHASE')
control = File.dirname(ENV.fetch('MOBI_RESULT_PATH'))
report = { 'schema' => 1, 'check' => 'swift-export-app-pilot', 'phase' => phase, 'status' => 'infrastructure', 'commands' => [], 'adoption_authorized' => false,
           'external_gates' => %w[published_clean_clone hosted device minimum_runtime android_parity signed_release advisory_review], 'diagnostics' => [] }
pin = nil
begin
  descriptor = Maintenance::SwiftExportPilot::Descriptor.new(root: source, profile: profile, repository_policy: policy, compose: compose, simulator_major: Integer(simulator_major))
  inspection = descriptor.inspection
  report['input_identity'] = inspection['identity']
  fixture = File.join(output, 'app-sources')
  Dir.mkdir(fixture)
  %w[ExportHarness.kt.template ReorderedNearbyState.kt.template offline-style.json AccessibilityBootstrap.swift.txt].each do |name|
    FileUtils.cp(File.join(source, 'scripts/maintenance/fixtures/swift-export', name), File.join(fixture, name.delete_suffix('.template')))
  end
  descriptor.data['native']['sources'].each { |path| FileUtils.cp(File.join(source, path), File.join(fixture, File.basename(path))) }
  aliases = "@_exported import MobiHome\n@_exported import MobiDI\n@_exported import ExportedKotlinPackages\npublic typealias HomeFeatureService = ExportedKotlinPackages.studio.mekate.mobi.feature.home.HomeFeatureService\n"
  File.write(File.join(fixture, 'Aliases.swift'), aliases)
  script = File.join(source, 'scripts/maintenance/lib/swift_export')
  data = descriptor.data
  data['pilot_action'] = action
  tools = JSON.parse(tools_json)
  ENV['DEVELOPER_DIR'] = Maintenance::SwiftExport::ToolIdentity.developer_dir(tools.fetch('developer_dir'))
  raise Maintenance::Failure, 'Tool bytes changed' unless tools['locations'].all? { |p, sha| Maintenance.file_sha(p) == sha }
  report['tool_tuple'] = tools.reject { |k, _| k == 'locations' }
  report['effective_input_identity'] = Maintenance.digest([inspection['identity'], report['tool_tuple'], phase == 'candidate' ? 'reordered' : 'original'])
  review = Maintenance::SwiftExportPilot::Review.settings(settings_path, source_identity: Maintenance.digest(inspection['selected_files']), tuple_identity: tools['identity'], qualified: experimental != 'true')
  report['settings_record'] = review
  report['scope'] = 'real-app-pilot'
  report['provisional'] = review['status'] != 'reviewed'
  data['runtime_settings'] = review['limits'].merge('scope' => 'diagnostic-only')
  # All paths below are to this run's source snapshot, not prior assessment work.
  inputs = { 'schema' => 1, 'source_sha256' => inspection['identity'], 'java_home' => File.dirname(File.dirname(java)),
             'cold_artifacts' => data['artifacts'], 'export_jar_names' => data['compiler']['export_jars'],
             'external_libraries_locked' => data['compiler']['external_libraries'], 'compose_plugin_locked' => data['compiler']['compose_plugin'],
             'metro_plugin_locked' => data['compiler']['metro_plugin'], 'enum_variant' => phase == 'candidate' ? 'reordered' : 'original',
             'archive_flags' => data['compiler']['archive_flags'], 'swift_flags' => data['compiler']['swift_flags'],
             'tool_tuple' => report['tool_tuple'], 'binary_artifacts' => data['native']['binary_artifacts'],
             'fixture_sources' => data['modules'].reject { |m| %w[MobiCore MobiHome MobiNearby MobiDI MobiUI].include?(m['name']) }.to_h { |m| [m['name'], m['inputs'].map { |path| File.join(source, path) }] },
             'materialized_fixtures' => fixture, 'producer_scope' => 'fresh_shared_graph_and_shipping_app_facades',
             'build_modules' => compose == 'enabled' ? %w[shared-di shared-ui-home] : %w[shared-di],
             'app_configuration' => { 'scheme' => 'SwiftExportPilot', 'bundle_identifier' => 'studio.mekate.mobi', 'runtime_resource' => true, 'compilation_conditions' => compose == 'enabled' ? ['MOBI_PILOT_COMPOSE'] : [], 'compose' => compose, 'simulator_major' => data.fetch('pilot_simulator_major') },
             'declared_modules' => data['modules'].map { |m| m['name'] },
             'module_visibility' => data['modules'].to_h { |m| [m['name'], m['visibility']] },
             'expected_modules' => data['modules'].map { |m| m['name'] } + %w[KotlinCoroutineSupport KotlinRuntimeSupport ExportedKotlinPackages],
             'native_package_source' => File.join(source, data['native']['package']), 'lock_path' => File.join(source, data['native']['lock']),
             'production_plist' => File.join(source, data['native']['plist']), 'production_assets' => File.join(source, data['native']['assets']),
             'files' => inspection['selected_files'].map { |p, v| { 'path' => File.join(source, p), 'sha256' => v['sha256'] } } }
  Maintenance::RunStore.atomic(File.join(output, 'candidate-inputs.json'), inputs)
  env = ENV.to_h.merge('PATH' => '/usr/bin:/bin:/usr/sbin:/sbin')
  env['GEM_PATH'] = gem_path
  settings = data.fetch('runtime_settings')
  File.write(File.join(fixture, 'pilot-runtime-settings.json'), JSON.generate('repositoryPolicy' => policy, 'parentReservations' => settings['parent_reservations'], 'nativeJobsPerOwner' => settings['native_jobs_per_owner'], 'composeJobsPerOwner' => settings['compose_jobs_per_owner'], 'pollingNanoseconds' => settings['polling_nanoseconds'], 'backoffNanoseconds' => settings['backoff_nanoseconds'], 'shutdownObservationNanoseconds' => settings['shutdown_observation_nanoseconds']))
  command = lambda do |name, argv, base = fixture|
    folder = File.join(control, name); Dir.mkdir(folder)
    result_path = File.join(folder, 'check.json')
    log = File.join(folder, 'command.log')
    status = File.open(log, 'w') do |stream|
      pid = Process.spawn(env.merge('MOBI_RESULT_PATH' => result_path), *argv, chdir: source, unsetenv_others: true, out: stream, err: [:child, :out], in: File::NULL)
      Process.wait2(pid).last
    end
    report['commands'] << { 'name' => name, 'exit' => status.exitstatus, 'log_sha256' => Maintenance.file_sha(log) }
    text = File.read(log, encoding: 'UTF-8').scrub
    puts "#{phase}/#{name}: #{status.exitstatus}"; $stdout.flush
    report['diagnostics'] += Maintenance::SwiftExport::Diagnostics.fingerprints(text, emitter: name, inputs: report['effective_input_identity'], roots: [source, output, cache, control])
    raise Maintenance::Failure, "Candidate step failed: #{name}" unless status.success?
    result = JSON.parse(File.read(result_path))
    raise Maintenance::Failure, "Candidate step did not pass: #{name}" unless result['status'] == 'passed'
    report[name] = result
  end
  command.call('produce', [RbConfig.ruby, File.join(script, 'produce.rb'), source, output, cache, fixture])
  command.call('native', [RbConfig.ruby, File.join(script, 'native.rb'), source, output, cache, fixture])
  produced = JSON.parse(File.read(File.join(output, 'native-inputs.json')))
  payload, identity = Maintenance::SwiftExport::Assemble.call(descriptor, produced, output)
  # Per-run registry has explicit diagnostic settings; persistent cache commands
  # use the same implementation and require their own explicit policy.
  run_root = File.dirname(File.dirname(control)); run_id = File.basename(run_root)
  run = { 'store' => File.dirname(run_root), 'run_id' => run_id }
  registry = Maintenance::SwiftExport::Registry.create(File.join(output, 'registry'), logical_bytes: data.fetch('cache_policy')['logical_payload_byte_limit'], minimum_age_seconds: data['cache_policy']['minimum_age_seconds'], run: run)
  pointer = registry.publish(registry.stage(payload), expected: 0, retained_run: run)
  owner = JSON.parse(File.read(File.join(control, 'started.json')))
  delivery, pin = registry.pin(owner: owner, run: run)
  consumer = Maintenance::SwiftExport::Assemble.consumer_inputs(delivery, phase)
  Maintenance::RunStore.atomic(File.join(output, 'native-inputs.json'), consumer)
  command.call('build', [RbConfig.ruby, File.join(script, 'build.rb'), source, output, cache, File.join(delivery, 'NativeSources')])
  if action == 'test'
    command.call('runtime', [RbConfig.ruby, File.join(source, 'scripts/maintenance/lib/swift_export_pilot/runtime.rb'), source, output, cache, File.join(delivery, 'NativeSources')])
  end
  raise Maintenance::Failure, 'Pinned delivery changed during consumption' unless Maintenance::SwiftExport::Delivery.verify(delivery) == identity
  report['delivery'] = { 'identity' => identity, 'pointer' => pointer, 'members' => Maintenance::SwiftExport::Delivery.files(delivery),
                         'profile' => profile, 'module_modes' => descriptor.modes(consumer['phases'][phase]['modules'].map { |m| m['name'] }), 'consumer_mode' => '6' }
  # Source fingerprint alone is insufficient: inspect every retained emitter log.
  Dir.glob(File.join(control, '**', '*.log')).sort.each do |log|
    report['diagnostics'] += Maintenance::SwiftExport::Diagnostics.fingerprints(File.read(log, encoding: 'UTF-8').scrub, emitter: log.delete_prefix(control + '/'), inputs: report['effective_input_identity'], roots: [source, output, cache, control])
  end
  report['diagnostics'].uniq! { |d| d['fingerprint'] }
  report['assessment'] = 'review_required'
  report['inheritance_compatibility'] = 'unresolved; opt-ins do not qualify adoption'
  report['status'] = 'passed'
rescue StandardError => e
  report['error_class'], report['error'] = e.class.name, e.message
ensure
  begin
    registry.release(pin['id']) if pin
    report['reader_pin'] = 'owner_released' if pin
  rescue StandardError => e
    report['status'] = 'infrastructure'
    report['pin_cleanup_finding'] = e.message
  end
  Maintenance::RunStore.atomic(File.join(output, 'candidate-report.json'), report)
  Maintenance::RunStore.atomic(ENV.fetch('MOBI_RESULT_PATH'), report)
end
exit(report['status'] == 'passed' ? 0 : 1)
