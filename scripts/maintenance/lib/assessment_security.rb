# frozen_string_literal: true

require_relative 'advisory_review'
require_relative 'upgrade_graph'
require_relative 'build_inputs'

module Maintenance
  module AssessmentSecurity
    module_function

    def queries(graphs, provenance)
      queries = UpgradeGraph.toolchain_queries(graphs).fetch('queries')
      origins = queries.to_h { |query| [Maintenance.digest(query), ['module_resolution']] }
      gaps = provenance.fetch('gaps', []).dup
      gaps << 'non_jar_downloaded_artifact_owner_provenance_unassigned' unless provenance.fetch('uninspected_downloaded_artifact_kinds', {}).empty?
      owners = provenance.fetch('owner_inputs', {})
      if owners['state'] == 'collected'
        owners.fetch('delegated_graphs').each do |packet|
          conditions = packet.fetch('data')['jetifier_conditions']
          unless conditions.is_a?(Hash) && conditions.dig('transforms', 'state') == 'observed' && Array(conditions['projects']).all? { |project| project['state'] == 'collected' }
            gaps << 'delegated_transform_or_agp_conditions_unproven'
          end
          BuildInputs.delegated!(packet.fetch('data')).each do |scope|
            gaps << 'delegated_uncollected_configurations' if scope['state'] == 'not_collected'
            Array(scope['nodes']).each do |node|
              component = node.fetch('component')
              next unless component['kind'] == 'maven'
              query = { 'package' => { 'ecosystem' => 'Maven', 'name' => component['group'] + ':' + component['name'] }, 'version' => component['version'] }
              queries << query
              (origins[Maintenance.digest(query)] ||= []) << 'observed_delegated_configuration'
            end
          end
        end
      else
        gaps += Array(owners['gaps']) + ['selected_compiler_and_delegated_producer_unavailable']
      end
      archives = provenance.fetch('archives', [])
      claims = []
      archives.each do |archive|
        if archive.fetch('metadata').size == 1 && archive.fetch('gaps').empty?
          claims << { 'component' => archive['metadata'].first.fetch('component'), 'identity' => archive.fetch('identity') }
        end
        archive.fetch('metadata').each do |metadata|
          component = metadata.fetch('component')
          UpgradeGraph.component!(component.merge('kind' => 'maven'))
          query = { 'package' => { 'ecosystem' => 'Maven', 'name' => component['group'] + ':' + component['name'] }, 'version' => component['version'] }
          queries << query
          (origins[Maintenance.digest(query)] ||= []) << 'embedded_archive_claim'
        end
        gaps << 'unassigned_archive_metadata' unless archive.fetch('gaps').empty?
      end
      locks = provenance.fetch('swift_locks', {})
      gaps << 'swift_lock_graph_unavailable' if locks.empty?
      swift = {}
      locks.each_value do |lock|
        lock.fetch('pins').each do |pin|
          uri = URI(pin.fetch('location'))
          revision = pin.fetch('state').fetch('revision')
          unless pin['kind'] == 'remoteSourceControl' && uri.scheme == 'https' && !uri.userinfo && uri.host == 'github.com' && uri.path.match?(%r{\A/[^/]+/[^/]+(?:\.git)?\z}) && revision.match?(/\A[0-9a-f]{40}\z/)
            gaps << 'unsupported_swift_pin_provenance'
            next
          end
          identity = [pin.fetch('identity'), uri.to_s.sub(/\.git$/, '')]
          gaps << 'conflicting_swift_locked_revisions' if swift[identity] && swift[identity] != revision
          swift[identity] = revision
          query = { 'commit' => revision }
          queries << query
          (origins[Maintenance.digest(query)] ||= []) << 'swift_locked_commit'
        end
      end
      gaps << 'selected_build_owner_classpaths_unproven' unless provenance['selected_classpath_proven'] == true
      gaps << 'embedded_claims_need_independent_byte_attribution' if archives.any? { |archive| !archive['metadata'].empty? } && provenance['identity_authority'] != 'independent_byte_references'
      { 'queries' => queries.uniq.sort_by { |query| JSON.generate(query) }, 'origins' => origins.transform_values { |value| value.uniq.sort },
        'gaps' => gaps.uniq.sort, 'archive_claims' => claims.uniq, 'downloaded_archive_count' => archives.size, 'swift_locked_package_count' => swift.size,
        'observed_owner_inputs' => owners.slice('state', 'compiler_version', 'complete_target_graph').merge('selected_plugin_count' => owners.fetch('selected_plugin_artifacts', {}).size) }
    rescue KeyError, TypeError, NoMethodError, URI::InvalidURIError
      raise Failure, 'Malformed assessment security provenance'
    end

    def byte_references(http, claims)
      root = ENV.fetch('KOTLIN_DEFAULT_MAVEN_CENTRAL_URL', 'https://repo.maven.apache.org/maven2').delete_suffix('/')
      claims = claims.uniq
      rows = claims.take(32).map do |claim|
        component = claim.fetch('component'); UpgradeGraph.component!(component.merge('kind' => 'maven'))
        raise Failure, 'unsafe_maven_reference_coordinate' if component.values.any? { |value| %w[. ..].include?(value) }
        registry = component['group'].start_with?('androidx.', 'com.android.') ? 'https://dl.google.com/dl/android/maven2' : root
        path = component['group'].tr('.', '/') + '/' + component['name'] + '/' + component['version'] + '/' + component['name'] + '-' + component['version'] + '.jar.sha256'
        url = registry + '/' + path
        begin
          body = http.get(url, json: false)
          checksum = body.strip[/\A([0-9a-fA-F]{64})(?:\s+[^\r\n]+)?\z/, 1]
          raise Failure, 'published_maven_checksum_missing' unless checksum
          matches = checksum.downcase == claim.fetch('identity').fetch('sha256')
          { 'component' => component, 'identity' => claim['identity'], 'url' => url,
            'state' => matches ? 'published_checksum_matches' : 'published_bytes_differ', 'reference_sha256' => checksum.downcase }
        rescue Failure => error
          { 'component' => component, 'identity' => claim['identity'], 'url' => url, 'state' => 'incomplete', 'reason' => error.message }
        end
      end
      { 'scope' => 'primary_published_maven_checksums_for_unambiguous_embedded_claims', 'references' => rows,
        'gaps' => ((claims.size > 32 ? ['maven_reference_budget'] : []) +
          (rows.any? { |row| row['state'] != 'published_checksum_matches' } ? ['unverified_maven_reference_bytes'] : []) +
          rows.filter_map { |row| row['reason'] }).uniq,
        'selected_classpath_proven' => false }
    end

    def finding_delta(summaries)
      before = summaries.fetch('baseline').fetch('findings').map { |finding| finding.fetch('id') }.uniq.sort
      after = summaries.fetch('candidate').fetch('findings').map { |finding| finding.fetch('id') }.uniq.sort
      complete = %w[baseline candidate].all? { |phase| summaries.fetch(phase)['state'] == 'provider_complete' }
      # A budget/provider gap can hide a record on either side. Absence from a
      # partial result cannot establish a resolution or a newly introduced ID.
      { 'state' => complete ? 'complete' : 'incomplete',
        'introduced_ids' => complete ? after - before : [], 'resolved_ids' => complete ? before - after : [],
        'retained_ids' => before & after,
        'observed_baseline_only_ids' => before - after, 'observed_candidate_only_ids' => after - before }
    end

    def collect(http, inputs, now: nil)
      collect_phases(http, { 'single' => inputs }, now: now).fetch('single')
    end

    def collect_pair(http, inputs, now: nil)
      raise Failure, 'Expected baseline and candidate security phases' unless
        inputs.is_a?(Hash) && inputs.size == 2 && %w[baseline candidate].all? { |phase| inputs.key?(phase) }
      collect_phases(http, %w[baseline candidate].to_h { |phase| [phase, inputs.fetch(phase)] }, now: now)
    end

    def collect_phases(http, inputs, now:)
      # Complete both query sets before optional byte-reference requests can
      # consume the shared budget. Keep the original per-phase batch packets.
      pending = inputs.transform_values { |input| query_receipt(http, input, now: now) }
      records = pending.values.flat_map { |_receipt, ids| ids.keys }.uniq.sort.to_h do |id|
        [id, finding_record(http, id, now: now)]
      end
      pending.each do |_phase, (receipt, ids)|
        ids.sort.each do |id, matched|
          record = records.fetch(id)
          receipt['records'] << record['packet'] if record['packet']
          receipt['reasons'].concat(record.fetch('errors'))
          receipt['findings'] << record.fetch('finding').merge('queries' => matched.uniq) if record['errors'].empty?
        end
        receipt['reasons'] << 'finding_record_coverage_incomplete' unless receipt['findings'].map { |row| row['id'] }.sort == ids.keys.sort
        receipt['advisory_state'] = receipt['reasons'].empty? ? 'complete' : 'incomplete'
      end
      # Every phase now has an advisory result, even if a checksum budget or
      # provider failure leaves the broader provenance assessment incomplete.
      pending.to_h do |phase, (receipt, _ids)|
        receipt['byte_references'] = byte_references(http, inputs.fetch(phase).fetch('archive_claims', []))
        receipt['reasons'].concat(receipt['byte_references']['gaps'])
        receipt['reasons'] = receipt['reasons'].uniq.sort
        receipt['state'] = receipt['reasons'].empty? ? 'provider_complete' : 'incomplete'
        [phase, receipt]
      end
    end

    def query_receipt(http, inputs, now:)
      queries = inputs.fetch('queries')
      raise Failure, 'Empty assessment security query set' if queries.empty?
      receipt = { 'schema' => 1, 'created_at' => (now || Time.now.utc).iso8601, 'queries' => queries, 'queries_sha256' => Maintenance.digest(queries),
        'origins' => inputs.fetch('origins'), 'batches' => [], 'records' => [], 'findings' => [], 'reasons' => [], 'adoption_authorized' => false }
      ids = {}
      queries.each_slice(100) do |batch|
        begin
          packet = http.packet(AdvisoryReview::API + 'querybatch', { 'queries' => batch })
          receipt['batches'] << packet
          data, errors = AdvisoryReview.packet(packet, AdvisoryReview::API + 'querybatch', { 'queries' => batch }, now || Time.now.utc)
          receipt['reasons'].concat(errors)
          next unless errors.empty?
          rows = data.fetch('results')
          unless rows.is_a?(Array) && rows.size == batch.size
            receipt['reasons'] << 'response_cardinality_mismatch'; next
          end
          rows.each_with_index do |row, index|
            unless row.is_a?(Hash) && (!row.key?('vulns') || row['vulns'].is_a?(Array))
              receipt['reasons'] << 'malformed_query_result'; next
            end
            receipt['reasons'] << 'pagination_incomplete' if row['next_page_token'] && row['next_page_token'] != ''
            row.fetch('vulns', []).each do |vulnerability|
              id = vulnerability['id']
              unless id.is_a?(String) && id.match?(AdvisoryReview::ID)
                receipt['reasons'] << 'malformed_finding'; next
              end
              (ids[id] ||= []) << batch[index]
            end
          end
        rescue Failure, KeyError, TypeError => error
          receipt['reasons'] << (error.is_a?(Failure) ? error.message : 'malformed_provider_response')
        end
      end
      [receipt, ids]
    end

    def finding_record(http, id, now:)
      packet = http.packet(AdvisoryReview::API + 'vulns/' + id, nil)
      data, errors = AdvisoryReview.packet(packet, AdvisoryReview::API + 'vulns/' + id, nil, now || Time.now.utc)
      return { 'packet' => packet, 'errors' => errors } unless errors.empty?
      unless data['id'] == id && data['affected'].is_a?(Array) && !data['affected'].empty? && data['modified'].is_a?(String)
        return { 'packet' => packet, 'errors' => ['finding_record_mismatch'] }
      end
      severity = data.dig('database_specific', 'severity').to_s.downcase
      severity = 'unknown' unless %w[low moderate medium high critical].include?(severity)
      { 'packet' => packet, 'errors' => [], 'finding' => { 'id' => id, 'severity' => severity,
        'exploitation_or_runtime_reachability' => 'not_established' } }
    rescue Failure, KeyError, TypeError => error
      { 'packet' => packet, 'errors' => [error.is_a?(Failure) ? error.message : 'malformed_finding_record'] }
    end
  end
end
