# frozen_string_literal: true

require_relative '../../lib/swift_export/registry'
nonce, registry_path, store_path, run_id, output, mode = ARGV
registry = Maintenance::SwiftExport::Registry.new(registry_path)
owner = Maintenance::ProcessGroup.identity(Process.pid).merge('host' => Maintenance::ProcessGroup.host, 'nonce' => nonce)
store = Maintenance::RunStore.new(store_path); journal = store.load(run_id)
control = store.directory(journal, 'steps/reader', disposable: false)
journal['steps'] << { 'id' => 'reader', 'path' => 'steps/reader', 'nonce' => nonce, 'owner' => owner }
store.save(journal)
path, pin = registry.pin(owner: owner, run: { 'store' => store_path, 'run_id' => run_id })
Maintenance::RunStore.atomic(File.join(output, 'ready.json'), 'pin' => pin, 'identity' => Maintenance::SwiftExport::Delivery.verify(path))
if mode == 'descendant'
  fork do
    identity = Maintenance::ProcessGroup.identity(Process.pid).merge('host' => Maintenance::ProcessGroup.host, 'nonce' => nonce)
    Maintenance::RunStore.atomic(File.join(output, 'descendant.json'), identity)
    sleep 300
  end
  sleep 0.01 until File.exist?(File.join(output, 'descendant.json'))
  exit! 0
end
sleep 0.02 until File.exist?(File.join(output, 'release'))
raise Maintenance::Failure, 'Pinned delivery changed' unless Maintenance::SwiftExport::Delivery.verify(path) == pin['object']
registry.release(pin['id'])
Maintenance::RunStore.atomic(File.join(output, 'done.json'), 'identity' => pin['object'])
