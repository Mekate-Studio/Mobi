# frozen_string_literal: true

require_relative '../swift_export/descriptor'

module Maintenance
  module SwiftExportPilot
    # Experiments can gather evidence; only reviewed, source-bound records can
    # request a qualified verdict. No fixture settings or count allowlist is used.
    module Review
      LIMITS = %w[parent_reservations native_jobs_per_owner compose_jobs_per_owner polling_nanoseconds backoff_nanoseconds shutdown_observation_nanoseconds].freeze
      SHA = /\A[0-9a-f]{64}\z/

      def self.settings(path, source_identity:, tuple_identity:, qualified:)
        raise Failure, 'Settings must be a regular non-symlink file' unless File.file?(path) && !File.symlink?(path)
        record = JSON.parse(File.read(path))
        raise Failure, 'Unsupported pilot settings' unless record['schema'] == 1 && %w[experimental reviewed].include?(record['status'])
        raise Failure, 'Settings source/tuple mismatch' unless record['source_identity'] == source_identity && record['tuple_identity'] == tuple_identity && [source_identity, tuple_identity].all? { |s| s.to_s.match?(SHA) }
        LIMITS.each do |key|
          value = record.fetch('limits').fetch(key)
          maximum = key.end_with?('_per_owner') ? 2**31 - 1 : 2**63 - 1
          raise Failure, "Explicit positive pilot limit required: #{key}" unless value.is_a?(Integer) && value.positive? && value <= maximum
        end
        raise Failure, 'Explicit busy/retry behavior required' unless record['busy_retry_behavior'] == 'reject-before-registration-and-manual-retry'
        raise Failure, 'Settings rationale required' unless record['rationale'].is_a?(String) && !record['rationale'].strip.empty?
        if qualified || record['status'] == 'reviewed'
          raise Failure, 'Qualified pilot needs reviewed settings' unless record['status'] == 'reviewed'
          raise Failure, 'Settings reviewer required' unless record['reviewer'].is_a?(String) && !record['reviewer'].strip.empty?
          verify_measurements(record.fetch('measurements'), source_identity, tuple_identity)
        end
        record
      rescue JSON::ParserError, KeyError, TypeError, Errno::ENOENT
        raise Failure, 'Malformed pilot settings record'
      end

      def self.verify_measurements(receipts, source_identity, tuple_identity)
        raise Failure, 'App measurement receipts required' unless receipts.is_a?(Array) && !receipts.empty?
        receipts.each do |receipt|
          path = receipt.fetch('path')
          raise Failure, 'Measurement receipt unavailable or changed' unless File.file?(path) && !File.symlink?(path) && Maintenance.file_sha(path) == receipt.fetch('sha256')
          measured = JSON.parse(File.read(path))
          raise Failure, 'Measurement source/tuple mismatch' unless measured['source_identity'] == source_identity && measured['tuple_identity'] == tuple_identity
          raise Failure, 'Real app measurement scope required' unless measured['scope'] == 'real-app-pilot'
          required = %w[cancellation retry background_foreground overlapping_owners retained_objects retained_jobs sustained_polling latency_distributions]
          raise Failure, 'Incomplete app measurements' unless measured['observations'].is_a?(Hash) && (required - measured['observations'].keys).empty? && required.all? { |key| !measured['observations'][key].nil? }
        end
      end

      def self.dispositions(findings, records, source_identity:, tuple_identity:)
        raise Failure, 'Unsupported disposition record' unless records['schema'] == 1 && records['source_identity'] == source_identity && records['tuple_identity'] == tuple_identity && records['findings'].is_a?(Array)
        records['findings'].each do |entry|
          raise Failure, 'Invalid finding fingerprint' unless entry['fingerprint'].to_s.match?(SHA)
          raise Failure, 'Missing scoped review fields' unless %w[emitter profile target message location rationale reviewer requalification_trigger].all? { |key| entry[key].is_a?(String) && !entry[key].strip.empty? }
          raise Failure, 'Unknown diagnostic disposition' unless %w[review_required accepted_for_pilot rejected].include?(entry['disposition'])
        end
        raise Failure, 'Duplicate diagnostic disposition' unless records['findings'].map { |entry| entry['fingerprint'] }.uniq.size == records['findings'].size
        findings.map do |finding|
          entry = records['findings'].find { |value| value['fingerprint'] == finding.fetch('fingerprint') }
          matched = entry && %w[emitter profile target message location].all? { |key| entry[key] == finding[key] }
          finding.merge('disposition' => matched ? entry['disposition'] : 'review_required')
        end
      rescue KeyError, TypeError
        raise Failure, 'Malformed diagnostic disposition record'
      end
    end
  end
end
