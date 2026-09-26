# frozen_string_literal: true

require_relative 'lib/recovery'
require_relative 'fixtures/executor/kotlin'
require_relative 'fixtures/executor/elixir'

module ExecutorTest
  ROOT = File.expand_path('../..', __dir__)
  @tests = []
  def self.test(name, &block)
    @tests << [name, block]
  end
  def self.assert(value, message = 'assertion failed')
    raise message unless value
  end
  def self.reject(pattern)
    yield
    raise 'Expected rejection'
  rescue Maintenance::Failure => error
    assert(error.message.match?(pattern), error.message)
  end
  def self.wait_for(timeout: 10)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    loop do
      value = yield
      return value if value
      raise 'Fixture timed out waiting for event' if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      sleep 0.02
    end
  end
  def self.policy
    JSON.parse(File.read(File.join(ROOT, 'maintenance-execution-policy.json'))).merge('termination_grace_seconds' => 0.15)
  end
  def self.fixture(adapter_class = Maintenance::KotlinFixture, scenario: 'pass', timeout: 3)
    Dir.mktmpdir('mobi-executor-test-') do |root|
      input = File.join(root, 'input'); Dir.mkdir(input)
      _, status = Open3.capture2e('/usr/bin/git', 'init', '-q', input); assert(status.success?)
      adapter = adapter_class.new(input, scenario: scenario, timeout: timeout)
      store = Maintenance::RunStore.new(File.join(root, 'runs'))
      source = Maintenance::Source.new(input)
      executor = Maintenance::Executor.new(source: source, adapter: adapter, store: store, policy: policy)
      yield root, source, adapter, store, executor
    end
  end
  def self.latest(store)
    file = Dir.glob(File.join(store.root, '*.json')).reject { |path| path.end_with?('.result.json') }.first
    file && JSON.parse(File.read(file))
  end

  test('both adapters run baseline first with independent source caches and fake database files') do
    [Maintenance::KotlinFixture, Maintenance::ElixirFixture].each do |klass|
      fixture(klass) do |_root, source, adapter, store, executor|
        result = executor.run
        assert(result['state'] == 'checks_passed', result.inspect)
        assert(result['steps'].map { |step| step['phase'] } == %w[baseline candidate])
        assert(result['scope'] == 'synthetic_adapter_contract' && !result['adoption_authorized'])
        assert(result['missing_capabilities'].include?('native_builds'))
        journal = store.load(result['run_id'])
        %w[baseline candidate].each do |phase|
          workspace = File.join(journal['root'], 'work', phase)
          assert(File.read(File.join(workspace, 'cache/compiled.fixture')) == phase)
          assert(File.read(File.join(workspace, 'output/database.fixture')) == phase)
          assert(!File.exist?(File.join(workspace, 'source/.git')))
        end
        assert(File.read(File.join(journal['root'], 'work/baseline/source', adapter.class::FILE)) != File.read(File.join(journal['root'], 'work/candidate/source', adapter.class::FILE)))
        source.verify!
      end
    end
  end

  test('baseline failure stops candidate and retains original failure evidence') do
    fixture(scenario: 'baseline-failure') do |_root, _source, _adapter, store, executor|
      result = executor.run
      assert(result['state'] == 'inconclusive' && result['reason'] == 'baseline_failed')
      assert(!File.exist?(File.join(executor.journal['root'], 'work/candidate')))
      before = File.binread(store.path(result['run_id'], '.result.json'))
      Maintenance::Recovery.new(store).recover(result['run_id'], action: 'stop')
      assert(File.binread(store.path(result['run_id'], '.result.json')) == before)
    end
  end

  test('candidate semantic regression is incompatible and repair uses a new run') do
    fixture(scenario: 'candidate-failure') do |_root, source, adapter, store, executor|
      bad = executor.run
      assert(bad['state'] == 'incompatible' && bad['steps'].map { |step| step['status'] } == %w[passed failed])
      adapter.plan['edits'][0].merge!('content' => "dependency=1.0.1\n", 'after_sha256' => Digest::SHA256.hexdigest("dependency=1.0.1\n"))
      good = Maintenance::Executor.new(source: source, adapter: adapter, store: store, policy: policy).run
      assert(good['state'] == 'checks_passed' && good['run_id'] != bad['run_id'])
      assert(JSON.parse(File.read(store.path(bad['run_id'], '.result.json')))['state'] == 'incompatible')
    end
  end

  test('missing infrastructure malformed and contradictory results are distinct failures') do
    { 'missing' => 'incomplete', 'infrastructure' => 'inconclusive', 'malformed' => 'executor_failure', 'forged-success' => 'executor_failure' }.each do |scenario, expected|
      fixture(scenario: scenario) do |_root, _source, _adapter, _store, executor|
        result = executor.run
        assert(result['state'] == expected, result.inspect)
        assert(result['attempts'].size == 1 && !result['attempts'][0]['output_sha256'].empty?)
      end
    end
  end

  test('source-copy mutation is refused and caller bytes stay unchanged') do
    fixture(scenario: 'source-drift') do |_root, source, _adapter, _store, executor|
      result = executor.run
      assert(result['state'] == 'refused' && result['reason'] == 'phase_source_drift')
      source.verify!
    end
  end

  test('timeout stops stubborn owned children and cannot report compatibility') do
    fixture(scenario: 'timeout', timeout: 0.4) do |_root, _source, _adapter, store, executor|
      result = executor.run
      assert(result['state'] == 'inconclusive' && result['reason'] == 'check_timeout', result.inspect)
      journal = store.load(result['run_id'])
      assert(journal['steps'].all? { |step| Maintenance::ProcessGroup.members(step['owner']['pgid']).empty? })
      assert(Maintenance::Recovery.new(store).cleanup(result['run_id'])['state'] == 'dry_run')
    end
  end

  test('surviving children are stopped even after a check exits successfully') do
    fixture(scenario: 'child-survivor') do |_root, _source, _adapter, store, executor|
      result = executor.run
      assert(result['state'] == 'checks_passed', result.inspect)
      assert(store.load(result['run_id'])['steps'].all? { |step| Maintenance::ProcessGroup.members(step['owner']['pgid']).empty? })
    end
  end

  test('caller credentials and injection settings never reach checks') do
    fixture do |_root, _source, _adapter, _store, executor|
      values = %w[GITHUB_TOKEN AWS_SECRET_ACCESS_KEY DATABASE_URL JAVA_TOOL_OPTIONS].to_h { |key| [key, ENV[key]] }
      begin
        values.each_key { |key| ENV[key] = 'fixture-secret-must-not-appear' }
        result = executor.run
        assert(result['state'] == 'checks_passed' && !JSON.generate(result).include?('fixture-secret'))
        assert(result['steps'].all? { |step| (step['environment_names'] & values.keys).empty? })
      ensure
        values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
      end
    end
  end

  test('unsupported resource handlers and invalid check plans fail before checks') do
    fixture do |_root, source, adapter, store, _executor|
      adapter.plan['resource_types'] << 'postgresql'
      result = Maintenance::Executor.new(source: source, adapter: adapter, store: store, policy: policy).run
      assert(result['state'] == 'incomplete' && result['steps'].empty?)
      adapter.plan['checks'][0]['argv'] = ['echo hello > stolen']
      reject(/check protocol/) { Maintenance::Executor.new(source: source, adapter: adapter, store: store, policy: policy) }
    end
  end

  test('argv metacharacters are passed literally without a shell') do
    fixture do |root, source, adapter, store, _executor|
      marker = File.join(root, 'must-not-exist')
      adapter.plan['checks'][0]['argv'] << "$(touch #{marker}); touch #{marker}"
      result = Maintenance::Executor.new(source: source, adapter: adapter, store: store, policy: policy).run
      assert(result['state'] == 'checks_passed' && !File.exist?(marker))
    end
  end

  test('candidate preimage and content digest mismatches refuse adoption') do
    %w[before_sha256 after_sha256].each do |key|
      fixture do |_root, source, adapter, store, _executor|
        adapter.plan['edits'][0][key] = 'a' * 64
        result = Maintenance::Executor.new(source: source, adapter: adapter, store: store, policy: policy).run
        assert(result['state'] == 'refused' && result['steps'].size == 1)
      end
    end
  end

  test('same-stat caller drift invalidates a successful running check') do
    fixture(scenario: 'barrier') do |_root, source, adapter, _store, executor|
      mutation = Thread.new do
        wait_for { executor.journal && File.exist?(File.join(executor.journal['root'], 'work/baseline/output/started.fixture')) }
        file = File.join(source.root, adapter.class::FILE); stat = File.stat(file)
        File.write(file, "dependency=9.0.0\n"); File.utime(stat.atime, stat.mtime, file)
        File.write(File.join(executor.journal['root'], 'work/baseline/output/continue.fixture'), '')
      end
      result = executor.run; mutation.value
      assert(result['state'] == 'refused' && result['reason'] == 'source_plan_or_tool_drift')
      assert(File.read(File.join(source.root, adapter.class::FILE)).include?('9.0.0'), 'caller was restored')
    end
  end

  test('index-only drift invalidates unchanged source bytes') do
    fixture(scenario: 'barrier') do |_root, source, adapter, _store, executor|
      mutation = Thread.new do
        wait_for { executor.journal && File.exist?(File.join(executor.journal['root'], 'work/baseline/output/started.fixture')) }
        _, status = Open3.capture2e('/usr/bin/git', '-C', source.root, 'add', '--', adapter.class::FILE); assert(status.success?)
        File.write(File.join(executor.journal['root'], 'work/baseline/output/continue.fixture'), '')
      end
      result = executor.run; mutation.value
      assert(result['state'] == 'refused'); source.verify!
    end
  end

  test('cleanup defaults to a dry run and preserves immutable evidence after explicit discard') do
    fixture do |_root, _source, _adapter, store, executor|
      result = executor.run; recovery = Maintenance::Recovery.new(store); id = result['run_id']
      before = File.binread(store.path(id, '.result.json'))
      assert(recovery.cleanup(id)['state'] == 'dry_run' && File.directory?(File.join(executor.journal['root'], 'work/baseline')))
      assert(recovery.cleanup(id, apply: true)['state'] == 'retained')
      assert(recovery.cleanup(id, apply: true, discard: true)['state'] == 'cleaned')
      assert(recovery.cleanup(id, apply: true, discard: true)['state'] == 'cleaned')
      assert(!File.exist?(File.join(executor.journal['root'], 'work/baseline')))
      assert(File.binread(store.path(id, '.result.json')) == before)
      store.load(id)
    end
  end

  test('review holds and active leases prevent even explicit discard') do
    fixture do |_root, _source, _adapter, store, executor|
      id = executor.run['run_id']; recovery = Maintenance::Recovery.new(store)
      recovery.recover(id, action: 'hold')
      reject(/held for review/) { recovery.cleanup(id, apply: true, discard: true) }
      recovery.recover(id, action: 'release-hold')
      store.lock(id) { reject(/lease held/) { recovery.cleanup(id, apply: true, discard: true) } }
    end
  end

  test('symlinked resources and replaced ownership markers cannot delete an unowned sibling') do
    fixture do |root, _source, _adapter, store, executor|
      id = executor.run['run_id']; journal = store.load(id)
      path = File.join(journal['root'], 'work/baseline'); saved = path + '-saved'
      outside = File.join(root, 'unowned'); Dir.mkdir(outside); File.write(File.join(outside, 'keep'), 'keep')
      File.rename(path, saved); File.symlink(outside, path)
      reject(/symlink/) { Maintenance::Recovery.new(store).cleanup(id, apply: true, discard: true) }
      assert(File.read(File.join(outside, 'keep')) == 'keep')
      File.unlink(path); File.rename(saved, path)
      File.write(File.join(path, '.resource-owner.json'), '{}')
      reject(/ownership marker mismatch/) { Maintenance::Recovery.new(store).cleanup(id, apply: true, discard: true) }
    end
  end

  test('truncated journals and altered history cannot be accepted during recovery') do
    fixture do |_root, _source, _adapter, store, executor|
      id = executor.run['run_id']
      events = store.path(id, '.events.jsonl'); File.open(events, 'a') { |file| file.write('{truncated') }
      reject(/Truncated run history/) { Maintenance::Recovery.new(store).recover(id) }
    end
  end

  test('changed PID start or nonce cannot authorize signaling a live process') do
    nonce = SecureRandom.hex(16)
    pid = Process.spawn([RbConfig.ruby, RbConfig.ruby], '-e', "trap('TERM') {}; sleep 60", nonce, pgroup: true, out: File::NULL, err: File::NULL)
    owner = wait_for { current = Maintenance::ProcessGroup.identity(pid); current && current['command'].split.include?(nonce) && current.merge('nonce' => nonce, 'host' => Maintenance::ProcessGroup.host) }
    begin
      reject(/ownership mismatch/) { Maintenance::ProcessGroup.stop(owner.merge('start' => 'reused-pid'), grace: 0.05) }
      reject(/ownership mismatch/) { Maintenance::ProcessGroup.stop(owner.merge('nonce' => 'b' * 32), grace: 0.05) }
      assert(Maintenance::ProcessGroup.identity(pid))
    ensure
      Maintenance::ProcessGroup.stop(owner, grace: 0.1)
      Process.waitpid(pid)
    end
  end

  test('TERM interruption preserves a non-success receipt and releases the lease') do
    fixture(scenario: 'timeout', timeout: 20) do |root, _source, _adapter, store, executor|
      result_file = File.join(root, 'result.json')
      pid = fork do
        trap('TERM') { raise Interrupt }
        File.write(result_file, JSON.generate(executor.run)); exit! 0
      end
      journal = wait_for { current = latest(store); current && current['steps'].any? { |step| step['state'] == 'running' } && current }
      Process.kill('TERM', pid); Process.waitpid(pid)
      result = JSON.parse(File.read(result_file))
      assert(result['state'] == 'inconclusive' && result['reason'] == 'interrupted', result.inspect)
      assert(Maintenance::Recovery.new(store).recover(journal['id'])['state'] == 'quiescent')
    end
  end

  test('coordinator SIGKILL leaves recoverable evidence and a bounded worker lifetime') do
    fixture(scenario: 'timeout', timeout: 20) do |_root, _source, _adapter, store, executor|
      pid = fork { executor.run; exit! 0 }
      journal = wait_for { current = latest(store); current && current['steps'].any? { |step| step['state'] == 'running' } && current }
      owner = journal['steps'].first['owner']
      Process.kill('KILL', pid); Process.waitpid(pid)
      wait_for { Maintenance::ProcessGroup.members(owner['pgid']).empty? }
      recovery = Maintenance::Recovery.new(store)
      assert(recovery.recover(journal['id'], action: 'stop')['state'] == 'quiescent')
      result = JSON.parse(File.read(store.path(journal['id'], '.result.json')))
      assert(result['state'] == 'inconclusive' && result['reason'] == 'coordinator_interrupted')
      assert(recovery.cleanup(journal['id'], apply: true, discard: true)['state'] == 'cleaned')
    end
  end

  test('cleanup failure is retryable and cannot rewrite the original check result') do
    fixture do |_root, _source, _adapter, store, executor|
      id = executor.run['run_id']; recovery = Maintenance::Recovery.new(store)
      original = File.binread(store.path(id, '.result.json'))
      singleton = FileUtils.singleton_class
      singleton.alias_method(:executor_original_remove, :remove_entry_secure)
      once = true
      singleton.define_method(:remove_entry_secure) do |path, *args|
        if once && path.end_with?('/work/baseline')
          once = false
          File.unlink(File.join(path, '.resource-owner.json'))
          raise Errno::ENOTEMPTY, 'fixture interrupted cleanup'
        end
        executor_original_remove(path, *args)
      end
      begin
        assert(recovery.cleanup(id, apply: true, discard: true)['state'] == 'cleanup_failed')
        assert(recovery.cleanup(id, apply: true, discard: true)['state'] == 'cleaned')
        assert(File.binread(store.path(id, '.result.json')) == original)
        events = File.read(store.path(id, '.events.jsonl'))
        assert(events.include?('cleanup_failed') && events.include?('resource_removed'))
      ensure
        singleton.alias_method(:remove_entry_secure, :executor_original_remove)
        singleton.remove_method(:executor_original_remove)
      end
    end
  end

  test('different runs can execute concurrently without sharing copies or leases') do
    fixture do |root, source, adapter, store, _executor|
      children = 2.times.map do |index|
        fork do
          result = Maintenance::Executor.new(source: source, adapter: adapter, store: store, policy: policy).run
          File.write(File.join(root, "result-#{index}.json"), JSON.generate(result)); exit! 0
        end
      end
      children.each { |pid| _, status = Process.wait2(pid); assert(status.success?) }
      results = 2.times.map { |i| JSON.parse(File.read(File.join(root, "result-#{i}.json"))) }
      assert(results.all? { |result| result['state'] == 'checks_passed' })
      assert(results.map { |result| result['run_id'] }.uniq.size == 2)
      source.verify!
    end
  end

  test('changed external policy or executable bytes invalidate captured input identity') do
    fixture do |root, source, adapter, store, _executor|
      path = File.join(root, 'external-policy.json'); File.write(path, '{}')
      executor = Maintenance::Executor.new(source: source, adapter: adapter, store: store, policy: policy, input_files: [path])
      File.write(path, '[]')
      result = executor.run
      assert(result['state'] == 'refused' && result['steps'].empty?)
    end
  end

  test('symlink inputs and directory replacement cannot redirect cleanup') do
    fixture do |root, source, _adapter, store, executor|
      File.symlink('/etc/hosts', File.join(source.root, 'escape'))
      reject(/symlink unsupported/) { Maintenance::Source.new(source.root) }
      File.unlink(File.join(source.root, 'escape'))
      id = executor.run['run_id']
      outside = File.join(root, 'outside'); Dir.mkdir(outside)
      original = store.root + '-saved'; File.rename(store.root, original); File.symlink(outside, store.root)
      reject(/store identity changed/) { Maintenance::Recovery.new(store).cleanup(id, apply: true, discard: true) }
      assert(Dir.children(outside).empty?)
      File.unlink(store.root); File.rename(original, store.root)
    end
  end

  test('an unmarked resource prevents deletion of otherwise valid workspaces') do
    fixture do |_root, _source, _adapter, store, executor|
      id = executor.run['run_id']; journal = store.load(id)
      path = File.join(journal['root'], 'unowned'); Dir.mkdir(path)
      journal['resources'] << { 'type' => 'directory', 'path' => 'unowned', 'disposable' => true, 'state' => 'planned' }
      store.save(journal)
      reject(/Resource identity mismatch/) { Maintenance::Recovery.new(store).cleanup(id, apply: true, discard: true) }
      assert(File.directory?(File.join(journal['root'], 'work/baseline')) && File.directory?(path))
    end
  end

  test('policy bounds and incomplete adapter schema reject before allocation') do
    fixture do |_root, source, adapter, store, _executor|
      reject(/execution policy/) { Maintenance::Executor.new(source: source, adapter: adapter, store: store, policy: policy.merge('outer_timeout_seconds' => 0)) }
      adapter.plan.delete('scope')
      reject(/adapter protocol/) { Maintenance::Executor.new(source: source, adapter: adapter, store: store, policy: policy) }
      assert(Dir.children(store.root) == ['.mobi-run-store.json'])
    end
  end

  test('source and identity inspection ignore inherited Git configuration and trace paths') do
    fixture do |root, source, adapter, store, _executor|
      trace = File.join(root, 'unowned-trace')
      saved = ENV['GIT_TRACE']
      begin
        ENV['GIT_TRACE'] = trace
        captured = Maintenance::Source.new(source.root)
        result = Maintenance::Executor.new(source: captured, adapter: adapter, store: store, policy: policy).run
        assert(result['state'] == 'checks_passed' && !File.exist?(trace))
      ensure
        saved.nil? ? ENV.delete('GIT_TRACE') : ENV['GIT_TRACE'] = saved
      end
    end
  end

  def self.run
    failures = []
    @tests.each do |name, block|
      block.call
      puts "PASS #{name}"
    rescue StandardError => error
      failures << name
      warn "FAIL #{name}: #{error.class}: #{error.message}"
    end
    puts "#{@tests.size} executor tests, #{failures.size} failures"
    exit(failures.empty? ? 0 : 1)
  end
end

ExecutorTest.run if $PROGRAM_NAME == __FILE__
