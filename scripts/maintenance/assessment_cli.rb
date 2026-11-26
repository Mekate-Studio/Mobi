# frozen_string_literal: true

require_relative 'lib/release_assessment'
require_relative 'adapters/assessment_qualification'
require_relative 'lib/assessment_authorities'
require_relative 'lib/assessment_git'
require_relative 'lib/assessment_bundle'

module Maintenance
  class ReleaseAssessment
    attr_reader :output

    def initialize(root, http: nil, qualifier: AssessmentQualification.method(:run), now: Time.now.utc, previous: nil, output: nil)
      @root, @http, @qualifier, @now = File.realpath(root), http, qualifier, now
      @previous, @requested_output = previous, output
    end

    def declarations(source)
      wrapper = File.read(File.join(@root, 'kotlin'))
      module_text = source.files.keys.grep(%r{(?:^|/)module\.yaml\z}).map { |path| File.read(File.join(@root, path)) }.join("\n")
      metro = module_text.scan(/dev\.zacsweers\.metro:[A-Za-z0-9_.-]+:([^\s]+)/).flatten.uniq
      kotlin = module_text.scan(/org\.jetbrains\.kotlin:swift-export-embeddable:([^\s]+)/).flatten.uniq
      swift = ReleaseWatch.new.swift_versions(source)
      { 'toolchain' => wrapper[/^kotlin_cli_version=(\S+)/, 1],
        'metro' => metro.size == 1 ? metro.first : nil,
        'kotlin' => kotlin.size == 1 ? kotlin.first : nil }.merge(swift)
    end

    def run
      parent = File.join(@root, '.maintenance')
      raise Failure, 'Symlinked maintenance store' if File.symlink?(parent)
      FileUtils.mkdir_p(parent)
      lock_path = File.join(parent, 'release-assessment.lock')
      raise Failure, 'Symlinked assessment lease' if File.symlink?(lock_path)
      File.open(lock_path, File::RDWR | File::CREAT, 0o600) do |lease|
        raise Failure, 'Assessment already active' unless lease.flock(File::LOCK_EX | File::LOCK_NB)
        assess(parent)
      end
    end

    def assess(parent)
      AssessmentQualification.maven_endpoint(ENV['KOTLIN_DEFAULT_MAVEN_CENTRAL_URL'])
      source = Source.new(@root)
      policy_path = File.join(@root, 'maintenance-policy.json')
      policy = JSON.parse(File.read(policy_path))
      raise Failure, 'Automatic adoption must stay disabled' unless policy['automatic_adoption'] == false
      run_id = SecureRandom.hex(16)
      reports = File.join(parent, 'release-assessments')
      raise Failure, 'Symlinked assessment reports' if File.symlink?(reports)
      FileUtils.mkdir_p(reports)
      @output = @requested_output ? File.expand_path(@requested_output, @root) : File.join(reports, run_id)
      raise Failure, 'Assessment output must be a new ignored report directory' unless
        @output.start_with?(reports + '/') || @output.start_with?(File.join(parent, 'watch-reports') + '/')
      relative = @output.delete_prefix(@root + '/')
      parts = relative.split('/')
      raise Failure, 'Symlinked or existing assessment output' if File.exist?(@output) || parts.each_index.any? { |i| File.symlink?(File.join(@root, *parts.take(i + 1))) }
      FileUtils.mkdir_p(File.dirname(@output))
      Dir.mkdir(@output, 0o700)
      evidence = File.join(@output, 'evidence'); Dir.mkdir(evidence, 0o700)
      http = @http || AssessmentHTTP.new(evidence, token: ENV['MOBI_WATCH_GITHUB_TOKEN'])
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 2700
      report = { 'schema' => 1, 'run_id' => run_id, 'created_at' => @now.iso8601, 'kind' => 'local_release_assessment',
        'source' => source.public_identity, 'source_sha256' => Maintenance.digest(source.files), 'git' => source.git_identity, 'policy_sha256' => Maintenance.file_sha(policy_path),
        'bounds' => { 'seconds' => 2700, 'official_evidence_api_requests' => 128, 'release_pages_per_provider' => 4, 'qualified_candidates' => 1, 'concurrency' => 1, 'source_git_seconds' => 120, 'source_git_storage_bytes' => AssessmentGit::MAX_STORAGE, 'source_git_changed_file_limit' => AssessmentGit::MAX_FILES, 'cache' => 'fresh_per_run_url_and_payload' },
        'adoption_authorized' => false, 'retirement_authorized' => false, 'pr_creation_authorized' => false,
        'assessment_prerequisite_complete' => false, 'catalogs' => {}, 'assessments' => [], 'gaps' => [] }
      pins = declarations(source)
      scope = { 'adapter' => 'local-release-assessment-v1', 'tuple_sha256' => Maintenance.digest(pins),
        'policy_sha256' => report['policy_sha256'], 'channel' => ENV.fetch('MOBI_WATCH_SCOPE', 'local') }
      previous_path = @previous ? File.expand_path(@previous, @root) : File.join(parent, 'release-assessment-state.json')
      raise Failure, 'Assessment history must be inside ignored maintenance storage' unless previous_path.start_with?(parent + '/')
      raise Failure, 'Symlinked assessment history' if File.exist?(previous_path) && File.realpath(previous_path) != previous_path
      prior, continuity = Watch.previous(previous_path, scope, now: @now)
      if ENV['MOBI_WATCH_HISTORY'] == 'incomplete'
        prior = nil; continuity = 'restore_incomplete'
      end
      report['history_state'] = continuity
      order = %w[metro tca clocks concurrency_extras toolchain kotlin]
      cursor = prior && prior.dig('observation', 'selection_cursor', 'last_component')
      order = order.rotate(order.index(cursor) + 1) if order.include?(cursor)
      report['selection_order'] = order

      repositories = ReleaseWatch::REPOSITORIES.reject { |key, _| key == 'skie' }.merge(ReleaseWatch::SWIFT_PACKAGES.transform_values { |value| 'pointfreeco/' + value })
      repositories.each do |name, repository|
        report['catalogs'][name] = if pins[name]
          catalog = AssessmentCatalog.collect(http, repository, pins[name], now: @now)
          coordinates = { 'toolchain' => [{ 'coordinate' => 'org.jetbrains.kotlin:kotlin-cli', 'registry' => 'https://packages.jetbrains.team/maven/p/amper/amper' }],
            'kotlin' => ['org.jetbrains.kotlin:swift-export-embeddable'],
            'metro' => %w[dev.zacsweers.metro:runtime dev.zacsweers.metro:compiler] }.fetch(name, [])
          AssessmentCatalog.channels(http, repository, pins[name], catalog, maven: coordinates)
        else
          { 'state' => 'incomplete', 'repository' => repository, 'releases' => [], 'gaps' => ['current_declaration_missing_or_ambiguous'] }
        end
        checkpoint(report, http)
      end
      qualified = 0
      store = nil
      # Newest eligible supported leads first; every other version stays visible
      # as budget-deferred, never silently passed or dropped from the packet.
      order.each do |name|
        catalog = report.fetch('catalogs').fetch(name)
        catalog.fetch('releases').reverse_each do |release|
          age_eligible = release['published_at'] && @now - Time.iso8601(release['published_at']) >= policy.fetch('minimum_release_age_days') * 86_400
          row = { 'component' => name, 'baseline' => pins[name], 'release' => release.reject { |key, _| key == 'notes' },
            'age_eligible' => age_eligible, 'stages' => {}, 'adoption_authorized' => false }
          report['assessments'] << row
          unless Array(release['gaps']).empty?
            row['decision'] = { 'recommendation' => 'incomplete', 'reason' => 'official_release_metadata_missing', 'gaps' => release['gaps'], 'adoption_authorized' => false }
            next
          end
          if !age_eligible || qualified >= 1 || Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
            row['decision'] = { 'recommendation' => 'defer', 'reason' => !age_eligible ? 'release_age_blocked' : 'candidate_budget_deferred', 'adoption_authorized' => false }
            next
          end
          qualified += 1
          row['assessment_started'] = true
          report['last_component'] = name
          interval = AssessmentCatalog.interval(http, catalog['repository'], catalog['baseline_tag'] || pins[name], release, git_fallback: AssessmentGit.method(:collect))
          authorities = if %w[kotlin toolchain].include?(name)
            AssessmentAuthorities.collect(http, baseline_published: catalog['baseline_published_at'], candidate_published: release['published_at'])
          else
            { 'state' => 'complete', 'role' => 'not_a_swift_export_owner_update', 'gaps' => [] }
          end
          authority_file = 'authorities-' + name + '-' + release['version'] + '.json'
          RunStore.atomic(File.join(@output, authority_file), authorities)
          interval_file = 'interval-' + name + '-' + release['version'] + '.json'
          RunStore.atomic(File.join(@output, interval_file), interval)
          row['stages']['upstream'] = { 'state' => interval['state'] == 'collected' && catalog['state'] == 'collected' && authorities['state'] == 'complete' ? 'complete' : 'incomplete',
            'interval_reference' => { 'file' => interval_file, 'sha256' => Maintenance.file_sha(File.join(@output, interval_file)) },
            'authorities_reference' => { 'file' => authority_file, 'sha256' => Maintenance.file_sha(File.join(@output, authority_file)) },
            'baseline_commit' => interval['baseline_commit'], 'candidate_commit' => interval['candidate_commit'], 'gaps' => catalog['gaps'] + interval['gaps'] + authorities['gaps'], 'authorities' => authorities.reject { |key, _| %w[primary_document supporting_sample].include?(key) } }
          row['stages']['impact'] = AssessmentImpact.analyze(@root, source, name, interval)
          row['stages']['constraints'] = AssessmentConstraints.evaluate(@root, name, pins[name], release['version'])
          begin
            edits = AssessmentPatch.prepare(source, name, pins[name], release, interval, http: http)
            row['patch_sha256'] = Maintenance.digest(edits)
            row['patch_file'] = 'candidate-patch-' + name + '-' + release['version'] + '.json'
            RunStore.atomic(File.join(@output, row['patch_file']), edits)
            store ||= RunStore.new(File.join(parent, 'runs-release-assessment'))
            qualification, security, cleanup = @qualifier.call(@root, source, edits, store, deadline: deadline, http: http)
            row['stages'].merge!('qualification' => qualification, 'security' => security, 'cleanup' => cleanup)
            row['stages']['evidence'] = AssessmentBundle.export(@root, @output, qualification, security: security)
          rescue Failure => error
            row['stages']['qualification'] = { 'state' => 'incomplete', 'reason' => error.message }
            row['stages']['security'] = { 'state' => 'incomplete', 'gaps' => ['selected_graph_pair_unavailable'] }
            row['stages']['cleanup'] = { 'state' => 'complete', 'result' => 'no_qualification_resources_allocated' }
            row['stages']['evidence'] = { 'state' => 'complete', 'files' => {}, 'bytes' => 0 }
          end
          source.verify!
          row['decision'] = AssessmentDecision.evaluate(row['stages'], age_eligible: age_eligible, source_verified: true, channel: release['channel'])
          row['next_slices'] = AssessmentDecision.next_slices(row)
          checkpoint(report, http)
        end
      end
      source.verify!
      raise Failure, 'Source Git identity changed during assessment' unless source.git_identity == report['git']
      report['coverage'] = { 'components' => repositories.keys.sort, 'release_channels' => %w[stable prerelease],
        'catalog_source' => 'official_github_releases_tags_and_selected_maven_metadata', 'outside_scope' => %w[unpublished_nightlies additional_dependency_families],
        'qualification_limit' => 1, 'adoption_readiness' => 'per_candidate_exact_packet_only' }
      report['catalogs'].each { |name, catalog| catalog['gaps'].each { |gap| report['gaps'] << name + ':' + gap } }
      report['assessments'].each do |row|
        report['gaps'] << row['component'] + ':' + row['release']['version'] + ':official_release_metadata_missing' if row.dig('decision', 'recommendation') == 'incomplete' && !row['assessment_started']
      end
      started = report['assessments'].select { |row| row['assessment_started'] }
      started.each do |row|
        row['stages'].each do |stage, result|
          next if result['state'] == 'complete'
          report['gaps'] << row['component'] + ':' + row['release']['version'] + ':' + stage
        end
      end
      report['gaps'] = report['gaps'].uniq.sort
      report['state'] = report['gaps'].empty? ? 'complete' : 'incomplete'
      # A recorded run is useful evidence even when blocked. It cannot close the
      # operational prerequisite while implemented coverage still has gaps.
      report['assessment_prerequisite_complete'] = report['state'] == 'complete' && !started.empty?
      report['operation_state'] = 'assessment_packet_recorded'
      observation = {
        'assessment_state' => report['state'], 'selection_cursor' => { 'last_component' => report['last_component'] },
        'catalogs' => report['catalogs'].transform_values { |catalog| catalog.slice('state', 'baseline', 'gaps').merge('versions' => catalog['releases'].map { |release| release.slice('version', 'channel') }) },
        'decisions' => report['assessments'].map { |row| [row['component'], row.dig('release', 'version'), row['decision']] }
      }
      snapshot = Watch.snapshot(scope, observation, now: @now)
      # Rotation is scheduling state, not a new release/capability finding.
      semantic = ->(value) { value && value.merge('observation' => value['observation'].reject { |key, _| key == 'selection_cursor' }) }
      report['notification'] = Watch.compare(semantic.call(snapshot), semantic.call(prior), continuity: continuity)
      RunStore.atomic(File.join(@output, 'snapshot.json'), snapshot)
      RunStore.atomic(File.join(parent, 'release-assessment-state.json'), snapshot)

      checkpoint(report, http)
      report
    rescue StandardError, Interrupt => error
      if report
        report['state'] = 'incomplete'
        report['operation_state'] = 'assessment_operation_failed'
        report['gaps'] << 'operation_' + error.class.name
        report['assessments'].each do |row|
          row['decision'] ||= { 'recommendation' => 'incomplete', 'reason' => 'assessment_operation_failed', 'adoption_authorized' => false }
        end
      end
      raise
    ensure
      checkpoint(report, http) if report && http && @output
    end

    def checkpoint(report, http)
      report['provider_evidence'] = http.receipts
      report['provider_requests'] = http.requests
      report['provider_failures'] = http.failures
      report['packet_sha256'] = Maintenance.digest(report.reject { |key, _| key == 'packet_sha256' })
      RunStore.atomic(File.join(@output, 'report.json'), report)
      lines = ['# Local release assessment', '', 'State: ' + report.fetch('state', 'running') + '. Adoption is not authorized.',
        '', '| Component | Candidate | Recommendation | Reason |', '| --- | --- | --- | --- |']
      visible = report.fetch('assessments').select { |row| row['assessment_started'] } + report.fetch('assessments').reject { |row| row['assessment_started'] }.take(40)
      visible.each do |row|
        decision = row['decision'] || { 'recommendation' => 'running', 'reason' => 'assessment_in_progress' }
        lines << '| ' + [row['component'], row.dig('release', 'version'), decision['recommendation'], decision['reason']].join(' | ') + ' |'
      end
      omitted = report['assessments'].size - visible.size
      lines << '' << "#{omitted} additional version decisions are retained in report.json." if omitted.positive?
      report.fetch('assessments').select { |row| row['assessment_started'] }.each do |row|
        lines += ['', row['component'] + ' ' + row['release']['version'] + ':']
        row['stages'].each do |stage, result|
          reasons = Array(result['gaps']) + Array(result['reason'])
          lines << '- ' + stage + ': ' + result['state'].to_s + (reasons.empty? ? '' : ' (' + reasons.join(', ') + ')')
        end
        checks = row.dig('stages', 'qualification')
        lines << '- Native comparison: baseline ' + checks.fetch('baseline', 'unavailable') + ', candidate ' + checks.fetch('candidate', 'unavailable') + '.' if checks
        ids = row.dig('stages', 'impact', 'workarounds').to_a.map { |entry| entry['id'] }
        lines << '- Workaround rechecks: ' + ids.join(', ') + '; retirement remains unqualified.' unless ids.empty?
        Array(row['next_slices']).each { |slice| lines << '- Proposed next slice: ' + slice['action'] + ' (`' + slice['code'].join('`, `') + '`).' }
      end
      lines += ['', 'The automation prerequisite remains open while required assessment stages are incomplete.',
        'No assessment PR is created. Complete local assessment precedes exact-packet human approval and one adoption PR.']
      lines += ['', 'Packet: `' + report['packet_sha256'] + '`.']
      File.write(File.join(@output, 'summary.md'), lines.join("\n") + "\n")
    end
  end

  module AssessmentCLI
    module_function

    def call(root, args)
      options = {}
      until args.empty?
        flag = args.shift
        raise Failure, 'Usage: assess-releases [--previous FILE] [--output DIR]' unless %w[--previous --output].include?(flag) && args.first && !options.key?(flag)
        options[flag] = args.shift
      end
      runner = ReleaseAssessment.new(root, previous: options['--previous'], output: options['--output'])
      report = runner.run
      if ENV['GITHUB_STEP_SUMMARY']
        File.open(ENV.fetch('GITHUB_STEP_SUMMARY'), 'a') { |file| file.write(File.read(File.join(runner.output, 'summary.md'))) }
      end
      puts JSON.pretty_generate(report.slice('run_id', 'state', 'operation_state', 'packet_sha256', 'gaps', 'provider_requests',
        'assessment_prerequisite_complete', 'adoption_authorized', 'pr_creation_authorized').merge(
          'report_directory' => runner.output.delete_prefix(root + '/'),
          'decision_counts' => report['assessments'].group_by { |row| row.dig('decision', 'recommendation') }.transform_values(&:size),
          'assessments' => report['assessments'].select { |row| row['assessment_started'] }.map { |row| row.slice('component', 'baseline', 'release', 'decision') }))
      report['state'] == 'complete' ? 0 : 2
    end
  end
end
