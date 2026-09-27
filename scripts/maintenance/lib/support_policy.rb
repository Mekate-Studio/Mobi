# frozen_string_literal: true

require_relative 'core'
require 'date'
require 'uri'

module Maintenance
  class SupportPolicy
    def initialize(policy, catalog, now: Time.now.utc)
      @policy, @catalog, @now = policy, catalog, now
      valid = policy.is_a?(Hash) && catalog.is_a?(Hash) && policy['schema'] == 1 && policy['automatic_adoption'] == false &&
              policy['evidence_max_age_hours'].is_a?(Integer) && (1..168).cover?(policy['evidence_max_age_hours']) &&
              policy['platforms'].is_a?(Hash) && !policy['platforms'].empty? && catalog['schema'] == 1 && catalog['platforms'].is_a?(Hash)
      raise Failure, 'Unsupported support policy/catalog' unless valid
    end

    def assess
      platforms = @policy['platforms'].map do |name, config|
        reasons = []
        raise Failure, 'Invalid platform configuration' unless config.is_a?(Hash)
        lag = config['stable_major_lag']
        raise Failure, 'Invalid stable-major lag or primary hosts' unless lag.is_a?(Integer) && (0..10).cover?(lag) && config['primary_hosts'].is_a?(Array) && !config['primary_hosts'].empty?
        rows = @catalog['platforms'][name]
        unless rows.is_a?(Array) && !rows.empty?
          next [name, { 'state' => 'incomplete', 'reasons' => ['missing_release_history'] }]
        end
        stable = []
        rows.each do |row|
          raise Failure, 'Malformed release family' unless row.is_a?(Hash) && row['major'].to_s.match?(/\A[1-9]\d*\z/) && %w[stable preview beta rc].include?(row['channel'])
          next unless row['channel'] == 'stable'
          date = Date.iso8601(row.fetch('released_on'))
          reasons << 'future_release' if date > @now.to_date
          reasons << 'missing_minimum_mapping' unless row['minimum'].to_s.match?(/\A\d+(?:\.\d+)?\z/)
          evidence = row['source']
          if !evidence.is_a?(Hash)
            reasons << 'missing_primary_evidence'
          else
            url = URI.parse(evidence.fetch('url', ''))
            reasons << 'untrusted_primary_url' unless url.scheme == 'https' && config['primary_hosts'].include?(url.host) && !url.userinfo
            reasons << 'missing_source_digest' unless evidence['sha256'].to_s.match?(/\A[0-9a-f]{64}\z/)
            stamp = Time.iso8601(evidence.fetch('retrieved_at'))
            reasons << 'future_evidence' if stamp > @now
            reasons << 'stale_evidence' if @now - stamp > @policy['evidence_max_age_hours'] * 3600
          end
          stable << row
        end
        reasons << 'ambiguous_release_history' unless stable.map { |r| r['major'].to_s }.uniq.size == stable.size && stable.map { |r| r['released_on'] }.uniq.size == stable.size
        ordered = stable.sort_by { |row| Date.iso8601(row['released_on']) }
        reasons << 'insufficient_stable_history' if ordered.size <= lag
        selected = ordered.reverse[lag]
        [name, { 'state' => reasons.empty? ? 'assessed' : 'incomplete', 'reasons' => reasons.uniq,
                 'latest_stable_major' => ordered.last && ordered.last['major'], 'stable_major_lag' => lag,
                 'proposed_major' => selected && selected['major'], 'proposed_minimum' => selected && selected['minimum'],
                 'evidence' => ordered.map { |row| row['source'] } }]
      end.to_h
      { 'schema' => 1, 'state' => platforms.values.all? { |p| p['state'] == 'assessed' } ? 'assessed' : 'incomplete',
        'policy_sha256' => Maintenance.digest(@policy), 'catalog_sha256' => Maintenance.digest(@catalog),
        'platforms' => platforms, 'evidence_scope' => 'reviewed_primary_release_history_not_automatic_global_discovery',
        'adoption_authorized' => false }
    rescue KeyError, ArgumentError, TypeError, URI::InvalidURIError
      raise Failure, 'Malformed support release evidence'
    end
  end
end
