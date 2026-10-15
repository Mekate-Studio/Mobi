# frozen_string_literal: true

require 'minitest/autorun'
require_relative 'lib/swift_export/origin'

class SwiftExportOriginTest < Minitest::Test
  def test_origin_binding_refuses_other_delivery_mutated_receipts_and_incomplete_runs
    Dir.mktmpdir('mobi-export-origin-') do |root|
      store = Maintenance::RunStore.new(File.join(root, 'runs')); id = SecureRandom.hex(16); identity = 'a' * 64
      journal = nil; path = nil
      store.lock(id) do
        journal = store.allocate(id, { 'source_sha256' => 'b' * 64 }, {})
        control = store.directory(journal, 'steps/producer', disposable: false); path = File.join(control, 'check.json')
        Maintenance::RunStore.atomic(path, 'status' => 'passed', 'phase' => 'candidate', 'delivery' => { 'identity' => identity })
        journal['steps'] << { 'id' => 'producer', 'path' => 'steps/producer' }; store.save(journal)
        store.result(journal, 'run_id' => id, 'state' => 'checks_passed', 'ended_at' => Time.now.utc.iso8601, 'binding' => journal['binding'],
                              'attempts' => [{ 'id' => 'producer', 'state' => 'stopped', 'process_exit' => 0, 'output_sha256' => { 'check.json' => Maintenance.file_sha(path) } }])
      end
      proof = Maintenance::SwiftExport::Origin.verify(store, id, identity)
      assert_equal identity, proof['delivery_identity']; assert_equal 'candidate', proof['phase']; assert_equal 'b' * 64, proof['source_sha256']
      assert_raises(Maintenance::Failure) { Maintenance::SwiftExport::Origin.verify(store, id, 'c' * 64) }
      original = File.read(path); File.write(path, original + ' ')
      assert_raises(Maintenance::Failure) { Maintenance::SwiftExport::Origin.verify(store, id, identity) }; File.write(path, original)
      journal['state'] = 'inconclusive'; store.save(journal)
      assert_raises(Maintenance::Failure) { Maintenance::SwiftExport::Origin.verify(store, id, identity) }
    end
  end
end
