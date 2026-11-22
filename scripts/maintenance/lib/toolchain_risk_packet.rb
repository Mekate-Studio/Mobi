# frozen_string_literal: true

require_relative 'risk_acceptance'
require_relative 'advisory_review'

module Maintenance
  # Explicit manual review of retained evidence, not another build/attribution producer.
  module ToolchainRiskPacket
    def self.review(root, packet_path, decision_path: nil, now: Time.now.utc)
      source = Source.new(root)
      raise Failure, 'Symlinked risk packet or decision' if File.symlink?(packet_path) || decision_path && File.symlink?(decision_path)
      raw = File.read(packet_path); packet = JSON.parse(raw)
      directory = File.realpath(File.dirname(packet_path))
      read = lambda do |ref|
        relative = ref.fetch('path')
        raise Failure, 'Invalid risk evidence path' unless relative.is_a?(String) && !Pathname.new(relative).absolute? && !relative.split('/').any? { |part| %w[. ..].include?(part) || part.empty? }
        parts = relative.split('/')
        raise Failure, 'Symlinked risk evidence' if parts.each_index.any? { |i| File.symlink?(File.join(directory, *parts.take(i + 1))) }
        path = File.join(directory, relative)
        raise Failure, 'Risk evidence must be a file' unless File.file?(path)
        bytes = File.binread(path)
        raise Failure, 'Risk packet evidence digest differs' unless Digest::SHA256.hexdigest(bytes) == ref['sha256']
        bytes
      end
      raise Failure, 'Only explicit 0.14.1 packets are supported' unless packet['schema'] == 1 && packet['toolchain'] == '0.14.1'
      wrapper = File.read(File.join(root, 'kotlin'))
      raise Failure, 'Risk packet requires the exact candidate source' unless wrapper[/^kotlin_cli_version=(.+)$/, 1] == '0.14.1' && packet['source_binding_sha256'] == Maintenance.digest(source.files)
      raise Failure, 'Risk packet requires both captured scopes' unless packet.fetch('captures').keys.sort == %w[delegated distribution]
      qualifications = packet.fetch('qualification_receipts')
      raise Failure, 'Risk packet requires qualification receipts' unless qualifications.is_a?(Array) && !qualifications.empty?
      findings = []; summaries = []; receipts = []
      attribution = JSON.parse(read.call(packet.fetch('attribution')))
      raise Failure, 'Attribution differs from selected distribution' unless attribution['version'] == '0.14.1' && attribution.dig('archive', 'sha256') == wrapper[/^kotlin_cli_sha256=(.+)$/, 1]
      artifacts = attribution.fetch('jars').select { |row| row['state'] == 'maven_byte_reference' }.map { |row| row.slice('component', 'identity') }
      JSON.parse(read.call(packet.fetch('delegated_graphs'))).each do |capture|
        capture.fetch('data').fetch('configurations').each do |configuration|
          next if %w[not_collected not_resolvable].include?(configuration['state'])
          artifacts.concat(configuration.fetch('artifacts').select { |row| row.dig('component', 'kind') == 'maven' }.map { |row| row.slice('component', 'identity') })
        end
      end
      packet.fetch('captures').each_value do |capture|
        inputs = JSON.parse(read.call(capture.fetch('inputs')))
        raise Failure, 'Capture does not select 0.14.1' unless inputs.dig('phases', 'candidate', 'version') == '0.14.1'
        queries = inputs.fetch('phases').values.flat_map { |phase| phase.fetch('owners').values.flat_map { |owner| owner.fetch('queries') } }.uniq.sort_by { |q| [q.fetch('package').fetch('name'), q.fetch('version')] }
        raise Failure, 'Capture requires named Maven queries' unless !queries.empty? && queries.all? { |q| q.dig('package', 'ecosystem') == 'Maven' && q.dig('package', 'name').to_s.match?(/\A[^:\s]+:[^:\s]+\z/) && !q['version'].to_s.empty? }
        receipt = JSON.parse(read.call(capture.fetch('advisories')))
        raise Failure, 'Advisories differ from retained input capture' unless receipt['input_evidence_sha256'] == capture['inputs']['sha256']
        # The one-off captures predate run_id envelopes. Keep every original raw
        # provider packet, adapting only the envelope for the existing verifier.
        report = { 'direct_resolution' => { 'candidate' => { 'advisory_queries' => { 'queries' => queries } } } }
        summary = AdvisoryReview.verify!(receipt, report, now: now)
        summaries << summary; receipts << receipt
        records = receipt.fetch('records').to_h { |row| data = JSON.parse(row.fetch('body')); [data.fetch('id'), data] }
        candidate_queries = inputs.fetch('phases').fetch('candidate').fetch('owners').values.flat_map { |owner| owner.fetch('queries') }
        candidate_matches = summary['matches'].select { |match| candidate_queries.include?(match['query']) }
        candidate_matches.map { |match| match['id'] }.uniq.each do |id|
          matches = candidate_matches.select { |match| match['id'] == id }
          selected = artifacts.select do |artifact|
            component = artifact['component']
            matches.any? { |match| match.dig('query', 'package', 'name') == component['group'] + ':' + component['name'] && match.dig('query', 'version') == component['version'] }
          end
          findings << { 'id' => id, 'severity' => records[id]&.dig('database_specific', 'severity'), 'artifacts' => selected.uniq }
        end
      end
      findings = findings.group_by { |row| [row['id'], row['severity']] }.map do |(id, severity), rows|
        { 'id' => id, 'severity' => severity, 'artifacts' => rows.flat_map { |row| row['artifacts'] }.uniq }
      end.sort_by { |row| [row['id'], row['severity'].to_s] }
      packet.fetch('qualification_receipts').each { |ref| JSON.parse(read.call(ref)) }
      patch = read.call(packet.fetch('applied_patch'))
      release = packet.fetch('release_receipt'); body = release.fetch('body'); data = JSON.parse(body)
      release_ok = release['url'] == 'https://api.github.com/repos/JetBrains/kotlin-toolchain/releases/tags/v0.14.1' && release['status'] == 200 && release['response_sha256'] == Digest::SHA256.hexdigest(body) && data['tag_name'] == 'v0.14.1' && data['prerelease'] == false && data['draft'] == false
      evidence = {
        'toolchain' => wrapper[/^kotlin_cli_version=(.+)$/, 1], 'distribution_sha256' => wrapper[/^kotlin_cli_sha256=(.+)$/, 1],
        'source_binding_sha256' => Maintenance.digest(source.files), 'applied_patch_sha256' => Digest::SHA256.hexdigest(patch),
        'review_packet_sha256' => Digest::SHA256.hexdigest(raw), 'coverage_gaps' => packet.fetch('coverage_gaps'),
        'operation' => 'public_source_development_builds', 'attribution' => 'measured_file_identities_accounted_for', 'findings' => findings,
        'release' => { 'complete' => release_ok, 'retrieved_at' => release['retrieved_at'], 'response_sha256' => release['response_sha256'], 'published_at' => data.fetch('published_at') },
        'advisory' => { 'complete' => summaries.all? { |s| s['reasons'].empty? },
                        'retrieved_at' => receipts.flat_map { |r| r['batches'] + r['records'] }.map { |p| p['retrieved_at'] }.min,
                        'response_sha256' => Maintenance.digest(receipts) }
      }
      pending_reasons = ['approval_missing_or_revoked', 'compatibility_not_reviewed']
      pending_reasons << 'advisory_evidence_incomplete' unless evidence['advisory']['complete']
      fetched = Time.iso8601(release.fetch('retrieved_at'))
      pending_reasons << 'release_evidence_incomplete' unless release_ok && fetched <= now && now - fetched <= 86_400
      decision = decision_path ? JSON.parse(File.read(decision_path)) : nil
      evidence['compatibility'] = decision && decision['qualification_receipts_reviewed'] == true ? 'passed' : 'pending'
      result = if decision
                 RiskAcceptance.evaluate(decision, evidence, now: now)
               else
                 { 'schema' => 1, 'state' => 'blocked', 'reasons' => pending_reasons, 'findings' => findings,
                   'adoption_authorized' => false, 'remediation_verified' => false, 'bridge_retirement' => 'defer' }
               end
      result.merge!('review_packet_sha256' => evidence['review_packet_sha256'], 'coverage_gaps' => evidence['coverage_gaps'],
                    'query_count' => summaries.sum { |summary| summary['query_count'] }, 'providers' => summaries,
                    'compatibility_basis' => 'manual_review_of_hash_bound_qualification_receipts', 'dependency_surface' => 'bounded_measured_inputs')
      source.verify!
      result
    rescue KeyError, JSON::ParserError, TypeError, NoMethodError, ArgumentError
      raise Failure, 'Malformed toolchain risk packet'
    end
  end
end
