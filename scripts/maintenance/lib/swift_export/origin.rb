# frozen_string_literal: true

require_relative '../run_store'

module Maintenance
  module SwiftExport
    module Origin
      def self.verify(store, id, delivery_identity)
        store.lock(id, create: false) do
          journal = store.load(id)
          result = JSON.parse(File.read(store.path(id, '.result.json')))
          raise Failure, 'Origin did not complete its source-bound checks' unless journal['state'] == 'checks_passed' && result['state'] == 'checks_passed' && result['run_id'] == id && result['binding'] == journal['binding']
          receipts = result.fetch('attempts').filter_map do |attempt|
            next unless attempt['state'] == 'stopped' && attempt['process_exit'] == 0
            step = journal.fetch('steps').find { |entry| entry['id'] == attempt['id'] }
            raise Failure, 'Origin attempt has no owned step' unless step
            path = store.safe_path(journal, step.fetch('path') + '/check.json')
            raise Failure, 'Origin check receipt changed' unless File.file?(path) && Maintenance.file_sha(path) == attempt.fetch('output_sha256').fetch('check.json')
            check = JSON.parse(File.read(path))
            next unless check['status'] == 'passed' && check.dig('delivery', 'identity') == delivery_identity
            { 'run_id' => id, 'phase' => check['phase'], 'source_sha256' => result.fetch('binding').fetch('source_sha256'),
              'delivery_identity' => delivery_identity, 'check_path' => path, 'check_sha256' => Maintenance.file_sha(path) }
          end
          raise Failure, 'Retained delivery does not belong to the stated origin run' if receipts.empty?
          receipts.first
        end
      rescue KeyError, JSON::ParserError, Errno::ENOENT => error
        raise Failure, 'Incomplete origin delivery evidence: ' + error.message
      end
    end
  end
end
