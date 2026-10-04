# frozen_string_literal: true

require_relative 'adapters/kotlin_watch'
require_relative 'lib/watch_history'
require_relative 'watch_cli'
require 'stringio'

module WatchTest
  ROOT = File.expand_path('../..', __dir__)
  NOW = Time.now.utc
  @tests = []
  def self.test(name, &block); @tests << [name, block]; end
  def self.assert(value, message = 'assertion failed'); raise message unless value; end
  def self.reject(pattern)
    yield
    raise 'Expected refusal'
  rescue Maintenance::Failure => error
    assert(error.message.match?(pattern), error.message)
  end
  def self.config; Maintenance::Compatibility.new(ROOT).config; end
  def self.release(version = '99.0.0', age: 10)
    { 'tag_name' => 'v' + version, 'published_at' => (NOW - age * 86_400).iso8601, 'draft' => false, 'prerelease' => false }
  end
  class Fetcher
    attr_accessor :data, :error, :bad_hash
    attr_reader :calls
    def initialize(data); @data = data; @calls = []; end
    def get(url, token: nil)
      @calls << [url, token]
      raise Maintenance::Failure, @error if @error
      body = JSON.generate(@data)
      { 'url' => url, 'retrieved_at' => Time.now.utc.iso8601, 'body' => body, 'sha256' => @bad_hash ? '0' * 64 : Digest::SHA256.hexdigest(body) }
    end
  end
  def self.probe(id = 'a' * 32, status: 'passed', state: 'checks_passed')
    [{ 'run_id' => id, 'state' => state, 'reason' => 'named_checks_passed', 'result_sha256' => id * 2, 'adoption_authorized' => false,
       'phases' => %w[baseline candidate].map { |phase| { 'phase' => phase, 'cells' => { 'native_library_compile' => { 'status' => 'passed' }, 'framework_link' => { 'status' => phase == 'candidate' ? status : 'passed' } } } } }, 'cleaned']
  end
  def self.fixture
    Dir.mktmpdir('mobi-watch-test-') do |root|
      Maintenance::Source.new(ROOT).copy_to(root)
      _, status = Open3.capture2e('/usr/bin/git', 'init', '-q', root); assert(status.success?)
      yield root
    end
  end
  def self.run_watch(root, **options)
    watcher = Maintenance::CompatibilityWatch.new(root, fetcher: Fetcher.new([release]), probe: ->(_source) { probe }, **options)
    [watcher.run, watcher.output]
  end

  test('first observation is explicit and a repeated semantic result stays quiet across run IDs') do
    fixture do |root|
      source = Maintenance::Source.new(root)
      first, output = run_watch(root)
      observation = first.dig('snapshot', 'observation', 'capability_observations').first
      assert(observation['state'] == 'documented_not_rehearsed' && observation['missing_capabilities'].include?('swiftpm_execution'))
      assert(File.read(File.join(output, 'summary.md')).include?('swiftpm_objective_c_visible_api_import_into_kotlin'))
      assert(first['notification']['notify'] && first.dig('notification', 'continuity') == 'initial')
      watcher = Maintenance::CompatibilityWatch.new(root, previous: File.join(output, 'snapshot.json'), fetcher: Fetcher.new([release]), probe: ->(_source) { probe('b' * 32) })
      second = watcher.run
      assert(!second['notification']['notify'], second['notification'].inspect)
      assert(second.dig('snapshot', 'observation', 'assessment_state') == 'checks_passed')
      assert(second['adoption_authorized'] == false && second['bridge_retirement'] == 'defer')
      assert(second.dig('snapshot', 'observation', 'missing_capabilities').include?('native_tests'))
      source.verify!
      io = StringIO.new; Maintenance::Watch.announce(second, io: io); assert(io.string.empty?)
    end
  end

  test('same-scope passing and failing cells identify improvement and regression') do
    old = Maintenance::Watch.snapshot({}, { 'native_state' => 'incompatible', 'matrix' => { 'candidate/framework_link' => 'failed' } })
    current = Maintenance::Watch.snapshot({}, { 'native_state' => 'checks_passed', 'matrix' => { 'candidate/framework_link' => 'passed' } })
    result = Maintenance::Watch.compare(current, old, continuity: 'restored')
    assert(result['changes'].any? { |c| c['kind'] == 'capability_improved' })
    result = Maintenance::Watch.compare(old, current, continuity: 'restored')
    assert(result['changes'].any? { |c| c['kind'] == 'capability_regressed' })
    missing = Maintenance::Watch.snapshot({}, { 'native_state' => 'inconclusive', 'matrix' => { 'candidate/framework_link' => 'not_attempted' } })
    result = Maintenance::Watch.compare(missing, current, continuity: 'restored')
    assert(result['changes'].none? { |c| c['kind'] == 'capability_regressed' })
  end

  test('missing corrupt expired future and changed-scope history cannot suppress notifications') do
    Dir.mktmpdir('mobi-watch-history-') do |root|
      file = File.join(root, 'snapshot.json'); now = Time.now.utc
      assert(Maintenance::Watch.previous(file, {})[1] == 'missing')
      File.write(file, '{'); assert(Maintenance::Watch.previous(file, {})[1] == 'invalid')
      data = Maintenance::Watch.snapshot({}, {}, now: now - 32 * 86_400); File.write(file, JSON.generate(data))
      assert(Maintenance::Watch.previous(file, {}, now: now)[1] == 'expired')
      data = Maintenance::Watch.snapshot({}, {}, now: now + 60); File.write(file, JSON.generate(data))
      assert(Maintenance::Watch.previous(file, {}, now: now)[1] == 'invalid_time')
      data = Maintenance::Watch.snapshot({ 'tuple' => 'old' }, {}); File.write(file, JSON.generate(data))
      assert(Maintenance::Watch.previous(file, { 'tuple' => 'new' })[1] == 'scope_changed')
      data['observation']['forged'] = true; File.write(file, JSON.generate(data))
      assert(Maintenance::Watch.previous(file, data['scope'])[1] == 'invalid')
      data = Maintenance::Watch.snapshot({}, {}).merge('recorded_at' => nil)
      data['sha256'] = Maintenance.digest(data.reject { |key, _| key == 'sha256' }); File.write(file, JSON.generate(data))
      assert(Maintenance::Watch.previous(file, {})[1] == 'invalid')
      result = Maintenance::Watch.compare({}, nil, continuity: 'invalid')
      assert(result['notify'] && result['changes'].first['kind'] == 'comparison_unavailable')
    end
  end

  test('release evidence preserves age blocks major changes source identities and no adoption') do
    fetcher = Fetcher.new([release, release('98.0.0', age: 2), release('100.0.0').merge('prerelease' => true), release('101.0.0-RC1')])
    result = Maintenance::KotlinReleaseWatch.new(fetcher: fetcher).discover(config)
    assert(result.keys.sort == %w[kotlin metro skie toolchain])
    result.each_value do |provider|
      assert(provider['state'] == 'observed' && provider['source']['sha256'].size == 64)
      assert(provider['newer'].map { |r| r['age_state'] } == %w[age_blocked eligible_for_review])
      assert(provider['newer'].all? { |r| r['major_change'] })
    end
    assert(fetcher.calls.all? { |_url, token| token.nil? })
  end

  test('rate limits malformed releases missing dates future releases and digest mismatch are incomplete') do
    fetcher = Fetcher.new([]); fetcher.error = 'provider_http_403'
    [fetcher, Fetcher.new({}), Fetcher.new([release.reject { |key, _| key == 'published_at' }]), Fetcher.new([release(age: -1)])].each do |provider|
      result = Maintenance::KotlinReleaseWatch.new(fetcher: provider).discover(config)
      assert(result.values.all? { |r| r['state'] == 'incomplete' && r['reason'] })
    end
    fetcher = Fetcher.new([release]); fetcher.bad_hash = true
    assert(Maintenance::KotlinReleaseWatch.new(fetcher: fetcher).discover(config).values.all? { |r| r['reason'] == 'provider_evidence_mismatch' })
  end

  test('optional public-provider authentication stays out of reports') do
    fetcher = Fetcher.new([release])
    result = Maintenance::KotlinReleaseWatch.new(fetcher: fetcher, token: 'fixture-secret').discover(config)
    assert(fetcher.calls.size == 4 && fetcher.calls.all? { |_url, token| token == 'fixture-secret' })
    assert(!JSON.generate(result).include?('fixture-secret'))
  end

  test('provider failure remains incomplete with a passing probe and unchanged failure is quiet') do
    fixture do |root|
      fetcher = Fetcher.new([]); fetcher.error = 'provider_http_429'
      watcher = Maintenance::CompatibilityWatch.new(root, fetcher: fetcher, probe: ->(_source) { probe })
      first = watcher.run
      assert(first['operation_state'] == 'observation_recorded')
      assert(first.dig('snapshot', 'observation', 'assessment_state') == 'incomplete')
      assert(Maintenance::Watch.summary(first).include?('Unknown: provider evidence is incomplete'))
      next_watch = Maintenance::CompatibilityWatch.new(root, previous: File.join(watcher.output, 'snapshot.json'), fetcher: fetcher, probe: ->(_source) { probe })
      assert(!next_watch.run['notification']['notify'])
    end
  end

  test('newly eligible releases and resolved provider gaps generate meaningful deltas') do
    before = Maintenance::Watch.snapshot({}, { 'releases' => { 'skie' => { 'state' => 'incomplete', 'newer' => [] } } })
    after = Maintenance::Watch.snapshot({}, { 'releases' => { 'skie' => { 'state' => 'observed', 'newer' => [{ 'version' => '1.0.0', 'age_state' => 'eligible_for_review' }] } } })
    result = Maintenance::Watch.compare(after, before, continuity: 'restored')
    assert(result['notify'] && result['changes'].all? { |c| c['kind'] == 'release_evidence_changed' })
  end

  test('cleanup failure and unverified native evidence cannot produce a successful watch operation') do
    fixture do |root|
      watcher = Maintenance::CompatibilityWatch.new(root, fetcher: Fetcher.new([release]), probe: ->(_source) { [probe.first, 'ownership_uncertain'] })
      result = watcher.run
      assert(result['operation_state'] == 'failed' && result.dig('snapshot', 'observation', 'missing_capabilities').include?('watch_cleanup'))
      watcher = Maintenance::CompatibilityWatch.new(root, fetcher: Fetcher.new([release]), probe: ->(_source) { raise Maintenance::Failure, 'bad evidence' })
      assert(watcher.run['operation_state'] == 'failed')
      watcher = Maintenance::CompatibilityWatch.new(root, fetcher: Fetcher.new([release]), probe: ->(_source) { probe(state: 'refused') })
      assert(watcher.run['operation_state'] == 'failed')
    end
  end

  test('restoration provider failure is visible even when a previous file exists') do
    fixture do |root|
      _, output = run_watch(root)
      result, = run_watch(root, previous: File.join(output, 'snapshot.json'), history: 'incomplete')
      assert(result.dig('notification', 'continuity') == 'history_provider_unavailable')
      assert(result.dig('snapshot', 'observation', 'assessment_state') == 'incomplete')
    end
  end

  test('Actions history selects only this workflow branch and excludes the current run') do
    base = { 'id' => 20, 'run_number' => 2, 'run_attempt' => 1, 'head_branch' => 'main', 'status' => 'completed', 'path' => '.github/workflows/dependency-compatibility.yml', 'event' => 'schedule' }
    fetcher = Fetcher.new('workflow_runs' => [base, base.merge('id' => 30, 'run_number' => 3), base.merge('id' => 40, 'run_number' => 4, 'head_branch' => 'other')])
    result = Maintenance::WatchHistory.lookup(repository: 'owner/repo', branch: 'main', current_run: '30', token: 'fixture', fetcher: fetcher)
    assert(result == { 'state' => 'found', 'run_id' => '20' })
    assert(fetcher.calls.first.last == 'fixture')
    fetcher.data = { 'workflow_runs' => [base.reject { |key, _| key == 'status' }] }
    assert(Maintenance::WatchHistory.lookup(repository: 'owner/repo', branch: 'main', current_run: '30', token: nil, fetcher: fetcher)['state'] == 'incomplete')
    fetcher.error = 'provider_http_403'
    assert(Maintenance::WatchHistory.lookup(repository: 'owner/repo', branch: 'main', current_run: '30', token: nil, fetcher: fetcher)['state'] == 'incomplete')
  end

  test('HTTPS transport bounds requests and keeps credentials off argv and inherited environment') do
    calls = []
    status = Struct.new(:exitstatus) { def success?; exitstatus.zero?; end }
    runner = lambda do |*args, **options|
      calls << [args, options]
      ["[]\n200", '', status.new(0)]
    end
    client = Maintenance::WatchHTTP.new(runner: runner)
    response = client.get('https://api.github.com/repos/owner/repo/releases', token: 'fixture-token')
    args, options = calls.fetch(0)
    assert(args[1..2] == ['/usr/bin/curl', '--disable'])
    assert(args.include?('--max-time') && args.include?('--max-filesize') && !args.include?('--location') && !args.include?('--insecure'))
    assert(!args.inspect.include?('fixture-token') && options[:stdin_data].include?('Authorization: Bearer fixture-token'))
    assert(options[:unsetenv_others] && args.first.keys.sort == %w[LC_ALL PATH])
    assert(response['sha256'] == Digest::SHA256.hexdigest('[]') && response['transport_sha256'].size == 64)
    reject(/Unsupported/) { client.get('https://example.com/releases', token: 'fixture-token') }
    reject(/credential/) { client.get('https://api.github.com/releases', token: "bad\nheader") }
    [[0, "[]\n403", /http_403/], [0, "[]\n302", /http_302/], [28, '', /network_unavailable/], [63, '', /response_too_large/]].each do |code, output, pattern|
      failed = Maintenance::WatchHTTP.new(runner: ->(*_args, **_options) { [output, '', status.new(code)] })
      reject(pattern) { failed.get('https://api.github.com/releases') }
    end
  end

  test('watch output refuses existing paths symlinks and paths outside its ignored store') do
    fixture do |root|
      reject(/new directory/) { Maintenance::CompatibilityWatch.new(root, output: 'report.json') }
      FileUtils.mkdir_p(File.join(root, '.maintenance/watch-reports/existing'))
      reject(/new directory/) { Maintenance::CompatibilityWatch.new(root, output: '.maintenance/watch-reports/existing') }
      File.symlink(Dir.tmpdir, File.join(root, '.maintenance/watch-reports/link'))
      reject(/Symlinked/) { Maintenance::CompatibilityWatch.new(root, output: '.maintenance/watch-reports/link/new') }
    end
  end

  test('legacy arbitrary version overrides are refused before executing a watch') do
    key = 'SKIE_COMPAT_KOTLIN_VERSION'; old = ENV[key]
    begin
      ENV[key] = '99.0.0'
      reject(/Legacy SKIE_COMPAT/) { Maintenance::WatchCLI.call(ROOT, []) }
    ensure
      old ? ENV[key] = old : ENV.delete(key)
    end
  end

  test('existing workflow retains its trigger and uses one reviewed evaluator with read-only permissions') do
    workflow = YAML.safe_load(File.read(File.join(ROOT, '.github/workflows/dependency-compatibility.yml')))
    triggers = workflow['on'] || workflow[true]
    assert(triggers.keys.sort == %w[schedule workflow_dispatch])
    assert(triggers['schedule'] == [{ 'cron' => '23 5 * * 1' }])
    assert(workflow['permissions'].values.all? { |value| value == 'read' })
    assert(workflow['concurrency']['cancel-in-progress'] == false)
    shell = File.read(File.join(ROOT, 'scripts/ci/check_skie_kotlin_compatibility.sh'))
    assert(shell.include?('watch-compatibility') && !shell.include?('catalog_path'))
    uploads = workflow['jobs'].values.flat_map { |job| job['steps'] }.select { |step| step['uses'].to_s.start_with?('actions/upload-artifact') }
    assert(uploads.all? { |step| step['with']['include-hidden-files'] == true && step['with']['path'].start_with?('.maintenance/watch-reports/current') })
  end

  def self.run
    failures = 0
    @tests.each do |name, block|
      block.call; puts 'PASS ' + name
    rescue StandardError => error
      failures += 1; warn 'FAIL ' + name + ': ' + error.message; warn error.backtrace.first(4).join("\n")
    end
    puts "#{@tests.size} watch contracts, #{failures} failures"
    exit(failures.zero? ? 0 : 1)
  end
end
WatchTest.run if $PROGRAM_NAME == __FILE__
