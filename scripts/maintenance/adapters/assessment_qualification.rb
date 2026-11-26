# frozen_string_literal: true

require_relative '../lib/executor'
require_relative '../lib/recovery'
require_relative '../lib/upgrade_graph'
require_relative '../lib/advisory_review'
require_relative '../lib/assessment_security'

module Maintenance
  module AssessmentPatch
    module_function

    def prepare(source, name, baseline, release, interval, http: nil)
      version = AssessmentCatalog.version(release.fetch('version'))
      edits = []
      case name
      when 'toolchain'
        raise Failure, 'official_wrapper_provider_required' unless http
        raise Failure, 'current_wrapper_version_mismatch' unless File.read(File.join(source.root, 'kotlin'))[/^kotlin_cli_version=(\S+)/, 1] == baseline
        hashes = %w[kotlin kotlin.bat].map do |path|
          suffix = path == 'kotlin' ? '' : '.bat'
          url = "https://packages.jetbrains.team/maven/p/amper/amper/org/jetbrains/kotlin/kotlin-cli/#{version}/kotlin-cli-#{version}-wrapper#{suffix}"
          content = http.get(url, json: false).gsub("\r\n", "\n")
          raise Failure, 'published_wrapper_version_mismatch' unless content.match?(/^(?:set )?kotlin_cli_version=#{Regexp.escape(version)}$/)
          checksum = content[/^(?:set )?kotlin_cli_sha256=([0-9a-f]{64})$/, 1]
          raise Failure, 'published_wrapper_checksum_missing' unless checksum
          edits << edit(source, path, content)
          checksum
        end
        raise Failure, 'published_wrapper_distributions_disagree' unless hashes.uniq.size == 1
        # Keep the exporter/CI reviewed-version guards unchanged. A new owner
        # tuple must demonstrate compatibility; this patch cannot grant it.
      when 'kotlin'
        source.files.keys.grep(%r{(?:^|/)module\.yaml\z}).each do |path|
          before = File.read(File.join(source.root, path))
          after = before.gsub(/(org\.jetbrains\.kotlin:swift-export-embeddable:)#{Regexp.escape(baseline)}(?=\s|$)/, '\\1' + version)
          edits << edit(source, path, after) unless before == after
        end
      when 'metro'
        source.files.keys.grep(%r{(?:^|/)module\.yaml\z}).each do |path|
          before = File.read(File.join(source.root, path))
          after = before.gsub(/(dev\.zacsweers\.metro:[A-Za-z0-9_.-]+:)#{Regexp.escape(baseline)}(?=\s|$)/, '\\1' + version)
          edits << edit(source, path, after) unless before == after
        end
      when 'tca', 'clocks', 'concurrency_extras'
        identity = ReleaseWatch::SWIFT_PACKAGES.fetch(name)
        sha = interval.fetch('candidate_commit')
        raise Failure, 'candidate_commit_unavailable' unless sha&.match?(/\A[0-9a-f]{40}\z/)
        source.files.keys.grep(%r{(?:^|/)Package\.resolved\z}).each do |path|
          data = JSON.parse(File.read(File.join(source.root, path)))
          pins = data.fetch('pins').select { |pin| pin['identity'] == identity }
          next if pins.empty?
          raise Failure, 'swift_pin_mismatch' unless pins.size == 1 && pins.first.dig('state', 'version') == baseline && pins.first['location'].to_s.sub(/\.git$/, '') == 'https://github.com/pointfreeco/' + identity
          pins.first['state'] = { 'revision' => sha, 'version' => version }
          edits << edit(source, path, JSON.pretty_generate(data) + "\n")
        end
      else
        # A Toolchain/compiler tuple needs an owner-specific preparation adapter.
        # Never loosen exporter/version guards or forge a wrapper checksum here.
        raise Failure, 'unsupported_assessment_component'
      end
      raise Failure, 'no_matching_candidate_declarations' if edits.empty?
      edits
    end

    def edit(source, path, content)
      { 'path' => path, 'before_sha256' => source.files.fetch(path).fetch('sha256'),
        'content' => content, 'after_sha256' => Digest::SHA256.hexdigest(content) }
    end
  end

  class AssessmentQualification
    attr_reader :plan, :code_files

    def initialize(root, source:, edits:)
      self.class.disk_preflight!(root)
      java = ENV['JAVA_HOME']; sdk = ENV['ANDROID_HOME'] || ENV['ANDROID_SDK_ROOT']
      raise Failure, 'qualification_requires_explicit_java_and_android_sdk' unless java && sdk && File.executable?(File.join(java, 'bin/java')) && File.directory?(File.join(sdk, 'platforms'))
      developer, status = Open3.capture2('/usr/bin/xcode-select', '-p')
      raise Failure, 'qualification_requires_xcode' unless status.success?
      host = { 'schema' => 1, 'ruby' => File.realpath(RbConfig.ruby), 'profile' => 'mobile', 'target_policy' => 'apple-silicon',
        'java_home' => File.realpath(java), 'android_sdk' => File.realpath(sdk), 'developer_dir' => File.realpath(developer.strip), 'macro_validation' => 'NO', 'maven_central_url' => self.class.maven_endpoint(ENV['KOTLIN_DEFAULT_MAVEN_CENTRAL_URL']) }
      quality = host['ruby'].match(%r{\A(.+/\.quality)/[^/]+/[0-9a-f]{64}/ruby/bin/ruby\z})
      host['quality_store'] = quality[1] if quality
      parent = File.join(root, '.maintenance', 'assessment-inputs')
      raise Failure, 'Symlinked assessment inputs' if File.symlink?(File.dirname(parent)) || File.symlink?(parent)
      FileUtils.mkdir_p(parent)
      host_path = File.join(parent, Maintenance.digest(host) + '.json')
      RunStore.atomic(host_path, host)
      @code_files = [__FILE__, host_path] + %w[assessment_check.rb assessment_provenance.py kotlin_check.rb lib/kotlin_evidence.rb lib/build_inputs.rb adapters/delegated_resolution.gradle adapters/kotlin_resources.rb].map { |path| File.join(root, 'scripts/maintenance', path) }
      @code_files << '/usr/bin/python3' if File.executable?('/usr/bin/python3')
      @plan = { 'schema' => 1, 'id' => 'release-assessment-mobile', 'scope' => 'local_development_candidate_assessment',
        'resource_types' => %w[filesystem process-group kotlin-native], 'phase_workspace_retention' => 'evidence_only',
        'missing_capabilities' => %w[complete_selected_build_owner_attribution signed_delivery device_exact_os_floor restoration_process_death shared_home_ui_runner],
        'edits' => edits, 'checks' => [{ 'id' => 'toolchain-mobile', 'required' => true, 'timeout_seconds' => 1500,
          'argv' => [File.realpath(RbConfig.ruby), File.join(root, 'scripts/maintenance/assessment_check.rb'), '{source}', '{output}', '{cache}', host_path, 'mobile'] }] }
    end

    MIN_FREE_KIB = 14 * 1024 * 1024

    def self.maven_endpoint(value)
      return nil unless value
      raise Failure, 'qualification_requires_supported_public_maven_endpoint' unless value.match?(%r{\Ahttps://(?:repo\.maven\.apache\.org|maven-central\.storage-download\.googleapis\.com)/maven2/?\z})
      value.delete_suffix('/')
    end

    def self.disk_preflight!(root, probe: nil)
      output, status = probe ? probe.call(root) : Open3.capture2('/bin/df', '-Pk', root)
      raise Failure, 'disk_preflight_unavailable' unless status.success?
      row = output.lines.last.to_s.split
      available = Integer(row[3], 10) rescue nil
      raise Failure, 'disk_preflight_unavailable' unless available && available >= 0
      raise Failure, 'qualification_requires_14_gib_free' if available < MIN_FREE_KIB
      available
    end

    def self.run(root, source, edits, store, deadline:, http:)
      adapter = new(root, source: source, edits: edits)
      policy = JSON.parse(File.read(File.join(root, 'maintenance-execution-policy.json')))
      remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
      raise Failure, 'assessment_deadline' unless remaining > 0
      policy['outer_timeout_seconds'] = [policy['outer_timeout_seconds'], remaining].min
      executor = Executor.new(source: source, adapter: adapter, store: store, policy: policy)
      result = executor.run
      phases = result.fetch('steps', [])
      summary = { 'state' => result['state'] == 'checks_passed' ? 'complete' : 'incomplete', 'run_id' => result['run_id'],
        'executor_state' => result['state'], 'result_sha256' => Maintenance.file_sha(store.path(result.fetch('run_id'), '.result.json')), 'reason' => result['reason'], 'binding' => result['binding'],
        'baseline' => phase_outcome(result, 'baseline'), 'candidate' => phase_outcome(result, 'candidate'),
        'gaps' => result['missing_capabilities'] }
      summary['evidence_refs'] = phases.map do |step|
        control = File.join(store.path(result.fetch('run_id')), 'steps', step.fetch('phase') + '-toolchain-mobile')
        evidence_path = File.join(control, 'evidence.json')
        { 'file' => evidence_path.delete_prefix(root + '/'), 'sha256' => Maintenance.file_sha(evidence_path) }
      end
      begin
        security = security(root, source, store, result, http: http)
      rescue StandardError => error
        security = { 'state' => 'incomplete', 'gaps' => [error.is_a?(Failure) ? error.message : error.class.name] }
      ensure
        recovery = Recovery.new(store)
        recovered = recovery.recover(result.fetch('run_id'), action: 'stop')
        cleaned = recovered['state'] == 'quiescent' ? recovery.cleanup(result['run_id'], apply: true, discard: true) : recovered
      end
      [summary, security, { 'state' => cleaned['state'] == 'cleaned' ? 'complete' : 'incomplete', 'result' => cleaned['state'] }]
    rescue Failure => error
      if executor && executor.journal
        recovery = Recovery.new(store)
        recovered = recovery.recover(executor.journal.fetch('id'), action: 'stop')
        cleaned = recovered['state'] == 'quiescent' ? recovery.cleanup(executor.journal['id'], apply: true, discard: true) : recovered
      end
      [{ 'state' => 'incomplete', 'reason' => error.message }, { 'state' => 'incomplete', 'gaps' => ['qualification_graph_unavailable'] },
        { 'state' => !executor || !executor.journal || cleaned['state'] == 'cleaned' ? 'complete' : 'incomplete',
          'reason' => executor && executor.journal ? cleaned['state'] : 'no_qualification_resources_allocated' }]
    end

    def self.phase_outcome(result, phase)
      return 'passed' if result.fetch('steps', []).any? { |step| step['phase'] == phase && step['status'] == 'passed' }
      return 'failed' if result['reason'] == (phase == 'baseline' ? 'baseline_failed' : 'candidate_regression')
      return 'inconclusive' if result.fetch('attempts', []).any? { |step| step['id'].start_with?(phase + '-') }
      'not_attempted'
    end

    def self.security(root, _source, store, result, http:)
      return { 'state' => 'incomplete', 'gaps' => ['passing_resolution_pair_unavailable'] } unless result['state'] == 'checks_passed'
      id = result.fetch('run_id')
      phase_inputs = %w[baseline candidate].to_h do |phase|
        control = File.join(store.path(id), 'steps', phase + '-toolchain-mobile')
        check = JSON.parse(File.read(File.join(control, 'check.json')))
        evidence_path = File.join(control, 'evidence.json')
        raise Failure, 'qualification_evidence_drift' unless check['evidence_sha256'] == Maintenance.file_sha(evidence_path)
        evidence = JSON.parse(File.read(evidence_path))
        read = lambda do |name|
          ref = evidence.fetch(name)
          raise Failure, 'unsafe_security_evidence_reference' unless ref.fetch('file').match?(/\A[a-z][a-z0-9-]*\.json\z/)
          path = File.join(control, ref['file'])
          raise Failure, 'security_evidence_drift' unless File.file?(path) && !File.symlink?(path) && Maintenance.file_sha(path) == ref.fetch('sha256')
          JSON.parse(File.read(path))
        end
        graphs = read.call('resolved-graphs')
        provenance = read.call('assessment-provenance')
        inputs = AssessmentSecurity.queries(graphs, provenance)
        [phase, inputs.merge('graph_sha256' => Maintenance.digest(graphs), 'provenance_sha256' => Maintenance.digest(provenance))]
      end
      policy = JSON.parse(File.read(File.join(root, 'maintenance-policy.json')))
      summaries = %w[baseline candidate].to_h do |phase|
        receipt = AssessmentSecurity.collect(http, phase_inputs.fetch(phase))
        path = File.join(store.path(id), 'assessment-advisories-' + phase + '.json')
        RunStore.atomic(path, receipt)
        [phase, receipt.slice('state', 'queries_sha256', 'findings', 'reasons').merge('query_count' => receipt['queries'].size, 'receipt_sha256' => Maintenance.file_sha(path))]
      end
      gaps = phase_inputs.values.flat_map { |inputs| inputs['gaps'] }
      gaps += summaries.values.flat_map { |summary| summary['reasons'] }
      candidate_findings = summaries.fetch('candidate').fetch('findings')
      blocked = candidate_findings.select { |finding| policy.fetch('blocking_severities').include?(finding['severity']) || finding['severity'] == 'unknown' }
      { 'state' => gaps.empty? ? 'complete' : 'incomplete',
        'module_graphs' => phase_inputs.transform_values { |inputs| inputs['graph_sha256'] },
        'provenance' => phase_inputs.transform_values { |inputs| inputs.slice('provenance_sha256', 'downloaded_archive_count', 'swift_locked_package_count', 'observed_owner_inputs', 'gaps') },
        'advisories' => summaries, 'gaps' => gaps.uniq.sort, 'blocking_findings' => blocked,
        'finding_delta' => AssessmentSecurity.finding_delta(summaries),
        'scope' => 'named_module_graphs_embedded_archive_claims_and_locked_swift_commits',
        'retained_risk_approval_reused' => false, 'exploitation_or_reachability' => 'not_established' }
    end

  end
end
