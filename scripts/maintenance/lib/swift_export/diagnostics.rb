# frozen_string_literal: true

require_relative 'descriptor'

module Maintenance
  module SwiftExport
    module Diagnostics
      def self.fingerprints(text, emitter:, inputs:, roots: [])
        text.lines.filter_map do |line|
          next unless line.match?(/(?:warning:|error:|Unsupported target feature|Unbalanced calls|contentInset)/i)
          normalized = roots.sort_by { |p| -p.size }.reduce(line.strip) { |value, root| value.gsub(root, '<owned>') }
          if line.match?(/Unbalanced calls|contentInset/i)
            normalized = normalized.sub(/\A\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\.\d+\s+/, '').gsub(/\[\d+:\d+\]/, '[<process>]').gsub(/0x[0-9a-fA-F]+/, '<address>')
          end
          finding = { 'emitter' => emitter, 'input_identity' => inputs, 'message_location' => normalized }
          finding.merge('fingerprint' => Maintenance.digest(finding), 'disposition' => 'review_required')
        end.uniq { |f| f['fingerprint'] }
      end
    end
  end
end
