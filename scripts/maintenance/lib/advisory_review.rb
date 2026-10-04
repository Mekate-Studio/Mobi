# frozen_string_literal: true

require_relative 'core'

module Maintenance
  module AdvisoryReview
    API = 'https://api.osv.dev/v1/'
    ID = /\A[A-Za-z0-9][A-Za-z0-9_.-]{0,199}\z/

    def self.query_evidence(report, phase)
      return 'named_baseline_reference_and_independent_bytes' if phase == 'candidate' && report['bundled_file_attribution']
      phase == 'candidate' && report.dig('bundled_settings_inputs', 'matches')&.any? ? 'named_and_unique_reference_bytes' : 'named_resolved'
    end

    # No credentials, shell expansion or redirected provider URLs. Partial
    # packets remain evidence; they never become a clean lookup by omission.
    def self.request(url, payload = nil)
      argv = ['/usr/bin/curl', '--silent', '--show-error', '--proto', '=https', '--connect-timeout', '10', '--max-time', '30', '--write-out', '\n%{http_code}', url]
      argv += ['--header', 'Content-Type: application/json', '--data-binary', '@-'] if payload
      out, _error, status = Open3.capture3(*argv, stdin_data: payload ? JSON.generate(payload) : '')
      body, _separator, code = out.rpartition("\n")
      { 'url' => url, 'request' => payload, 'status' => status.success? ? code.to_i : 0, 'retrieved_at' => Time.now.utc.iso8601,
        'body' => body, 'response_sha256' => Digest::SHA256.hexdigest(body) }
    rescue SystemCallError
      body = '{}'
      { 'url' => url, 'request' => payload, 'status' => 0, 'retrieved_at' => Time.now.utc.iso8601,
        'body' => body, 'response_sha256' => Digest::SHA256.hexdigest(body) }
    end

    def self.collect(report, phase: 'candidate', transport: method(:request), checkpoint: ->(_receipt) {})
      raise Failure, 'Advisories require a passing direct-resolution pair' unless report['state'] == 'checks_passed' && report['direct_resolution'].is_a?(Hash)
      raise Failure, 'Unknown advisory phase' unless %w[baseline candidate].include?(phase)
      queries = report.fetch('direct_resolution').fetch(phase).fetch('advisory_queries').fetch('queries')
      raise Failure, 'Advisories require a passing direct-resolution pair' unless report['state'] == 'checks_passed' && !queries.empty?
      receipt = { 'schema' => 1, 'run_id' => report['run_id'], 'result_sha256' => report['result_sha256'],
                  'queries_sha256' => Maintenance.digest(queries), 'queries' => queries, 'batches' => [], 'records' => [], 'adoption_authorized' => false }
      receipt['phase'] = phase if phase != 'candidate'
      scope = query_evidence(report, phase)
      receipt['query_evidence'] = scope unless scope == 'named_resolved'
      receipt['input_evidence_sha256'] = report['input_evidence_sha256'] if scope == 'named_baseline_reference_and_independent_bytes'
      checkpoint.call(receipt)
      ids = []
      queries.each_slice(100) do |batch|
        packet = transport.call(API + 'querybatch', { 'queries' => batch })
        receipt['batches'] << packet
        checkpoint.call(receipt)
        begin
          data = JSON.parse(packet.fetch('body'))
          next unless packet['status'] == 200 && data['results'].is_a?(Array) && data['results'].size == batch.size
          data['results'].select { |row| row.is_a?(Hash) }.each { |row| Array(row['vulns']).each { |v| ids << v['id'] if v.is_a?(Hash) && v['id'].to_s.match?(ID) } }
        rescue JSON::ParserError, KeyError, TypeError
          next
        end
      end
      ids.uniq.sort.each do |id|
        receipt['records'] << transport.call(API + 'vulns/' + id, nil)
        checkpoint.call(receipt)
      end
      verify!(receipt, report)
      receipt
    end

    def self.packet(packet, url, payload, now)
      unless packet['url'] == url && packet['request'] == payload && packet['body'].is_a?(String) && packet['response_sha256'] == Digest::SHA256.hexdigest(packet['body']) && packet['status'].is_a?(Integer)
        raise Failure, 'Advisory response binding mismatch'
      end
      time = Time.iso8601(packet.fetch('retrieved_at'))
      raise Failure, 'Future advisory timestamp' if time > now
      reasons = []
      reasons << 'stale_provider' if now - time > 86_400
      reasons << 'provider_failed' if packet['status'] != 200
      data = JSON.parse(packet['body']) rescue nil
      reasons << 'malformed_provider_response' unless data.is_a?(Hash)
      [data, reasons]
    end

    def self.verify!(receipt, report, now: Time.now.utc)
      phase = receipt.fetch('phase', 'candidate')
      raise Failure, 'Unknown advisory phase' unless %w[baseline candidate].include?(phase)
      queries = report.fetch('direct_resolution').fetch(phase).fetch('advisory_queries').fetch('queries')
      unless receipt['schema'] == 1 && receipt['run_id'] == report['run_id'] && receipt['result_sha256'] == report['result_sha256'] && receipt['queries'] == queries &&
             receipt['queries_sha256'] == Maintenance.digest(queries) && receipt['adoption_authorized'] == false && receipt['batches'].is_a?(Array) && receipt['records'].is_a?(Array)
        raise Failure, 'Advisory receipt is not bound to this resolution run'
      end
      query_evidence = self.query_evidence(report, phase)
      raise Failure, 'Advisory query evidence scope differs' unless receipt.fetch('query_evidence', 'named_resolved') == query_evidence
      if query_evidence == 'named_baseline_reference_and_independent_bytes'
        raise Failure, 'Advisory attribution producer binding differs' unless report['input_evidence_sha256'].to_s.match?(/\A[0-9a-f]{64}\z/) && receipt['input_evidence_sha256'] == report['input_evidence_sha256']
      end
      batches = queries.each_slice(100).to_a
      reasons = []; matches = []; ids = []
      reasons << 'missing_or_extra_batches' unless receipt['batches'].size == batches.size
      receipt['batches'].each_with_index do |entry, index|
        raise Failure, 'Unexpected advisory batch' unless batches[index]
        data, errors = packet(entry, API + 'querybatch', { 'queries' => batches[index] }, now)
        reasons.concat(errors)
        next unless errors.empty?
        rows = data['results']
        unless rows.is_a?(Array) && rows.size == batches[index].size
          reasons << 'response_cardinality_mismatch'; next
        end
        rows.each_with_index do |row, i|
          unless row.is_a?(Hash) && (row.keys - %w[vulns next_page_token]).empty? && (!row.key?('vulns') || row['vulns'].is_a?(Array))
            reasons << 'malformed_query_result'; next
          end
          reasons << 'pagination_incomplete' if row['next_page_token'] && row['next_page_token'] != ''
          Array(row['vulns']).each do |v|
            unless v.is_a?(Hash) && v['id'].is_a?(String) && v['id'].match?(ID) && v['modified'].is_a?(String)
              reasons << 'malformed_finding'; next
            end
            ids << v['id']
            matches << { 'query' => batches[index][i], 'id' => v['id'], 'triage' => 'required' }
          end
        end
      end
      seen = []
      receipt['records'].each do |entry|
        id = entry.fetch('url').delete_prefix(API + 'vulns/')
        raise Failure, 'Unexpected or duplicate advisory record' unless id.match?(ID) && ids.include?(id) && !seen.include?(id)
        seen << id
        data, errors = packet(entry, API + 'vulns/' + id, nil, now)
        reasons.concat(errors)
        reasons << 'finding_record_mismatch' if errors.empty? && (data['id'] != id || !data['affected'].is_a?(Array) || data['affected'].empty? || !data['modified'].is_a?(String))
      end
      reasons << 'missing_finding_records' unless seen.sort == ids.uniq.sort
      scopes = { 'named_resolved' => 'named_resolved_maven_packages_only', 'named_and_unique_reference_bytes' => 'named_and_reference_byte_attributed_packages_only', 'named_baseline_reference_and_independent_bytes' => 'named_baseline_reference_and_independent_byte_attributed_packages_only' }
      { 'state' => reasons.empty? ? (matches.empty? ? 'provider_complete' : 'triage_required') : 'incomplete',
        'scope' => phase + '_' + scopes.fetch(query_evidence), 'query_count' => queries.size, 'finding_ids' => ids.uniq.sort, 'matches' => matches.uniq,
        'reasons' => reasons.uniq.sort, 'receipt_sha256' => Maintenance.digest(receipt), 'dependency_surface' => 'incomplete',
        'missing_capabilities' => %w[compiler_plugin_resolution artifact_attribution complete_direct_target_graph advisory_review], 'adoption_authorized' => false }
    rescue KeyError, TypeError, NoMethodError, ArgumentError
      raise Failure, 'Malformed advisory receipt'
    end
  end
end
