# frozen_string_literal: true

require_relative 'core'
require_relative 'run_store'
require_relative '../adapters/kotlin_watch'
require 'cgi'
require 'rubygems/version'
require 'rexml/document'

module Maintenance
  # Acquisition and interpretation are separate. Upstream bodies are evidence,
  # never shell commands, executable plans, approvals or retirement instructions.
  class AssessmentHTTP
    HOSTS = %w[api.github.com kotlinlang.org youtrack.jetbrains.com api.osv.dev packages.jetbrains.team repo.maven.apache.org maven-central.storage-download.googleapis.com dl.google.com].freeze
    MAX_BYTES = 8 * 1024 * 1024
    attr_reader :receipts, :requests, :failures

    def initialize(output, token: nil, max_requests: 128, seconds: 2700, transport: nil)
      @output, @token, @max_requests = output, token, max_requests
      @deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
      @transport = transport || method(:request)
      @receipts, @requests, @cache, @failures, @backoff = [], 0, {}, [], {}
    end

    def remaining_seconds
      [@deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC), 0].max
    end

    def request(url, payload = nil)
      uri = URI(url)
      headers = ['Accept: application/vnd.github+json', 'User-Agent: Mobi-Release-Assessment']
      if uri.host == 'api.github.com' && @token && !@token.empty?
        raise Failure, 'Invalid assessment credential format' unless @token.match?(/\A[!-~]+\z/)
        headers << 'Authorization: Bearer ' + @token
      end
      headers << 'Content-Type: application/json' if payload
      extra = payload ? ['--data-binary', JSON.generate(payload)] : []
      remaining = @deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
      raise Failure, 'provider_deadline' unless remaining.positive?
      out = nil; status = nil; response_headers = ''
      Dir.mktmpdir('transport-', @output) do |temp|
        header_file = File.join(temp, 'headers')
        out, _err, status = Open3.capture3({ 'PATH' => '/usr/bin:/bin', 'LC_ALL' => 'C' }, '/usr/bin/curl', '--disable',
          '--proto', '=https', '--tlsv1.2', '--silent', '--show-error', '--connect-timeout', [remaining, 10].min.to_s, '--max-time', [remaining, 30].min.to_s,
          '--max-filesize', MAX_BYTES.to_s, '--header', '@-', '--dump-header', header_file, '--write-out', "\n%{http_code}", *extra, url,
          stdin_data: headers.join("\n") + "\n", unsetenv_others: true)
        response_headers = File.binread(header_file, 64 * 1024) if File.file?(header_file)
      end
      raise Failure, 'provider_network_failure' unless status.success?
      body, _, code = out.rpartition("\n")
      retry_after = response_headers[/^Retry-After:\s*([^\r\n]+)/i, 1]
      if retry_after
        begin
          @backoff[uri.host] = retry_after.match?(/\A\d+\z/) ? Time.now.utc + retry_after.to_i : Time.httpdate(retry_after)
        rescue ArgumentError
          @backoff[uri.host] = Time.now.utc + 60
        end
      elsif code == '429'
        @backoff[uri.host] = Time.now.utc + 60
      end
      raise Failure, 'provider_http_' + code unless code == '200'
      body
    end

    def get(url, json: true)
      body = fetch(url)
      json ? JSON.parse(body) : body
    rescue JSON::ParserError
      raise Failure, 'provider_malformed_json'
    end

    def packet(url, payload)
      body = fetch(url, payload)
      { 'url' => url, 'request' => payload, 'body' => body, 'status' => 200,
        'retrieved_at' => @receipts.find { |r| r['url'] == url && r['request_sha256'] == Maintenance.digest(payload) }.fetch('retrieved_at'),
        'response_sha256' => Digest::SHA256.hexdigest(body) }
    end

    def fetch(url, payload = nil)
      uri = URI(url)
      raise Failure, 'Unsupported assessment URL' unless uri.scheme == 'https' && HOSTS.include?(uri.host) && !uri.userinfo && !uri.fragment && [nil, 443].include?(uri.port)
      key = [url, Maintenance.digest(payload)]
      return @cache.fetch(key) if @cache.key?(key)
      raise Failure, 'provider_retry_after_active' if @backoff[uri.host] && @backoff[uri.host] > Time.now.utc
      raise Failure, 'provider_request_budget' if @requests >= @max_requests
      raise Failure, 'provider_deadline' if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= @deadline
      @requests += 1
      body = payload ? @transport.call(url, payload) : @transport.call(url)
      raise Failure, 'provider_response_size' unless body.is_a?(String) && body.bytesize <= MAX_BYTES
      sha = Digest::SHA256.hexdigest(body)
      File.binwrite(File.join(@output, sha + '.body'), body)
      @receipts << { 'url' => url, 'retrieved_at' => Time.now.utc.iso8601, 'sha256' => sha, 'bytes' => body.bytesize, 'request_sha256' => Maintenance.digest(payload),
        'transport_sha256' => Maintenance.file_sha('/usr/bin/curl') }
      @cache[key] = body
      body
    rescue URI::InvalidURIError, JSON::ParserError => error
      raise Failure, 'provider_malformed_' + error.class.name.split('::').last
    rescue Failure => error
      failed_url = uri && uri.dup
      if failed_url
        failed_url.user = nil; failed_url.password = nil; failed_url.query = nil; failed_url.fragment = nil
      end
      @failures << { 'url' => failed_url&.to_s, 'url_sha256' => Digest::SHA256.hexdigest(url), 'request_sha256' => Maintenance.digest(payload),
        'retrieved_at' => Time.now.utc.iso8601, 'reason' => error.message,
        'retry_after' => uri && @backoff[uri.host]&.iso8601 }
      raise
    end
  end

  module AssessmentCatalog
    VERSION = /\A\d+\.\d+\.\d+(?:-[0-9A-Za-z]+(?:[.\-][0-9A-Za-z]+)*)?\z/
    MAX_MAVEN_VERSIONS = 4000
    module_function

    def version(tag)
      text = tag.to_s.delete_prefix('v')
      raise Failure, 'unrecognized_release_tag' unless text.length <= 120 && text.match?(VERSION)
      text
    end

    # Walk the whole bounded catalog: release creation order is not version order.
    # Stopping at the first older record can silently lose backported/prereleases.
    def collect(http, repository, baseline, now: Time.now.utc, pages: 4)
      rows = []; complete = false; gaps = []
      pages.times do |index|
        page = http.get("https://api.github.com/repos/#{repository}/releases?per_page=100&page=#{index + 1}")
        raise Failure, 'invalid_release_page' unless page.is_a?(Array) && page.size <= 100
        rows.concat(page)
        if page.size < 100
          complete = true
          break
        end
      end
      gaps << 'release_catalog_page_limit' unless complete
      baseline_version = Gem::Version.new(version(baseline).downcase)
      releases = rows.filter_map do |row|
        raise Failure, 'invalid_release_record' unless row.is_a?(Hash) && [true, false].include?(row['draft']) && [true, false].include?(row['prerelease'])
        next if row['draft']
        begin
          value = version(row.fetch('tag_name'))
          published = Time.iso8601(row.fetch('published_at'))
          raise Failure, 'future_release_date' if published > now
          next unless Gem::Version.new(value.downcase) > baseline_version
          raise Failure, 'missing_release_notes' unless row['body'].is_a?(String) && !row['body'].strip.empty?
          { 'version' => value, 'tag' => row['tag_name'], 'published_at' => published.utc.iso8601,
            'channel' => row['prerelease'] || value.include?('-') ? 'prerelease' : 'stable',
            'url' => row.fetch('html_url'), 'notes_sha256' => Digest::SHA256.hexdigest(row['body']) }
        rescue Failure, KeyError, ArgumentError, TypeError
          gaps << 'unreadable_release_record'
          nil
        end
      end
      baseline_row = rows.find { |r| r['tag_name'].to_s.delete_prefix('v').downcase == baseline.downcase }
      gaps << 'baseline_release_tag_unavailable' unless baseline_row
      { 'state' => gaps.empty? ? 'collected' : 'incomplete', 'baseline' => baseline, 'baseline_tag' => baseline_row && baseline_row['tag_name'], 'baseline_published_at' => baseline_row && baseline_row['published_at'], 'repository' => repository,
        'releases' => releases.uniq { |r| r['tag'] }.sort_by { |r| Gem::Version.new(r['version'].downcase) }, 'gaps' => gaps.uniq }
    rescue Failure, KeyError, ArgumentError, TypeError => error
      { 'state' => 'incomplete', 'baseline' => baseline, 'repository' => repository, 'releases' => [], 'gaps' => [error.message] }
    end

    def commit(http, repository, tag)
      data = http.get("https://api.github.com/repos/#{repository}/commits/#{CGI.escape(tag)}")
      sha = data.fetch('sha')
      raise Failure, 'invalid_release_commit' unless sha.is_a?(String) && sha.match?(/\A[0-9a-f]{40}\z/)
      sha
    end

    # Releases omit unpublished-to-GitHub prereleases. Cross-check official tags
    # and the actual Maven coordinates; absent notes/dates remain blockers,
    # rather than being invented from tag order or an artifact's fetch time.
    def channels(http, repository, baseline, catalog, maven: [])
      known = catalog.fetch('releases').to_h { |row| [row['version'].downcase, row] }
      lower = Gem::Version.new(version(baseline).downcase)
      gaps = catalog.fetch('gaps').dup
      references = []
      complete = false
      4.times do |page|
        rows = http.get("https://api.github.com/repos/#{repository}/tags?per_page=100&page=#{page + 1}")
        raise Failure, 'invalid_tag_page' unless rows.is_a?(Array) && rows.size <= 100
        rows.each do |tag|
          raise Failure, 'invalid_tag_record' unless tag.is_a?(Hash) && tag['name'].is_a?(String)
          begin
            value = version(tag['name'])
          rescue Failure
            gaps << 'unrecognized_tag_catalog_entry'
            next
          end
          next unless Gem::Version.new(value.downcase) > lower
          next if known.key?(value.downcase)
          sha = tag.dig('commit', 'sha')
          raise Failure, 'invalid_tag_commit' unless sha.is_a?(String) && sha.match?(/\A[0-9a-f]{40}\z/)
          known[value.downcase] = { 'version' => value, 'tag' => tag['name'], 'candidate_commit' => sha,
            'channel' => value.include?('-') ? 'prerelease' : 'stable', 'published_at' => nil,
            'url' => "https://github.com/#{repository}/tree/#{sha}", 'gaps' => ['official_release_notes_and_publication_date_unavailable'] }
        end
        if rows.size < 100
          complete = true; break
        end
      end
      gaps << 'tag_catalog_page_limit' unless complete
      maven.each do |spec|
        coordinate = spec.is_a?(Hash) ? spec.fetch('coordinate') : spec
        group, artifact = coordinate.split(':', 2)
        root = (spec.is_a?(Hash) ? spec.fetch('registry') : ENV.fetch('KOTLIN_DEFAULT_MAVEN_CENTRAL_URL', 'https://repo.maven.apache.org/maven2')).delete_suffix('/')
        url = root + '/' + group.tr('.', '/') + '/' + artifact + '/maven-metadata.xml'
        body = http.get(url, json: false)
        raise Failure, 'unsafe_maven_metadata_document' if body.match?(/<!DOCTYPE|<!ENTITY/i)
        document = REXML::Document.new(body)
        raise Failure, 'maven_metadata_coordinate_mismatch' unless document.elements['metadata/groupId']&.text == group && document.elements['metadata/artifactId']&.text == artifact
        versions = document.get_elements('metadata/versioning/versions/version').map(&:text)
        raise Failure, 'missing_maven_versions' if versions.empty?
        gaps << 'maven_version_count_limit' if versions.size > MAX_MAVEN_VERSIONS
        references << { 'coordinate' => coordinate, 'url' => url, 'sha256' => Digest::SHA256.hexdigest(body) }
        versions.take(MAX_MAVEN_VERSIONS).each do |text|
          value = version(text)
          next unless Gem::Version.new(value.downcase) > lower
          key = value.downcase
          if known[key]
            (known[key]['maven_coordinates'] ||= []) << coordinate
          else
            known[key] = { 'version' => value, 'tag' => nil, 'channel' => value.include?('-') ? 'prerelease' : 'stable',
              'published_at' => nil, 'url' => url, 'maven_coordinates' => [coordinate],
              'gaps' => ['maven_version_official_release_tag_notes_and_date_unavailable'] }
          end
        end
      end
      catalog.merge('state' => gaps.empty? ? 'collected' : 'incomplete', 'gaps' => gaps.uniq,
        'maven_metadata' => references, 'channels_cross_checked' => true,
        'releases' => known.values.sort_by { |row| Gem::Version.new(row['version'].downcase) })
    rescue Failure, KeyError, TypeError, ArgumentError, NoMethodError, REXML::ParseException => error
      catalog.merge('state' => 'incomplete', 'gaps' => (gaps + [error.is_a?(Failure) ? error.message : 'malformed_channel_catalog']).uniq,
        'maven_metadata' => references, 'channels_cross_checked' => false,
        'releases' => known.values.sort_by { |row| Gem::Version.new(row['version'].downcase) })
    end

    def interval(http, repository, baseline, release, git_fallback: nil)
      before = commit(http, repository, baseline)
      after = commit(http, repository, release.fetch('tag'))
      data = http.get("https://api.github.com/repos/#{repository}/compare/#{before}...#{after}")
      files = data.fetch('files')
      raise Failure, 'invalid_source_interval' unless files.is_a?(Array) && files.all? { |f| f.is_a?(Hash) && f['filename'].is_a?(String) }
      gaps = []
      gaps << 'source_interval_file_limit' if files.size >= 300
      gaps << 'source_interval_diverged' unless %w[ahead identical].include?(data['status']) && data.dig('base_commit', 'sha') == before && data.dig('merge_base_commit', 'sha') == before
      gaps << 'source_interval_patch_missing' if files.any? { |f| !f['patch'].is_a?(String) }
      if !gaps.empty? && git_fallback
        result = git_fallback.call(repository, before, after, seconds: [http.remaining_seconds, 120].min)
        result['api_fallback_reasons'] = gaps
        if result['state'] != 'collected'
          result['files'] = files if result['files'].empty?
          result['gaps'] = (gaps + result['gaps']).uniq
        end
        return result
      end
      { 'state' => gaps.empty? ? 'collected' : 'incomplete', 'baseline_commit' => before, 'candidate_commit' => after,
        'files' => files, 'gaps' => gaps }
    rescue Failure, KeyError, TypeError => error
      { 'state' => 'incomplete', 'files' => [], 'gaps' => [error.message] }
    end
  end

  module AssessmentImpact
    DECLARATION = /\b(?:fun|func|class|struct|interface|protocol|enum|typealias|object|val|var)\s+([A-Za-z_][A-Za-z0-9_]*)/
    EFFECT = /\b(?:async|await|suspend|cancel|cancellation|CoroutineScope|Flow|Task|MainActor|nonisolated|Sendable|preconcurrency|withContext|Dispatchers|Clock|Timer)\b/i
    module_function

    def analyze(root, source, name, interval)
      changed = interval.fetch('files')
      # This model extracts explicit API/configuration/effect changes and their
      # actual consumers. It does not infer semantic equivalence or retirement.
      facts = changed.map do |file|
        path = file.fetch('filename')
        patch = file['patch'].is_a?(String) ? file['patch'] : ''
        lines = patch.lines
        removed = lines.grep(/\A-(?!-)/).map { |line| line[1..] }.join
        added = lines.grep(/\A\+(?!\+)/).map { |line| line[1..] }.join
        before = removed.scan(DECLARATION).flatten.uniq
        after = added.scan(DECLARATION).flatten.uniq
        kind = if path.match?(/\.(?:png|jpe?g|gif|svg|webp|ico|woff2?|pdf)\z/i)
                 'package_or_documentation_resource'
               elsif path.match?(%r{(?:^|/)(?:tests?|test-integration|__tests__)/}i) || path.match?(/Tests?\.(?:swift|kt|java)\z/)
                 'test'
               elsif path.match?(/\.(?:md|rst|adoc|txt)\z/i) || path.match?(%r{(?:^|/)(?:LICENSE|NOTICE)(?:[-.]|$)})
                 'documentation'
               elsif path.match?(/\.(?:swift|kt|java|c|cpp|h|m|mm)\z/) && !path.end_with?('Package.swift')
                 'runtime_source'
               elsif path.match?(/(?:Package\.swift|\.(?:yaml|yml|json|toml|xml|properties|kts|gradle|sh|rb|bat|resolved|pbxproj|xcscheme|xctestplan|xcconfig|plist|podspec|lock))\z/) || path.start_with?('.github/') || %w[.editorconfig .gitattributes .gitignore .gitmodules].include?(File.basename(path))
                 'build_or_dependency_configuration'
               else
                 'unsupported_change_format'
               end
        { 'path' => path, 'kind' => kind, 'status' => file['status'],
          'removed_declarations' => before - after, 'added_declarations' => after - before,
          'modified_declarations' => before & after,
          'effect_changes' => (removed + added).scan(EFFECT).map(&:downcase).uniq.sort,
          'patch_sha256' => Digest::SHA256.hexdigest(patch) }
      end
      tokens = facts.flat_map { |f| f.values_at('removed_declarations', 'added_declarations', 'modified_declarations').flatten }.uniq
      # Type-only matching misses lowercase functions; include all changed API
      # declarations, then type references for implementation-only changes.
      tokens += changed.flat_map { |f| (f['patch'].is_a?(String) ? f['patch'] : '').scan(/\b[A-Z][A-Za-z0-9_]{4,79}\b/) }
      tokens = tokens.uniq.sort
      gaps = interval.fetch('gaps', []).dup
      paths = source.files.keys.select do |path|
        path.match?(%r{\A(?:shared-[^/]+|android-app|ios-app|tools/swift-export)/}) && path.match?(/\.(?:kt|swift|yaml|json)\z/)
      end
      actual_symbols = paths.to_h do |path|
        [path, File.read(File.join(root, path)).scan(/\b[A-Za-z_][A-Za-z0-9_]*\b/).uniq]
      end
      # Bound relevant matches after intersecting actual consumers. Alphabetical
      # truncation of upstream-only symbols can hide the app's only real caller.
      tokens &= actual_symbols.values.flatten.uniq
      gaps << 'source_symbol_limit' if tokens.size > 1000
      tokens = tokens.take(1000)
      mappings = paths.filter_map do |path|
        matched = tokens & actual_symbols.fetch(path)
        next if matched.empty?
        { 'path' => path, 'symbols' => matched, 'sha256' => source.files.fetch(path).fetch('sha256') }
      end
      consumed = mappings.flat_map { |m| m['symbols'] }.uniq
      findings = facts.filter_map do |fact|
        next unless fact['kind'] == 'runtime_source' || fact['kind'] == 'build_or_dependency_configuration'
        removed_consumed = fact['removed_declarations'] & consumed
        { 'upstream_path' => fact['path'],
          'risk' => removed_consumed.empty? ? 'behavior_or_integration_change' : 'possible_consumed_api_removed_or_renamed',
          'consumed_removed_symbols' => removed_consumed, 'effect_changes' => fact['effect_changes'],
          'qualification' => %w[android-test ios-test android-build-debug ios-build-debug] }
      end
      gaps << 'unsupported_source_change_format' if facts.any? { |f| f['kind'] == 'unsupported_change_format' }
      gaps << 'missing_source_patch' if changed.any? { |f| !f['patch'].is_a?(String) && f['binary'] != true }
      gaps << 'opaque_runtime_binary_change' if changed.any? { |f| f['binary'] && f['filename'].match?(/\.(?:jar|klib|a|dylib)\z/) }
      gaps << 'source_interval_incomplete' unless interval['state'] == 'collected'
      registry = JSON.parse(File.read(File.join(root, InteropWorkarounds::REGISTRY)))
      workarounds = registry.fetch('entries').select { |entry| entry.fetch('recheck_on').include?(name) }.map do |entry|
        entry.slice('id', 'disposition', 'replacement', 'retirement_checks', 'paths')
      end
      { 'state' => gaps.empty? ? 'complete' : 'incomplete', 'model' => 'declaration_effect_configuration_usage_v1',
        'changed_files' => facts, 'actual_source_matches' => mappings, 'findings' => findings, 'workarounds' => workarounds,
        'semantic_equivalence' => 'not_claimed', 'retirement_authorized' => false,
        'limitations' => %w[private_behavior_beyond_selected_native_tests unexercised_platform_behavior symbol_owner_resolution_not_proven no_retirement_proof], 'gaps' => gaps.uniq }
    end
  end

  module AssessmentConstraints
    module_function

    def evaluate(root, name, baseline, candidate)
      names, datasource = case name
                          when 'metro' then [%w[dev.zacsweers.metro:runtime dev.zacsweers.metro:compiler], 'maven']
                          when 'kotlin' then [['org.jetbrains.kotlin:swift-export-embeddable'], 'maven']
                          when 'toolchain' then [['JetBrains/kotlin-toolchain'], 'github-releases']
                          else
                            identity = ReleaseWatch::SWIFT_PACKAGES[name]
                            [[identity && 'pointfreeco/' + identity].compact, 'git-tags']
                          end
      path = File.join(root, 'renovate.json')
      return { 'state' => 'complete', 'constraints' => [], 'decisions_required' => [], 'gaps' => [] } unless File.file?(path)
      config = JSON.parse(File.read(path))
      rows = []; gaps = []
      config.fetch('packageRules', []).each do |rule|
        next unless rule['allowedVersions']
        next if rule['matchDatasources'] && !rule['matchDatasources'].include?(datasource)
        matched = names.any? do |package|
          rule.fetch('matchPackageNames', []).any? do |pattern|
            pattern.start_with?('/') && pattern.end_with?('/') ? Regexp.new(pattern[1...-1]).match?(package) : pattern == package
          end
        end
        next unless matched
        if (rule.keys - %w[description matchDatasources matchPackageNames allowedVersions]).any?
          gaps << 'conditional_renovate_ceiling_unsupported'; next
        end
        bound = rule['allowedVersions'].match(/\A(<=|>=|<|>|=)?(\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?)\z/)
        unless bound
          gaps << 'renovate_ceiling_syntax_unsupported'; next
        end
        allowed = lambda do |version|
          comparison = Gem::Version.new(version.downcase) <=> Gem::Version.new(bound[2].downcase)
          case bound[1] || '='
          when '<=' then comparison <= 0
          when '>=' then comparison >= 0
          when '<' then comparison < 0
          when '>' then comparison > 0
          else comparison == 0
          end
        end
        rows << { 'ceiling' => rule['allowedVersions'], 'baseline_allowed' => allowed.call(baseline), 'candidate_allowed' => allowed.call(candidate) }
      end
      decisions = rows.filter_map do |row|
        next if row['candidate_allowed']
        row['baseline_allowed'] ? 'candidate_exceeds_reviewed_ceiling' : 'adopted_tuple_already_exceeds_ceiling'
      end
      { 'state' => gaps.empty? ? 'complete' : 'incomplete', 'constraints' => rows, 'decisions_required' => decisions.uniq, 'gaps' => gaps.uniq,
        'source' => 'renovate.json', 'sha256' => Maintenance.file_sha(path), 'policy_changed' => false }
    rescue RegexpError, KeyError, TypeError, ArgumentError, JSON::ParserError
      { 'state' => 'incomplete', 'gaps' => ['malformed_dependency_constraints'], 'policy_changed' => false }
    end
  end

  module AssessmentDecision
    REQUIRED = %w[upstream impact constraints qualification security cleanup evidence].freeze
    module_function

    def next_slices(row)
      stages = row.fetch('stages')
      slices = []
      baseline = stages.dig('qualification', 'baseline')
      if baseline && baseline != 'passed'
        failed = baseline == 'failed'
        slices << { 'action' => failed ? 'repair_adopted_baseline_before_comparison' : 'repair_baseline_qualification_prerequisites',
          'code' => failed ? ['scripts/ci/run_job.sh'] : ['scripts/maintenance/assessment_check.rb', 'scripts/dev/test_contracts.rb'], 'candidate_regression_established' => false }
      end
      if stages.dig('upstream', 'state') == 'incomplete'
        slices << { 'action' => 'extend_bounded_official_evidence_acquisition', 'code' => ['scripts/maintenance/lib/release_assessment.rb', 'scripts/maintenance/lib/assessment_authorities.rb'], 'gaps' => stages['upstream']['gaps'] }
      end
      if stages.dig('impact', 'state') == 'incomplete'
        paths = stages['impact'].fetch('changed_files', []).select { |file| file['kind'] == 'unsupported_change_format' }.map { |file| file['path'] }
        slices << { 'action' => 'extend_supported_source_analysis', 'code' => ['scripts/maintenance/lib/release_assessment.rb'], 'unsupported_upstream_paths' => paths.take(10) }
      end
      if stages.dig('security', 'state') == 'incomplete'
        slices << { 'action' => 'establish_missing_selected_input_provenance_and_provider_coverage',
          'code' => ['scripts/maintenance/assessment_provenance.py', 'scripts/maintenance/lib/build_inputs.rb', 'scripts/maintenance/lib/assessment_security.rb'], 'gaps' => stages['security']['gaps'] }
      end
      unless Array(stages.dig('constraints', 'decisions_required')).empty?
        slices << { 'action' => 'resolve_recorded_dependency_ceiling_inconsistency', 'code' => ['renovate.json'], 'decisions' => stages['constraints']['decisions_required'], 'policy_change_authorized' => false }
      end
      slices
    end

    def evaluate(stages, age_eligible:, source_verified:, channel: 'stable')
      gaps = REQUIRED.filter_map { |key| key unless stages.dig(key, 'state') == 'complete' }
      gaps << 'source_drift' unless source_verified
      baseline = stages.dig('qualification', 'baseline')
      if baseline && baseline != 'passed'
        recommendation = 'incomplete'; reason = 'baseline_inconclusive'
      elsif stages.dig('qualification', 'candidate') == 'failed' && stages.dig('qualification', 'baseline') == 'passed'
        recommendation = 'reject'; reason = 'candidate_qualification_failed'
      elsif !gaps.empty?
        recommendation = 'incomplete'; reason = 'required_evidence_missing'
      elsif !age_eligible
        recommendation = 'defer'; reason = 'release_age_blocked'
      elsif channel != 'stable'
        recommendation = 'defer'; reason = 'prerelease_adoption_requires_decision'
      elsif Array(stages.dig('constraints', 'decisions_required')).any?
        recommendation = 'defer'; reason = 'dependency_ceiling_decision_required'
      elsif stages.dig('security', 'blocking_findings') != []
        recommendation = 'defer'; reason = 'security_decision_required'
      else
        recommendation = 'adopt'; reason = 'exact_packet_ready_for_human_approval'
      end
      { 'recommendation' => recommendation, 'reason' => reason, 'missing_stages' => gaps,
        'adoption_authorized' => false, 'pr_creation_authorized' => false, 'retirement_authorized' => false }
    end
  end
end
