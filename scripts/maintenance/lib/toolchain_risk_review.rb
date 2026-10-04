# frozen_string_literal: true

require_relative 'risk_acceptance'
require_relative 'plugin_attribution'

module Maintenance
  module ToolchainRiskReview
    def self.review(root, now: Time.now.utc)
      decision_path = File.join(root, 'maintenance-toolchain-risk-acceptance.json')
      raise Failure, 'Symlinked manual decision' if File.symlink?(decision_path)
      decision = JSON.parse(File.read(decision_path))
      source = Source.new(root)
      bindings = decision.fetch('source_files').map do |row|
        identity = source.files.fetch(row.fetch('path'))
        { 'path' => row['path'], 'sha256' => identity['sha256'], 'executable' => identity['executable'] }
      end
      raise Failure, 'Duplicate source bindings' unless bindings.map { |r| r['path'] }.uniq.size == bindings.size
      ids = decision.fetch('producers')
      raise Failure, 'Unreviewed producer identity' unless ids == { 'store' => 'upstream-remediation', 'plugin' => 'f0d6207beefc5d95faa0793e1a9a5a4e', 'bundled' => 'ee4c6a7e32a1db3782ec81933a02522d' }
      store = RunStore.new(File.join(root, '.maintenance', 'runs-' + ids['store']))
      report = store.lock(ids['plugin'], create: false) { PluginAttribution.report(store, ids['plugin']) }
      bundled = BundledAttribution.report(root, store, ids['bundled'])
      raw = JSON.parse(File.read(File.join(store.path(ids['plugin']), 'advisory-review.json')))
      summary = AdvisoryReview.verify!(raw, report, now: now)
      records = raw['records'].to_h { |p| [JSON.parse(p['body']).fetch('id'), JSON.parse(p['body'])] }
      artifacts = bundled.fetch('bundled_settings_inputs').fetch('matches').map { |m| { 'component' => m['reference_component'], 'identity' => m['identity'] } }
      artifacts += bundled.fetch('bundled_file_attribution').fetch('files').filter_map do |m|
        { 'component' => m.fetch('component').merge('kind' => 'maven'), 'identity' => m['identity'] } if m['kind'] == 'maven_reference'
      end
      findings = summary.fetch('finding_ids').map do |id|
        matches = summary['matches'].select { |m| m['id'] == id }.map { |m| m['query'] }
        selected = artifacts.select do |a|
          c = a['component']; matches.any? { |q| q.dig('package', 'name') == c['group'] + ':' + c['name'] && q['version'] == c['version'] }
        end.uniq
        { 'id' => id, 'severity' => records.fetch(id).dig('database_specific', 'severity'), 'artifacts' => selected }
      end
      release = decision.fetch('release_receipt')
      body = release.fetch('body'); data = JSON.parse(body)
      release_ok = release['url'] == 'https://api.github.com/repos/JetBrains/kotlin-toolchain/releases/tags/v0.13.0' && release['status'] == 200 && release['response_sha256'] == Digest::SHA256.hexdigest(body) && data['tag_name'] == 'v0.13.0' && data['prerelease'] == false && data['draft'] == false
      compatibility = 'pending'
      if decision['compatibility_run']
        run = decision.fetch('compatibility_run')
        raise Failure, 'Invalid compatibility run binding' unless run['id'].to_s.match?(/\A[0-9a-f]{32}\z/) && run['store'] == 'adoption-direct'
        checks = CompatibilityReport.read(RunStore.new(File.join(root, '.maintenance/runs-adoption-direct')), run['id'])
        compatibility = 'passed' if checks['state'] == 'checks_passed' && checks['result_sha256'] == run['result_sha256'] && checks.dig('binding', 'source_sha256') == run['source_sha256']
      end
      evidence = {
        'toolchain' => File.read(File.join(root, 'kotlin'))[/^kotlin_cli_version=(.+)$/, 1],
        'distribution_sha256' => File.read(File.join(root, 'kotlin'))[/^kotlin_cli_sha256=(.+)$/, 1],
        'applied_patch_sha256' => Maintenance.file_sha(File.join(root, 'docs/maintenance/evidence/2026-10-04-toolchain-adoption-applied.patch')), 'source_binding_sha256' => Maintenance.digest(bindings),
        'operation' => 'public_source_development_builds', 'compatibility' => compatibility,
        'attribution' => bundled.fetch('bundled_file_attribution').fetch('state'), 'findings' => findings,
        'release' => { 'complete' => release_ok, 'retrieved_at' => release['retrieved_at'], 'response_sha256' => release['response_sha256'], 'published_at' => data.fetch('published_at') },
        'advisory' => { 'complete' => summary['reasons'].empty? && %w[triage_required provider_complete].include?(summary['state']),
                        'retrieved_at' => (raw['batches'] + raw['records']).map { |p| p['retrieved_at'] }.min, 'response_sha256' => summary['receipt_sha256'] }
      }
      result = RiskAcceptance.evaluate(decision, evidence, now: now)
      result.merge!('query_count' => summary['query_count'], 'provider_scope' => summary['scope'], 'decision_sha256' => Maintenance.file_sha(decision_path),
                    'measured_input_source' => 'retained_verified_producers_not_new_integrated_selection')
      source.verify!
      result
    rescue KeyError, JSON::ParserError
      raise Failure, 'Malformed toolchain risk decision or evidence'
    end
  end
end
