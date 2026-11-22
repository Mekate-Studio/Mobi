# frozen_string_literal: true

require_relative 'core'

module Maintenance
  # Manual review only. Discovery findings and automatic adoption remain unchanged.
  module RiskAcceptance
    OPERATIONS = %w[public_source_development_builds repository_tests isolated_compatibility_assessment].freeze

    CANDIDATE_GAPS = %w[unassigned_or_ambiguous_files shaded_or_native_code configurations_outside_android_debug unsupported_transform_observer device_exact_floor_signed_delivery].freeze

    def self.evaluate(decision, evidence, now: Time.now.utc)
      raise Failure, 'Malformed manual risk review' unless decision.is_a?(Hash) && evidence.is_a?(Hash)
      reasons = []
      reasons << 'approval_missing_or_revoked' unless decision['schema'] == 1 && decision['approved'] == true && decision['state'] == 'approved_conditional' && decision['revoked'] == false && !decision['approval_reference'].to_s.empty?
      reasons << 'missing_reason_or_controls' unless !decision['reason'].to_s.empty? && decision['controls'].is_a?(Array) && !decision['controls'].empty?
      start = Time.iso8601(decision.fetch('starts_at')); expiry = Time.iso8601(decision.fetch('expires_at'))
      reasons << 'decision_outside_window' unless start <= now && now < expiry && expiry > start && expiry - start <= 30 * 86_400
      reasons << 'operation_outside_scope' unless OPERATIONS.include?(evidence['operation']) && decision.fetch('allowed_operations').include?(evidence['operation'])
      %w[toolchain distribution_sha256 applied_patch_sha256 source_binding_sha256].each do |key|
        value = decision.fetch(key)
        raise Failure, 'Invalid decision identity' unless key == 'toolchain' ? %w[0.13.0 0.14.1].include?(value) : value.to_s.match?(/\A[0-9a-f]{64}\z/)
        reasons << key + '_drift' unless value == evidence[key]
      end
      if evidence['toolchain'] == '0.14.1'
        binding = decision['review_packet_sha256']
        reasons << 'review_packet_drift' unless binding.to_s.match?(/\A[0-9a-f]{64}\z/) && binding == evidence['review_packet_sha256']
        gaps = evidence['coverage_gaps']
        reasons << 'coverage_gaps_not_acknowledged' unless gaps.is_a?(Array) && (CANDIDATE_GAPS - gaps).empty? && gaps == decision['acknowledged_coverage_gaps']
      end
      %w[release advisory].each do |key|
        provider = evidence.fetch(key)
        fetched = Time.iso8601(provider.fetch('retrieved_at'))
        reasons << key + '_evidence_incomplete' unless provider['complete'] == true && fetched <= now && now - fetched <= 86_400 && provider['response_sha256'].to_s.match?(/\A[0-9a-f]{64}\z/)
      end
      reasons << 'compatibility_not_passed' unless evidence['compatibility'] == 'passed'
      reasons << 'attribution_incomplete' unless evidence['attribution'] == 'measured_file_identities_accounted_for'
      expected = decision.fetch('known_findings')
      observed = evidence.fetch('findings')
      raise Failure, 'Malformed finding sets' unless expected.is_a?(Array) && observed.is_a?(Array) && !expected.empty? && !observed.empty?
      raise Failure, 'Duplicate decision finding IDs' unless expected.map { |f| f.fetch('id') }.uniq.size == expected.size
      reasons << 'new_or_missing_finding' unless expected.map { |f| f.fetch('id') }.sort == observed.map { |f| f.fetch('id') }.uniq.sort
      accepted = []
      observed.each do |finding|
        severity = finding.fetch('severity').to_s.downcase
        reasons << 'unknown_severity' unless %w[low moderate medium high critical].include?(severity)
        match = expected.find { |f| f['id'] == finding['id'] && f['severity'].to_s.downcase == severity }
        reasons << 'finding_scope_drift' unless match
        next unless %w[high critical].include?(severity)
        grant = decision.fetch('findings').find { |f| f['id'] == finding['id'] && f['severity'].to_s.downcase == severity }
        artifacts = finding.fetch('artifacts')
        valid = artifacts.is_a?(Array) && !artifacts.empty? && artifacts.all? do |artifact|
          id = artifact.fetch('identity')
          id['kind'] == 'file' && id['bytes'].is_a?(Integer) && id['bytes'].positive? && id['sha256'].to_s.match?(/\A[0-9a-f]{64}\z/) && grant && grant.fetch('artifacts').include?(artifact)
        end
        reasons << 'artifact_scope_drift' unless valid
        accepted << finding['id'] if valid
      end
      published = Time.iso8601(evidence.fetch('release').fetch('published_at'))
      raise Failure, 'Release publication is in the future' if published > now
      young = now < published + 7 * 86_400
      waiver = decision.fetch('age_exception')
      waiver_valid = waiver['approved'] == true && waiver['version'] == evidence['toolchain'] && waiver['published_at'] == evidence['release']['published_at'] && waiver['decision_at'] == decision['starts_at']
      if young
        if evidence['toolchain'] == '0.14.1' && waiver['scope'] != 'scoped_manual_risk_use'
          reasons << 'age_exception_scope_differs'; waiver_valid = false
        end
        reasons << 'age_exception_missing' unless waiver_valid
      end
      { 'schema' => 1, 'state' => reasons.empty? ? 'accepted_risk_for_scoped_manual_use' : 'blocked',
        'reasons' => reasons.uniq.sort, 'accepted_risk_ids' => reasons.empty? ? accepted.uniq.sort : [], 'findings' => observed,
        'age_state' => young ? (waiver_valid ? 'age_blocked_with_explicit_exception' : 'age_blocked') : 'age_eligible', 'expires_at' => expiry.iso8601,
        'dependency_surface' => 'bounded_measured_inputs', 'remediation_verified' => false,
        'adoption_authorized' => false, 'bridge_retirement' => 'defer' }
    rescue KeyError, TypeError, NoMethodError, ArgumentError
      raise Failure, 'Malformed manual risk review'
    end
  end
end
