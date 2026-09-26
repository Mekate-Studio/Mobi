# frozen_string_literal: true

require_relative 'run_store'
require 'rbconfig'

module Maintenance
  class ExecutionStop < Failure
    attr_reader :state, :reason
    def initialize(state, reason)
      @state, @reason = state, reason
      super(reason)
    end
  end

  class Executor
    EXIT_CODES = { 'checks_passed' => 0, 'incomplete' => 20, 'inconclusive' => 21, 'incompatible' => 22, 'refused' => 23, 'executor_failure' => 24 }.freeze
    attr_reader :journal

    def initialize(source:, adapter:, store:, policy:, input_files: [])
      @source, @adapter, @store = source, adapter, store
      @policy = JSON.parse(JSON.generate(policy))
      valid = @policy['schema'] == 1 && @policy['automatic_adoption'] == false &&
              %w[outer_timeout_seconds startup_timeout_seconds termination_grace_seconds].all? { |key| @policy[key].is_a?(Numeric) && @policy[key] > 0 } &&
              @policy['outer_timeout_seconds'] <= 2700 && @policy['startup_timeout_seconds'] <= 30 && @policy['termination_grace_seconds'] <= 5 &&
              %w[success_retention_days failure_retention_days evidence_retention_days].all? { |key| @policy[key].is_a?(Integer) && @policy[key] >= 0 } && @policy['evidence_retention_days'] >= 90
      raise Failure, 'Unsupported execution policy' unless valid
      @plan = JSON.parse(JSON.generate(adapter.plan))
      validate_plan!
      @ruby = File.realpath(RbConfig.ruby)
      @worker = File.expand_path('../worker.rb', __dir__)
      paths = [__FILE__, @worker, File.join(__dir__, 'core.rb'), File.join(__dir__, 'run_store.rb'), File.join(__dir__, 'process_group.rb'), @ruby, '/bin/ps', '/usr/bin/git'] + adapter.code_files + input_files
      @plan['checks'].each { |check| paths += check['argv'].select { |arg| Pathname.new(arg).absolute? && File.file?(arg) } }
      @tools = paths.uniq.to_h { |path| [File.realpath(path), Maintenance.file_sha(path)] }
      @git = git_identity
      @code_sha = Maintenance.digest(@tools.values.sort)
      @steps = []
    end

    def validate_plan!
      valid = @plan['schema'] == 1 && @plan['id'].is_a?(String) && @plan['id'].match?(/\A[a-z][a-z0-9-]{1,63}\z/) &&
              @plan['scope'].is_a?(String) && @plan['missing_capabilities'].is_a?(Array) && @plan['missing_capabilities'].all? { |capability| capability.is_a?(String) } &&
              @plan['checks'].is_a?(Array) && !@plan['checks'].empty? && @plan['edits'].is_a?(Array) && @plan['resource_types'].is_a?(Array)
      raise Failure, 'Unsupported adapter protocol' unless valid
      @plan['checks'].each do |check|
        valid = check['id'].is_a?(String) && check['id'].match?(/\A[a-z][a-z0-9-]{1,63}\z/) && check['required'] == true &&
                check['argv'].is_a?(Array) && !check['argv'].empty? && check['argv'].all? { |a| a.is_a?(String) && !a.include?("\0") } &&
                Pathname.new(check['argv'][0]).absolute? && File.executable?(check['argv'][0]) &&
                check['timeout_seconds'].is_a?(Numeric) && check['timeout_seconds'] > 0
        raise Failure, 'Unsupported check protocol' unless valid
      end
      raise Failure, 'Duplicate check IDs' unless @plan['checks'].map { |c| c['id'] }.uniq.size == @plan['checks'].size
      raise Failure, 'Duplicate candidate edit' unless @plan['edits'].map { |e| e['path'] }.uniq.size == @plan['edits'].size
    end

    def git_identity
      env = { 'PATH' => '/usr/bin:/bin', 'LC_ALL' => 'C', 'GIT_CONFIG_GLOBAL' => File::NULL, 'GIT_CONFIG_NOSYSTEM' => '1', 'GIT_OPTIONAL_LOCKS' => '0' }
      head, status = Open3.capture2(env, '/usr/bin/git', '-C', @source.root, 'rev-parse', '--verify', '--quiet', 'HEAD', unsetenv_others: true)
      raise Failure, 'Cannot inspect source HEAD' unless status.success? || status.exitstatus == 1
      index, status = Open3.capture2(env, '/usr/bin/git', '-C', @source.root, 'ls-files', '--stage', '-v', '-z', unsetenv_others: true)
      raise Failure, 'Cannot inspect source index' unless status.success?
      { 'head' => head.strip.empty? ? nil : head.strip, 'index_sha256' => Digest::SHA256.hexdigest(index) }
    end

    def verify_inputs!
      @source.verify!
      raise Failure, 'Source Git identity changed' unless git_identity == @git
      raise Failure, 'Execution implementation changed' unless @tools.all? { |path, sha| File.file?(path) && Maintenance.file_sha(path) == sha }
      raise Failure, 'Adapter plan changed' unless @adapter.plan == @plan
    rescue Failure
      raise ExecutionStop.new('refused', 'source_plan_or_tool_drift')
    end

    def clock
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def guard_deadline!
      raise ExecutionStop.new('inconclusive', 'outer_deadline') if clock >= @deadline
    end

    def run
      id = SecureRandom.hex(16)
      @store.lock(id) do
        binding = { 'source_sha256' => Maintenance.digest(@source.files), 'capture_mode' => 'working_snapshot', 'git' => @git,
                    'adapter' => @plan['id'], 'adapter_schema' => @plan['schema'], 'plan_sha256' => Maintenance.digest(@plan),
                    'patch_sha256' => Maintenance.digest(@plan['edits']), 'tools_sha256' => @code_sha,
                    'execution_files' => @tools.map { |path, sha| { 'name' => File.basename(path), 'sha256' => sha } },
                    'runtime' => { 'ruby' => RUBY_VERSION, 'platform' => RUBY_PLATFORM }, 'policy_sha256' => Maintenance.digest(@policy) }
        @journal = @store.allocate(id, binding, @policy)
        @deadline = clock + @policy['outer_timeout_seconds']
        state, reason = 'checks_passed', 'named_checks_passed'
        begin
          verify_inputs!
          unless (@plan['resource_types'] - %w[filesystem process-group]).empty?
            raise ExecutionStop.new('incomplete', 'unsupported_resource_handler')
          end
          %w[baseline candidate].each { |phase| run_phase(phase) }
        rescue ExecutionStop => error
          state, reason = error.state, error.reason
        rescue Interrupt
          state, reason = 'inconclusive', 'interrupted'
        rescue StandardError => error
          state, reason = 'executor_failure', 'executor_exception'
          @store.event(@journal, 'executor_exception', 'class' => error.class.name)
        ensure
          begin
            verify_inputs!
          rescue ExecutionStop => error
            state, reason = error.state, error.reason
          end
        end
        @store.result(@journal, { 'schema' => 1, 'run_id' => id, 'state' => state, 'reason' => reason,
                                 'started_at' => @journal['created_at'], 'ended_at' => Time.now.utc.iso8601,
                                 'binding' => binding, 'steps' => @steps, 'attempts' => @journal['steps'].map { |step| step.select { |key, _| %w[id state process_exit output_sha256].include?(key) } }, 'scope' => @plan.fetch('scope'),
                                 'missing_capabilities' => @plan.fetch('missing_capabilities'), 'adoption_authorized' => false,
                                 'resources' => 'retained_for_review', 'cleanup' => 'not_requested' })
      end
    end

    def run_phase(phase)
      guard_deadline!; verify_inputs!
      @store.event(@journal, 'phase_started', 'phase' => phase)
      workspace = @store.directory(@journal, 'work/' + phase)
      %w[source home cache tmp output].each { |name| Dir.mkdir(File.join(workspace, name), 0o700) }
      source_dir = File.join(workspace, 'source')
      @source.copy_to(source_dir)
      @source.verify_copy!(source_dir)
      expected = JSON.parse(JSON.generate(@source.files))
      if phase == 'candidate'
        @plan['edits'].each do |edit|
          relative = edit['path']
          unless expected.key?(relative) && expected[relative]['sha256'] == edit['before_sha256'] && edit['content'].is_a?(String) &&
                 Digest::SHA256.hexdigest(edit['content']) == edit['after_sha256']
            raise ExecutionStop.new('refused', 'candidate_preimage_or_digest_mismatch')
          end
          target = File.join(source_dir, relative)
          File.binwrite(target, edit['content'])
          expected[relative]['sha256'] = edit['after_sha256']
        end
      end
      @source.verify_copy!(source_dir, expected: expected)
      @plan['checks'].each do |check|
        guard_deadline!; verify_inputs!
        step = run_check(phase, check, workspace)
        @steps << step
        @source.verify_copy!(source_dir, expected: expected)
        verify_inputs!
        case step['status']
        when 'passed' then next
        when 'missing' then raise ExecutionStop.new('incomplete', 'check_prerequisite_missing')
        when 'infrastructure' then raise ExecutionStop.new('inconclusive', 'check_infrastructure_failure')
        when 'failed' then raise ExecutionStop.new(phase == 'baseline' ? 'inconclusive' : 'incompatible', phase == 'baseline' ? 'baseline_failed' : 'candidate_regression')
        end
      end
      @store.event(@journal, 'phase_passed', 'phase' => phase)
    rescue Failure => error
      raise error if error.is_a?(ExecutionStop)
      raise ExecutionStop.new('refused', 'phase_source_drift') if error.message.start_with?('Copied source changed')
      raise
    end

    def run_check(phase, check, workspace)
      key = "#{phase}-#{check['id']}"
      control = @store.directory(@journal, 'steps/' + key, disposable: false)
      nonce = SecureRandom.hex(16)
      record = { 'id' => key, 'path' => 'steps/' + key, 'nonce' => nonce, 'state' => 'planned' }
      @journal['steps'] << record; @store.save(@journal)
      replacements = { '{source}' => File.join(workspace, 'source'), '{output}' => File.join(workspace, 'output'),
                       '{cache}' => File.join(workspace, 'cache'), '{phase}' => phase }
      argv = check['argv'].map { |arg| replacements.reduce(arg) { |text, (from, to)| text.gsub(from, to) } }
      environment = { 'PATH' => File.dirname(@ruby) + ':/usr/bin:/bin', 'HOME' => File.join(workspace, 'home'), 'TMPDIR' => File.join(workspace, 'tmp'),
                      'LANG' => 'C', 'LC_ALL' => 'C', 'GIT_CONFIG_GLOBAL' => File::NULL, 'GIT_CONFIG_NOSYSTEM' => '1',
                      'MOBI_RESULT_PATH' => File.join(control, 'check.json'), 'MOBI_PHASE' => phase }
      timeout = [check['timeout_seconds'], @deadline - clock].min
      raise ExecutionStop.new('inconclusive', 'outer_deadline') unless timeout > 0
      config = { 'argv' => argv, 'cwd' => replacements['{source}'], 'env' => environment,
                 'lifetime_seconds' => timeout + @policy['startup_timeout_seconds'] + 2, 'grace_seconds' => @policy['termination_grace_seconds'],
                 'coordinator' => ProcessGroup.identity(Process.pid) }
      RunStore.atomic(File.join(control, 'command.json'), config)
      started = clock; pid = nil; stopped = false
      begin
        pid = Process.spawn(environment, [@ruby, @ruby], @worker, control, nonce, pgroup: true, unsetenv_others: true,
                            close_others: true, in: File::NULL, out: File.join(control, 'supervisor.log'), err: [:child, :out], umask: 0o077)
        startup_deadline = [@deadline, clock + @policy['startup_timeout_seconds']].min
        until File.file?(File.join(control, 'started.json'))
          raise ExecutionStop.new('executor_failure', 'supervisor_startup_failed') if clock >= startup_deadline || Process.waitpid(pid, Process::WNOHANG)
          sleep 0.02
        end
        owner = JSON.parse(File.read(File.join(control, 'started.json')))
        unless owner['pid'] == pid && owner['nonce'] == nonce && ProcessGroup.owned?(owner, ProcessGroup.identity(pid))
          raise ExecutionStop.new('executor_failure', 'supervisor_identity_mismatch')
        end
        record.merge!('owner' => owner, 'state' => 'running'); @store.save(@journal)
        @store.event(@journal, 'check_started', 'check' => key)
        File.write(File.join(control, 'grant'), nonce)
        limit = [@deadline, clock + timeout].min
        until File.file?(File.join(control, 'finished.json'))
          raise ExecutionStop.new('inconclusive', 'check_timeout') if clock >= limit
          raise ExecutionStop.new('executor_failure', 'supervisor_failed') if File.file?(File.join(control, 'worker-error.json')) || Process.waitpid(pid, Process::WNOHANG)
          @journal['heartbeat_at'] = Time.now.utc.iso8601
          sleep 0.02
        end
        finished = JSON.parse(File.read(File.join(control, 'finished.json')))
        raise ExecutionStop.new('executor_failure', 'invalid_process_receipt') unless finished['schema'] == 1 && finished['nonce'] == nonce
        raise ExecutionStop.new('inconclusive', 'check_signaled') if finished['signal']
        # Only release a quiescent group. Surviving descendants are stopped while the leader is identifiable.
        if ProcessGroup.members(pid) == [pid]
          File.write(File.join(control, 'release'), nonce)
          limit = clock + @policy['termination_grace_seconds']
          loop do
            break if Process.waitpid(pid, Process::WNOHANG)
            break if clock >= limit
            sleep 0.02
          end
          stopped = ProcessGroup.members(pid).empty?
        end
        record['process_exit'] = finished['exit']
      ensure
        begin
          if pid && !stopped
            record['owner'] ||= JSON.parse(File.read(File.join(control, 'started.json'))) if File.file?(File.join(control, 'started.json'))
            if record['owner'] && record['owner']['pid'] == pid && record['owner']['nonce'] == nonce
              ProcessGroup.stop(record['owner'], grace: @policy['termination_grace_seconds'])
            elsif ProcessGroup.identity(pid)
              raise Failure, 'Supervisor ownership unavailable; retained for recovery'
            end
          end
          record['state'] = 'stopped'
          record['output_sha256'] = %w[stdout.log stderr.log check.json supervisor.log].each_with_object({}) do |name, hashes|
            file = File.join(control, name)
            hashes[name] = Maintenance.file_sha(file) if File.file?(file) && !File.symlink?(file)
          end
          @store.save(@journal)
        rescue StandardError
          record['state'] = 'cleanup_incomplete'; @store.save(@journal)
          raise ExecutionStop.new('executor_failure', 'process_cleanup_incomplete')
        ensure
          Process.waitpid(pid, Process::WNOHANG) rescue Errno::ECHILD if pid
        end
      end
      result_file = File.join(control, 'check.json')
      raise ExecutionStop.new('executor_failure', 'missing_or_invalid_check_result') unless File.file?(result_file) && !File.symlink?(result_file) && File.size(result_file) <= 1_048_576
      result = JSON.parse(File.read(result_file))
      valid = result['schema'] == 1 && result['check'] == check['id'] && result['phase'] == phase &&
              %w[passed failed missing infrastructure].include?(result['status']) &&
              (result['status'] == 'passed' ? record['process_exit'] == 0 : record['process_exit'].is_a?(Integer) && record['process_exit'] != 0)
      raise ExecutionStop.new('executor_failure', 'check_result_exit_mismatch') unless valid
      hashes = %w[stdout.log stderr.log check.json].to_h do |name|
        file = File.join(control, name)
        raise ExecutionStop.new('executor_failure', 'invalid_log_file') unless File.file?(file) && !File.symlink?(file)
        [name, Maintenance.file_sha(file)]
      end
      @store.event(@journal, 'check_finished', 'check' => key, 'status' => result['status'])
      { 'check' => check['id'], 'phase' => phase, 'status' => result['status'], 'exit' => record['process_exit'],
        'seconds' => (clock - started).round(3), 'argv' => check['argv'].map { |arg| Pathname.new(arg).absolute? ? File.basename(arg) : arg },
        'working_directory' => 'work/' + phase + '/source', 'environment_names' => environment.keys.sort, 'output_sha256' => hashes }
    rescue JSON::ParserError
      raise ExecutionStop.new('executor_failure', 'malformed_check_result')
    end
  end
end
