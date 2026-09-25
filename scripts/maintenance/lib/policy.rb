# frozen_string_literal: true

require_relative 'core'
require 'uri'
require 'rubygems/version'

module Maintenance
  class Policy
    def initialize(policy, now: Time.now.utc)
      valid = policy.is_a?(Hash) && policy['schema'] == 1 &&
              %w[minimum_release_age_days release_evidence_max_age_hours advisory_max_age_hours].all? { |key| policy[key].is_a?(Integer) && policy[key] > 0 } &&
              policy['minimum_release_age_days'] >= 7 && policy['advisory_max_age_hours'] <= 24 &&
              policy['blocking_severities'].is_a?(Array) && %w[high critical].all? { |severity| policy['blocking_severities'].include?(severity) } &&
              policy['unknown_severity'] == 'requires_triage' && policy['automatic_adoption'] == false
      raise Failure, 'Unsupported or unsafe maintenance policy' unless valid
      @policy = policy
      @now = now
    end

    def timestamp(value)
      return nil unless value.is_a?(String) && value.match?(/T.*(?:Z|[+-]\d{2}:\d{2})\z/)
      Time.iso8601(value).utc
    rescue ArgumentError, TypeError
      nil
    end

    def provider_errors(provider, max_age)
      return ['missing_provider'] unless provider.is_a?(Hash)
      errors = []
      errors << 'provider_failed' unless provider['status'] == 'ok'
      errors << 'provider_incomplete' unless provider['complete'] == true
      errors << 'missing_response_digest' unless provider['response_sha256'].to_s.match?(/\A[0-9a-f]{64}\z/)
      errors << 'missing_primary_url' unless provider['url'].to_s.match?(%r{\Ahttps://[^/]+/})
      fetched = timestamp(provider['retrieved_at'])
      errors << 'missing_provider_timestamp' unless fetched
      errors << 'future_provider_timestamp' if fetched && fetched > @now
      errors << 'stale_provider' if fetched && @now - fetched > max_age
      errors
    end

    def release(component, candidate, provider)
      reasons = provider_errors(provider, @policy.fetch('release_evidence_max_age_hours') * 3600)
      published = timestamp(candidate['published_at'])
      reasons << 'missing_publication_timestamp' unless published
      reasons << 'too_new' if published && @now - published < @policy.fetch('minimum_release_age_days') * 86_400
      version = candidate['version'].to_s
      current = (component['version'] || component['locked_version']).to_s
      reasons << 'prerelease' if candidate['prerelease'] != false || version.match?(/[-+]|alpha|beta|rc/i)
      parsed = version.sub(/\Av/, '')
      baseline = current.sub(/\Av/, '')
      unless parsed.match?(/\A\d+(?:\.\d+){1,3}\z/) && baseline.match?(/\A\d+(?:\.\d+){1,3}\z/)
        reasons << 'unsupported_version_comparison'
      else
        reasons << 'not_newer' if Gem::Version.new(parsed) <= Gem::Version.new(baseline)
        reasons << 'major_requires_review' if parsed.split('.').first.to_i > baseline.split('.').first.to_i
        Array(component['ceilings']).each do |ceiling|
          if ceiling.match?(/\A<\d+(?:\.\d+){1,3}\z/)
            reasons << "ceiling:#{ceiling}" if Gem::Version.new(parsed) >= Gem::Version.new(ceiling.delete_prefix('<'))
          else
            reasons << 'unsupported_ceiling'
          end
        end
      end
      { 'raw' => candidate, 'version' => candidate['version'], 'published_at' => candidate['published_at'], 'reasons' => reasons.uniq, 'eligible_for_review' => reasons.empty? }
    end

    def evaluate(inventory, evidence)
      expected = Maintenance.digest(inventory.reject { |key, _| key == 'id' })
      raise Failure, 'Inventory identity is invalid' unless inventory['schema'] == 1 && inventory['id'] == expected
      raise Failure, 'Evidence does not match this inventory' unless evidence['schema'] == 1 && evidence['inventory_id'] == inventory['id']

      components = inventory.fetch('components').to_h { |c| [c.fetch('id'), c] }
      releases = Array(evidence['releases']).map do |packet|
        component = components[packet.fetch('component_id')]
        raise Failure, 'Release evidence names an unknown component' unless component
        { 'component_id' => component['id'], 'provider_errors' => provider_errors(packet['provider'], @policy.fetch('release_evidence_max_age_hours') * 3600),
          'candidates' => packet.fetch('versions').map { |candidate| release(component, candidate, packet['provider']) } }
      end
      gaps = inventory.fetch('coverage').select { |row| row['required'] && row['state'] != 'complete' }.map { |row| row.fetch('id') }
      receipts = Array(evidence['advisories'])
      required = inventory.fetch('resolved_inputs')
      raise Failure, 'Advisory evidence names an unknown resolved input' if receipts.any? { |receipt| !required.any? { |input| input['id'] == receipt['input_id'] } }
      advisory = required.map do |input|
        matches = receipts.select { |item| item['input_id'] == input['id'] }
        receipt = matches.size == 1 ? matches.first : nil
        reasons = provider_errors(receipt && receipt['provider'], @policy.fetch('advisory_max_age_hours') * 3600)
        reasons << 'missing_or_duplicate_advisory_receipt' unless receipt
        reasons << 'resolved_input_mismatch' if receipt && receipt['input_sha256'] != input['sha256']
        findings = receipt ? receipt['findings'] : []
        reasons << 'malformed_findings' unless findings.is_a?(Array)
        findings = [] unless findings.is_a?(Array)
        findings.each do |finding|
          unless finding.is_a?(Hash)
            reasons << 'malformed_findings'
            next
          end
          severity = finding['severity'].to_s.downcase
          reasons << 'finding_requires_triage' unless %w[low moderate medium high critical].include?(severity) && finding['id'].is_a?(String) && !finding['id'].empty?
          reasons << 'blocking_vulnerability' if @policy.fetch('blocking_severities').include?(severity)
        end
        { 'input_id' => input['id'], 'reasons' => reasons.uniq, 'findings' => findings }
      end
      incomplete = !gaps.empty? || required.empty? || releases.empty? || releases.any? { |r| !r['provider_errors'].empty? || r['candidates'].any? { |c| c['reasons'].any? { |reason| reason.start_with?('missing_', 'unsupported_', 'provider_', 'stale_', 'future_') } } } ||
                   advisory.any? { |a| (a['reasons'] - ['blocking_vulnerability']).any? }
      blocked = advisory.any? { |a| a['reasons'].include?('blocking_vulnerability') }
      { 'schema' => 1, 'inventory_id' => inventory['id'], 'evidence_sha256' => Maintenance.digest(evidence), 'evaluated_at' => @now.iso8601,
        'state' => incomplete ? 'incomplete' : blocked ? 'blocked' : 'checks_passed',
        'missing_coverage' => gaps, 'release_scope' => releases.empty? ? 'not_provided' : 'only_named_components',
        'releases' => releases, 'advisories' => advisory, 'adoption_authorized' => false }
    end
  end
end
