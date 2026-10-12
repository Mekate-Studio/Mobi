# frozen_string_literal: true

require_relative '../swift_export/assemble'
require_relative '../swift_export/origin'
require_relative '../recovery'
require 'rbconfig'

source, output, cache, delivery, origin_store, origin_id, profile, policy, gem_path, tools_json = ARGV
phase = ENV.fetch('MOBI_PHASE'); control = File.dirname(ENV.fetch('MOBI_RESULT_PATH'))
report = { 'schema' => 1, 'check' => 'swift-export-pilot-replay', 'phase' => phase, 'status' => 'infrastructure', 'adoption_authorized' => false, 'commands' => [],
           'scope' => 'fresh_swift_compile_link_runtime_from_retained_source_archive_and_warm_native_products' }
begin
  store = Maintenance::RunStore.new(origin_store)
  journal = store.load(origin_id)
  raise Maintenance::Failure, 'Original work remains available' unless journal['resources'].select { |r| r['disposable'] }.all? { |r| r['state'] == 'removed' && !File.exist?(store.safe_path(journal, r['path'])) }
  raise Maintenance::Failure, 'Original run is not positively quiescent' unless Maintenance::Recovery.new(store).recover(origin_id)['state'] == 'quiescent'
  report['origin_delivery_binding'] = Maintenance::SwiftExport::Origin.verify(store, origin_id, Maintenance::SwiftExport::Delivery.verify(delivery))
  graph = Maintenance::SwiftExport::Delivery.validate(delivery)
  raise Maintenance::Failure, 'Replay profile/policy differs' unless graph['profile'] == profile && graph['repository_policy'] == policy
  tools = JSON.parse(tools_json)
  raise Maintenance::Failure, 'Replay compiler tuple differs' unless graph['tool_tuple'] == tools.reject { |k, _| k == 'locations' } && tools['locations'].all? { |p, sha| Maintenance.file_sha(p) == sha }
  retained = File.join(output, 'delivery-source')
  Maintenance::SwiftExport::Assemble.copy(delivery, retained)
  report['delivery_identity'] = Maintenance::SwiftExport::Delivery.verify(retained)
  report['original_work_unavailable'] = true
  inputs = Maintenance::SwiftExport::Assemble.consumer_inputs(retained, phase)
  Maintenance::RunStore.atomic(File.join(output, 'native-inputs.json'), inputs)
  %w[build runtime].each do |name|
    folder = File.join(control, name); Dir.mkdir(folder)
    log = File.join(folder, 'command.log'); result = File.join(folder, 'check.json')
    env = ENV.to_h.merge('GEM_PATH' => gem_path, 'MOBI_RESULT_PATH' => result)
    status = File.open(log, 'w') do |stream|
      pid = Process.spawn(env, RbConfig.ruby, File.join(source, name == 'runtime' ? 'scripts/maintenance/lib/swift_export_pilot' : 'scripts/maintenance/lib/swift_export', name + '.rb'), source, output, cache, File.join(retained, 'NativeSources'), chdir: source, unsetenv_others: true, out: stream, err: [:child, :out], in: File::NULL)
      Process.wait2(pid).last
    end
    report['commands'] << { 'name' => name, 'exit' => status.exitstatus, 'log_sha256' => Maintenance.file_sha(log) }
    raise Maintenance::Failure, "Replay #{name} failed" unless status.success?
    report[name] = JSON.parse(File.read(result))
  end
  raise Maintenance::Failure, 'Retained delivery changed during replay' unless Maintenance::SwiftExport::Delivery.verify(delivery) == report['delivery_identity']
  report['status'] = 'passed'; report['assessment'] = 'review_required'
rescue StandardError => e
  report['error_class'], report['error'] = e.class.name, e.message
ensure
  Maintenance::RunStore.atomic(File.join(output, 'replay-report.json'), report)
  Maintenance::RunStore.atomic(ENV.fetch('MOBI_RESULT_PATH'), report)
end
exit(report['status'] == 'passed' ? 0 : 1)
