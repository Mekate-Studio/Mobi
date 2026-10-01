# frozen_string_literal: true

require_relative '../lib/watch'
require_relative '../lib/compatibility_report'
require 'rubygems/version'

module Maintenance
  class KotlinReleaseWatch
    REPOSITORIES = { 'toolchain' => 'JetBrains/kotlin-toolchain', 'kotlin' => 'JetBrains/kotlin', 'metro' => 'ZacSweers/metro', 'skie' => 'touchlab/SKIE' }.freeze

    def initialize(fetcher: WatchHTTP.new, now: Time.now.utc, token: nil)
      @fetcher, @now, @token = fetcher, now, token
    end

    def discover(config)
      pins = { 'toolchain' => config['toolchain'] }.merge(config['candidate']['releases'].transform_values { |r| r['version'] })
      REPOSITORIES.to_h do |name, repository|
        url = 'https://api.github.com/repos/' + repository + '/releases?per_page=30'
        source = { 'url' => url, 'retrieved_at' => @now.iso8601 }
        begin
          response = @fetcher.get(url, token: @token)
          raise Failure, 'provider_evidence_mismatch' unless response['url'] == url && response['sha256'] == Digest::SHA256.hexdigest(response.fetch('body')) && Time.iso8601(response.fetch('retrieved_at')) <= Time.now.utc
          source = response.slice('url', 'retrieved_at', 'sha256', 'transport_sha256')
          data = JSON.parse(response.fetch('body'))
          raise Failure, 'provider_invalid_response' unless data.is_a?(Array) && !data.empty? && data.size <= 30
          newer = data.filter_map do |release|
            raise Failure, 'provider_invalid_release' unless release.is_a?(Hash) && [true, false].include?(release['draft']) && [true, false].include?(release['prerelease'])
            next if release['draft'] || release['prerelease']
            version = release.fetch('tag_name').delete_prefix('v')
            # Some upstream RC releases are not flagged prerelease by GitHub.
            next if version.match?(/\A\d+\.\d+\.\d+-[0-9A-Za-z][0-9A-Za-z.-]*\z/)
            raise Failure, 'provider_unrecognized_stable_tag' unless version.match?(/\A\d+\.\d+\.\d+\z/)
            published = Time.iso8601(release.fetch('published_at'))
            raise Failure, 'provider_future_release' if published > @now
            next unless Gem::Version.new(version) > Gem::Version.new(pins.fetch(name))
            { 'version' => version, 'published_at' => published.utc.iso8601,
              'age_state' => @now - published >= config['minimum_release_age_days'] * 86_400 ? 'eligible_for_review' : 'age_blocked',
              'major_change' => version.split('.').first != pins[name].split('.').first }
          end
          newer.sort_by! { |r| Gem::Version.new(r['version']) }
          value = { 'state' => 'observed', 'reviewed_version' => pins[name], 'newer' => newer.uniq,
                    'coverage' => 'first_30_release_records_not_full_interval', 'source' => source }
        rescue Failure, JSON::ParserError, KeyError, ArgumentError, NoMethodError, TypeError => error
          reason = error.is_a?(Failure) ? error.message : 'provider_malformed_data'
          value = { 'state' => 'incomplete', 'reviewed_version' => pins[name], 'reason' => reason, 'newer' => [],
                    'source' => source }
        end
        [name, value]
      end
    end
  end

  class CompatibilityWatch
    attr_reader :output

    def initialize(root, previous: nil, output: nil, fetcher: WatchHTTP.new, probe: nil, history: 'local', scope: 'local', now: Time.now.utc, token: nil)
      @root, @previous, @fetcher, @probe, @history, @scope, @now = root, previous, fetcher, probe, history, scope, now
      @token = token
      base = File.join(root, '.maintenance', 'watch-reports')
      @output = output ? File.expand_path(output, root) : File.join(base, SecureRandom.hex(16))
      unless @output.start_with?(base + '/') && !File.exist?(@output)
        raise Failure, 'Watch output must be a new directory below .maintenance/watch-reports/'
      end
      ancestor = @output
      until ancestor == root
        raise Failure, 'Symlinked watch output' if File.symlink?(ancestor)
        ancestor = File.dirname(ancestor)
      end
      FileUtils.mkdir_p(@output)
    end

    def native(source)
      @probe_stage = 'prerequisites'
      store = RunStore.new(File.join(@root, '.maintenance', 'runs-compatibility-watch'))
      adapter = CompatibilityRehearsal.new(@root, source: source, profile: 'bridge-compile')
      policy_path = File.join(@root, 'maintenance-execution-policy.json')
      executor = Executor.new(source: source, adapter: adapter, store: store, policy: JSON.parse(File.read(policy_path)), input_files: [__FILE__, policy_path, File.join(@root, 'scripts/maintenance/lib/watch.rb')])
      @probe_stage = 'execution'
      result = executor.run
      @probe_stage = 'verification'
      report = CompatibilityReport.read(store, result.fetch('run_id'))
      [report, nil]
    ensure
      if executor && executor.journal
        id = executor.journal.fetch('id'); recovery = Recovery.new(store)
        @native_run_id = id
        recovered = recovery.recover(id, action: 'stop')
        cleaned = recovered['state'] == 'quiescent' ? recovery.cleanup(id, apply: true, discard: true) : { 'state' => 'ownership_uncertain' }
        RunStore.atomic(File.join(@output, 'recovery.json'), recovered)
        RunStore.atomic(File.join(@output, 'cleanup.json'), cleaned)
        @cleanup_state = cleaned['state']
      end
    end

    def run
      source = Source.new(@root); adapter = Compatibility.new(@root, now: @now)
      assessment = adapter.assessment(source)
      releases = KotlinReleaseWatch.new(fetcher: @fetcher, now: @now, token: @token).discover(adapter.config)
      RunStore.atomic(File.join(@output, 'discovery.json'), releases)
      begin
        native_report, injected_cleanup = @probe ? @probe.call(source) : native(source)
        @cleanup_state ||= injected_cleanup
        raise Failure, 'Missing verified watch native result' unless native_report && native_report['adoption_authorized'] == false
        RunStore.atomic(File.join(@output, 'native-report.json'), native_report)
      rescue StandardError => error
        @probe_error = true
        native_report = { 'state' => @probe_stage == 'verification' ? 'refused' : 'incomplete', 'reason' => 'watch_probe_unavailable', 'phases' => [], 'adoption_authorized' => false }
        RunStore.atomic(File.join(@output, 'probe-failure.json'), { 'class' => error.class.name, 'stage' => @probe_stage, 'state' => native_report['state'] })
      end
      matrix = native_report.fetch('phases', []).each_with_object({}) do |phase, result|
        phase.fetch('cells').each { |cell, value| result[phase['phase'] + '/' + cell] = value.fetch('status') }
      end
      gaps = assessment['missing_capabilities'] + %w[native_tests application_builds retirement_approval]
      gaps << 'release_provider_coverage' if releases.values.any? { |r| r['state'] != 'observed' }
      gaps << 'watch_native_result' if matrix.empty?
      gaps << 'watch_cleanup' unless @cleanup_state == 'cleaned'
      gaps << 'watch_history_provider' unless %w[local found initial].include?(@history)
      state = native_report['state']
      state = 'incomplete' if gaps.any? { |gap| %w[release_provider_coverage watch_native_result watch_history_provider watch_cleanup].include?(gap) }
      scope = { 'adapter' => 'kotlin-bridge-compile-v1', 'channel' => @scope, 'toolchain' => adapter.config['toolchain'],
                'baseline' => adapter.config['baseline'], 'candidate' => adapter.config['candidate'],
                'probe_inputs_sha256' => Maintenance.digest(source.files.reject { |path, _| path.start_with?('docs/', 'openspec/') || %w[README.md AGENTS.md LICENSE LICENSE.md].include?(path) }),
                'minimum_release_age_days' => adapter.config['minimum_release_age_days'] }
      observation = { 'assessment_state' => state, 'native_state' => native_report['state'], 'native_reason' => native_report['reason'],
                      'matrix' => matrix, 'releases' => releases.transform_values { |r| r.reject { |key, _| key == 'source' } },
                      'direct_paths' => assessment['direct_paths'], 'missing_capabilities' => gaps.uniq.sort,
                      'cleanup' => @cleanup_state || 'not_started', 'history_provider' => @history == 'local' ? 'local' : @history == 'initial' ? 'available' : @history == 'found' ? 'available' : 'incomplete' }
      previous, continuity = Watch.previous(@history == 'initial' ? nil : @previous, scope, now: @now)
      continuity = 'history_provider_unavailable' unless %w[local found initial].include?(@history)
      current = Watch.snapshot(scope, observation, now: @now)
      operational = @cleanup_state == 'cleaned' && !@probe_error && !%w[refused executor_failure].include?(native_report['state'])
      report = { 'schema' => 1, 'operation_state' => operational ? 'observation_recorded' : 'failed',
                 'source_sha256' => Maintenance.digest(source.files), 'config_sha256' => assessment['config_sha256'],
                 'snapshot' => current, 'notification' => Watch.compare(current, previous, continuity: continuity),
                 'native_run_id' => @native_run_id, 'native_result_sha256' => native_report['result_sha256'], 'adoption_authorized' => false, 'bridge_retirement' => 'defer' }
      source.verify!
      RunStore.atomic(File.join(@output, 'snapshot.json'), current)
      RunStore.atomic(File.join(@output, 'report.json'), report)
      File.write(File.join(@output, 'summary.md'), Watch.summary(report))
      report
    end
  end
end
