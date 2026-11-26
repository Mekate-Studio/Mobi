# frozen_string_literal: true

require_relative 'kotlin_check'
require_relative 'lib/build_inputs'
require_relative 'adapters/assessment_qualification'
require 'base64'

module Maintenance
  class AssessmentCheck < KotlinCheck
    def initialize(source, output, cache, host_file, profile)
      super
      host = JSON.parse(File.read(host_file))
      @assessment_host = host
      @env['JAVA_HOME'] = host.fetch('java_home')
      @env['KOTLIN_DEFAULT_MAVEN_CENTRAL_URL'] = host['maven_central_url'] if host['maven_central_url']
    end

    def self.prepare_index(work, paths, control)
      spec = File.join(control, 'assessment-source-paths')
      File.binwrite(spec, paths.join("\0") + "\0")
      env = { 'PATH' => '/usr/bin:/bin', 'HOME' => File.dirname(work), 'GIT_CONFIG_GLOBAL' => File::NULL, 'GIT_CONFIG_NOSYSTEM' => '1' }
      [ ['/usr/bin/git', 'init', '--quiet', work],
        ['/usr/bin/git', '--literal-pathspecs', '-C', work, 'add', '--force', '--pathspec-from-file=' + spec, '--pathspec-file-nul'] ].each do |argv|
        _out, error, status = Open3.capture3(env, *argv, unsetenv_others: true)
        raise Failure, 'owned_assessment_index_preparation_failed' unless status.success?
      end
    end

    def classify_command(name, text, code)
      # These qualify the harness and its historical fixtures, not the changed
      # library's runtime behavior. A broken prerequisite is inconclusive.
      return 'infrastructure' if name == 'maintenance-contracts' && code != 0
      super
    end

    def self.prerequisite_environment(environment)
      environment.reject { |name, _value| name.start_with?('MOBI_') }
    end

    def native_setup(simulator: true)
      super
      # This cache is owned and removed with this phase. Do not share candidate
      # packages with the baseline or reuse test DerivedData for the Debug build.
      @env['MOBI_XCODE_PACKAGES_DIR'] = File.join(@cache, 'swiftpm-checkouts')
      @report['environment']['swift_package_checkouts'] = 'phase_owned_test_and_build_only'
      # Reuse the existing observer in the owned Gradle home. Its unsupported
      # transform/AGP APIs keep their explicit gaps; version guards stay intact.
      init = File.join(@env.fetch('GRADLE_USER_HOME'), 'init.d')
      FileUtils.mkdir_p(init)
      FileUtils.cp(File.join(@work, 'scripts/maintenance/adapters/delegated_resolution.gradle'), File.join(init, 'mobi-evidence.gradle'))
    end

    def capture_owner_inputs
      producers = Dir.glob(File.join(@work, 'build', '**', 'kotlin_cli_traces.jsonl')) +
        Dir.glob(File.join(@cache, 'gradle/mobi-delegated-evidence/*.json'))
      raise Failure, 'build_input_producer_limit' if producers.size > 256 || producers.sum { |path| File.size(path) } > 16 * 1024 * 1024
      # Preserve bounded raw producers before interpretation so unsupported
      # schemas remain diagnosable after successful workspace cleanup.
      bytes = 0
      raw = producers.sort.map do |path|
        prefix = path.start_with?(@work + '/') ? @work : @cache
        BuildInputs.safe_file!(path, prefix)
        body = File.binread(path); bytes += body.bytesize
        raise Failure, 'build_input_producer_limit' if bytes > 16 * 1024 * 1024
        { 'source' => (prefix == @work ? '{work}' : '{cache}') + path.delete_prefix(prefix),
          'sha256' => Digest::SHA256.hexdigest(body), 'bytes' => body.bytesize, 'base64' => Base64.strict_encode64(body) }
      end
      write_evidence('owner-producers', { 'scope' => 'raw_owned_producers_not_interpretation_or_approval', 'files' => raw })
      settings = JSON.parse(File.read(File.join(@control, 'effective-settings.json')))
      versions = settings.values.flat_map { |fragments| fragments.values.map { |fragment| fragment.dig('kotlin', 'version') } }.compact.uniq
      raise Failure, 'ambiguous_executed_compiler_version' unless versions.size == 1 && versions.first.is_a?(String)
      BuildInputs.capture(@work, @cache, @env.fetch('HOME'), @control, compiler_version: versions.first)
      traces = JSON.parse(File.read(File.join(@control, 'compiler-traces.json')))
      plugins = JSON.parse(File.read(File.join(@control, 'selected-plugin-artifacts.json')))
      delegated = JSON.parse(File.read(File.join(@control, 'delegated-graphs.json')))
      delegated.each { |packet| BuildInputs.delegated!(packet.fetch('data')) }
      %w[compiler-traces selected-plugin-artifacts delegated-graphs].each do |name|
        write_evidence(name, JSON.parse(File.read(File.join(@control, name + '.json'))))
      end
      { 'state' => 'collected', 'compiler_version' => versions.first,
        'invocations' => BuildInputs.invocations(traces, compiler_version: versions.first), 'selected_plugin_artifacts' => plugins,
        'delegated_graphs' => delegated, 'complete_target_graph' => false }
    rescue Failure, KeyError, TypeError, NoMethodError, JSON::ParserError, Errno::ENOENT => error
      { 'state' => 'incomplete', 'gaps' => [error.is_a?(Failure) ? error.message : 'build_input_capture_unavailable'] }
    end

    def run
      AssessmentQualification.disk_preflight!(@output)
      # Static/contract validation belongs to the same candidate packet. Managed
      # tools are cloned, not installed from PATH or shared as mutable state.
      quality = @assessment_host['quality_store']
      raise Failure, 'managed_quality_store_unavailable' unless quality && File.directory?(quality) && !File.symlink?(quality)
      target = File.join(@work, '.quality')
      _, copied = Open3.capture2e('/bin/cp', '-cR', quality, target)
      unless copied.success?
        raise Failure, 'unsafe_partial_quality_snapshot' if File.symlink?(target)
        FileUtils.remove_entry_secure(target) if File.exist?(target)
        FileUtils.cp_r(quality, target)
      end
      self.class.prepare_index(@work, @manifest.keys, @control)
      @report['assessment_source_index'] = { 'scope' => 'owned_staged_source_copy', 'source_sha256' => Maintenance.digest(@manifest) }
      native = @native
      native_environment = @env
      begin
        # Contracts own synthetic process/resource fixtures; they run before
        # native setup, outside the native JVM observer's workspace prefix scan.
        @native = nil
        # Nested contract executors own their control paths and nonces. They
        # must never inherit this outer executor's result/control variables.
        @env = self.class.prerequisite_environment(native_environment)
        prerequisite = catch(:outcome) do
          command('static-quality', [File.join(@work, 'scripts/ci/run_job.sh'), 'quality-check'])
          command('maintenance-contracts', [File.join(@work, 'scripts/ci/run_job.sh'), 'quality-contracts'])
          'passed'
        end
      ensure
        @native = native
        @env = native_environment
      end
      if prerequisite != 'passed'
        @report['assessment_prerequisite_outcome'] = prerequisite
        RunStore.atomic(File.join(@control, 'evidence.json'), @report)
        return prerequisite
      end
      outcome = super
      begin
        fingerprints = File.join(@control, 'downloaded-artifacts.json')
        text, error, status = Open3.capture3('/usr/bin/python3', File.expand_path('assessment_provenance.py', __dir__),
          @cache, ENV.fetch('HOME'), fingerprints)
        raise Failure, 'archive_metadata_scanner_failed' unless status.success? && text.bytesize <= 32 * 1024 * 1024
        data = JSON.parse(text)
        data['owner_inputs'] = capture_owner_inputs
        locks = @manifest.keys.grep(%r{(?:^|/)Package\.resolved\z}).to_h do |path|
          body = File.read(File.join(@work, path))
          parsed = JSON.parse(body)
          raise Failure, 'unsupported_swift_lock_format' unless parsed['version'] == 3 && parsed['pins'].is_a?(Array)
          [path, { 'sha256' => Digest::SHA256.hexdigest(body), 'pins' => parsed['pins'] }]
        end
        data['swift_locks'] = locks
        write_evidence('assessment-provenance', data)
      rescue StandardError => error
        @report['provenance_failure'] = error.is_a?(Failure) ? error.message : error.class.name
      ensure
        RunStore.atomic(File.join(@control, 'evidence.json'), @report)
      end
      outcome
    rescue Failure => error
      @report['failure'] = error.message
      RunStore.atomic(File.join(@control, 'evidence.json'), @report)
      'missing'
    end
  end
end

if $PROGRAM_NAME == __FILE__
  # Preserve the explicitly selected supported repository endpoint. This is never
  # an automatic retry fallback and is part of the bound host-input receipt.
  source, output, cache, host_file, profile = ARGV
  check = Maintenance::AssessmentCheck.new(source, output, cache, host_file, profile)
  status = check.run
  status = 'infrastructure' if check.report['evidence_failure']
  evidence = File.join(File.dirname(ENV.fetch('MOBI_RESULT_PATH')), 'evidence.json')
  Maintenance::RunStore.atomic(ENV.fetch('MOBI_RESULT_PATH'), { 'schema' => 1, 'check' => 'toolchain-mobile', 'phase' => ENV.fetch('MOBI_PHASE'),
    'status' => status, 'evidence_sha256' => File.file?(evidence) ? Maintenance.file_sha(evidence) : nil })
  exit(status == 'passed' ? 0 : 1)
end
