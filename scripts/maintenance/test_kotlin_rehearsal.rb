# frozen_string_literal: true

ROOT = File.expand_path('../..', __dir__)
require File.join(ROOT, 'scripts/maintenance/adapters/kotlin_rehearsal')
require File.join(ROOT, 'scripts/maintenance/lib/kotlin_evidence')
require File.join(ROOT, 'scripts/maintenance/lib/recovery')
require File.join(ROOT, 'scripts/maintenance/kotlin_check')

module KotlinRehearsalTest
  @tests = []
  def self.test(name, &block); @tests << [name, block]; end
  def self.assert(value, message = 'assertion failed'); raise message unless value; end
  def self.reject(pattern)
    yield
    raise 'Expected rejection'
  rescue Maintenance::Failure => error
    assert(error.message.match?(pattern), error.message)
  end
  def self.wait_for(seconds = 15)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
    loop do
      value = yield
      return value if value
      raise 'Fixture wait timed out' if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      sleep 0.05
    end
  end
  def self.wrapper_fixture
    Dir.mktmpdir('mobi-kotlin-wrappers-test-') do |root|
      _, status = Open3.capture2e('/usr/bin/git', 'init', '-q', root); assert(status.success?)
      File.write(File.join(root, '.gitignore'), ".maintenance/\n")
      pins = JSON.parse(File.read(File.join(ROOT, 'maintenance-kotlin-toolchains.json')))
      # Preserve the historical upgrade scenario independently of the adopted baseline.
      pins['baseline'] = '0.11.1'; pins['candidates'] = ['0.12.2']; pins.delete('target_policy')
      bytes = {}
      pins['versions'].each do |version, pin|
        pin['wrappers'].each do |name, item|
          body = "#!/bin/sh\n# caf\u00e9 fixture\nkotlin_cli_version=#{version}\nkotlin_cli_sha256=#{pin['distribution_sha256']}\n"
          body = body.gsub("\n", "\r\n") if name.end_with?('.bat')
          bytes[[version, name]] = body
          item['sha256'] = Digest::SHA256.hexdigest(body)
        end
      end
      File.write(File.join(root, 'maintenance-kotlin-toolchains.json'), JSON.pretty_generate(pins))
      FileUtils.cp(File.join(ROOT, 'maintenance-policy.json'), root)
      wrappers = Maintenance::KotlinWrappers.new(root)
      FileUtils.mkdir_p(wrappers.slot)
      Maintenance::RunStore.atomic(File.join(wrappers.slot, '.owner.json'), { 'identity' => Maintenance.digest(pins) })
      bytes.each do |(version, name), body|
        path = wrappers.wrapper(version, name); FileUtils.mkdir_p(File.dirname(path)); File.write(path, body)
      end
      %w[kotlin kotlin.bat].each do |name|
        File.write(File.join(root, name), bytes[[pins['baseline'], name]].gsub("\r\n", "\n"))
      end
      File.chmod(0o755, File.join(root, 'kotlin'))
      yield root, wrappers
    end
  end

  test('reviewed wrappers require exact bytes and an owned non-symlink installation') do
    wrapper_fixture do |_root, wrappers|
      assert(wrappers.verify!)
      file = wrappers.wrapper('0.12.2', 'kotlin')
      File.write(file, 'corrupt')
      reject(/bytes changed/) { wrappers.verify! }
    end
    wrapper_fixture do |_root, wrappers|
      file = wrappers.wrapper('0.12.2', 'kotlin')
      original = File.read(file); File.unlink(file)
      other = File.join(File.dirname(wrappers.slot), 'outside'); File.write(other, original)
      File.symlink(other, file)
      reject(/bytes changed/) { wrappers.verify! }
    end
  end

  test('unknown and too-young candidates refuse before rehearsal') do
    wrapper_fixture do |_root, wrappers|
      reject(/Unreviewed/) { wrappers.candidate!('9.9.9') }
      published = Time.iso8601(wrappers.pins['versions']['0.12.2']['published_at'])
      reject(/age threshold/) { wrappers.candidate!('0.12.2', now: published + 6 * 86_400) }
      assert(wrappers.candidate!('0.12.2', now: published + 7 * 86_400) == '0.12.2')
    end
  end

  test('LF-normalized wrappers yield a stable UTF-8 plan and only declared candidate edits') do
    wrapper_fixture do |root, _wrappers|
      source = Maintenance::Source.new(root)
      adapter = Maintenance::KotlinRehearsal.new(root, source: source, candidate: '0.12.2', profile: 'inputs')
      assert(adapter.plan == JSON.parse(JSON.generate(adapter.plan)))
      assert(adapter.plan['edits'].map { |edit| edit['path'] } == %w[kotlin kotlin.bat])
      assert(adapter.plan['missing_capabilities'].include?('native_builds'))
      assert(adapter.plan['resource_types'] == %w[filesystem process-group])
      source.verify!
    end
  end

  test('modified caller baseline cannot silently become a candidate comparison') do
    wrapper_fixture do |root, _wrappers|
      File.write(File.join(root, 'kotlin'), 'different source')
      reject(/reviewed baseline/) { Maintenance::KotlinRehearsal.new(root, source: Maintenance::Source.new(root), candidate: '0.12.2', profile: 'inputs') }
    end
  end

  def self.target_fixture(root)
    FileUtils.cp(File.join(ROOT, 'project.yaml'), root)
    %w[android-app ios-app].concat(Maintenance::KotlinTargets::MODULES).each do |name|
      FileUtils.mkdir_p(File.join(root, name))
      FileUtils.cp(File.join(ROOT, name, 'module.yaml'), File.join(root, name))
      if Maintenance::KotlinTargets::MODULES.include?(name)
        path = File.join(root, name, 'module.yaml')
        File.write(path, File.read(path).sub('platforms: [android, iosArm64, iosSimulatorArm64]', 'platforms: [android, iosArm64, iosSimulatorArm64, iosX64]'))
      end
    end
    bridge = Maintenance::KotlinTargets::BRIDGE
    FileUtils.mkdir_p(File.dirname(File.join(root, bridge)))
    FileUtils.cp(File.join(ROOT, bridge), File.join(root, bridge))
    path = File.join(root, bridge)
    content = File.read(path)
    unless content.include?('iosX64()')
      content = content.sub("    iosArm64()", "    iosX64()\n    iosArm64()")
      block = Maintenance::KotlinTargets::X64_SOURCE_SET.lines.map { |line| line.strip.empty? ? line : '        ' + line }.join
      content = content.sub('        val iosArm64Main by getting', block + '        val iosArm64Main by getting')
      File.write(path, content)
    end
  end

  test('explicit Apple Silicon candidate changes eight files and preserves ARM source mappings and caller state') do
    wrapper_fixture do |root, _wrappers|
      target_fixture(root)
      source = Maintenance::Source.new(root)
      adapter = Maintenance::KotlinRehearsal.new(root, source: source, candidate: '0.12.2', profile: 'inputs', target_policy: 'apple-silicon')
      edits = adapter.plan['edits']
      assert(edits.size == 8)
      bridge = edits.find { |edit| edit['path'] == Maintenance::KotlinTargets::BRIDGE }.fetch('content')
      assert(!bridge.include?('iosX64'))
      assert(bridge.include?('iosArm64()') && bridge.include?('iosSimulatorArm64()'))
      assert(bridge.scan('"../../shared-core/src@ios"').size == 2)
      assert(bridge.include?('val commonTest by getting') && bridge.include?('alias(libs.plugins.skie)'))
      assert(!adapter.plan['missing_capabilities'].include?('intel_linux_hosted_execution'))
      assert(adapter.plan['missing_capabilities'].include?('cold_hosted_execution'))
      assert(adapter.plan['scope'].end_with?('_apple_silicon'))
      source.verify!
    end
  end

  test('unknown target policy and changed or additional target declarations require review') do
    wrapper_fixture do |root, _wrappers|
      target_fixture(root)
      reject(/Unknown Kotlin target/) { Maintenance::KotlinTargets.edits(Maintenance::Source.new(root), 'anything') }
      file = File.join(root, Maintenance::KotlinTargets::BRIDGE)
      File.write(file, File.read(file).sub('val iosX64Main', 'val renamedMain'))
      reject(/declaration changed/) { Maintenance::KotlinTargets.edits(Maintenance::Source.new(root), 'apple-silicon') }
      target_fixture(root)
      module_file = File.join(root, 'shared-core/module.yaml')
      File.write(module_file, File.read(module_file).sub(', iosX64', ', macosX64, iosX64'))
      reject(/declaration changed/) { Maintenance::KotlinTargets.edits(Maintenance::Source.new(root), 'apple-silicon') }
      target_fixture(root)
      project = File.join(root, 'project.yaml')
      data = YAML.safe_load(File.read(project)); data['modules'] << 'new-library'
      File.write(project, YAML.dump(data))
      FileUtils.mkdir_p(File.join(root, 'new-library'))
      FileUtils.cp(module_file, File.join(root, 'new-library/module.yaml'))
      reject(/module coverage changed/) { Maintenance::KotlinTargets.edits(Maintenance::Source.new(root), 'apple-silicon') }
    end
  end

  test('candidate graph must cover both ARM targets with test scopes and exclude Intel') do
    roots = (Maintenance::KotlinTargets::MODULES + ['ios-app']).product(%w[iosArm64 iosSimulatorArm64], %w[main test], %w[compile runtime]).map do |name, platform, usage, scope|
      { 'module' => name, 'platforms' => [platform], 'usage' => usage, 'scope' => scope }
    end
    assert(Maintenance::KotlinTargets.verify_graphs!('graphs' => roots))
    reject(/missing a required ARM/) { Maintenance::KotlinTargets.verify_graphs!('graphs' => roots.drop(1)) }
    reject(/Intel iOS target remains/) { Maintenance::KotlinTargets.verify_graphs!('graphs' => roots + [roots[0].merge('platforms' => ['iosX64'])]) }
  end

  def self.settings(version)
    api = version == '0.11.1' ? '36' : "\n      apiLevel: 36"
    "Module: app\n\nsettings@android:\n  android:\n    compileSdk: #{api}\n    minSdk: 23\n  kotlin:\n    version: #{version == '0.11.1' ? '2.3.21' : '2.4.10'}\n"
  end
  def self.graph
    "Dependencies of module app:\n\n" + %w[main test].product(%w[COMPILE RUNTIME]).map do |usage, scope|
      "Module app\n\u2502 - #{usage}\n\u2502 - scope = #{scope}\n\u2502 - platforms = [android]\n\u251c\u2500\u2500\u2500 g:library:1.0 -> 2.0\n\u2502    \u2570\u2500\u2500\u2500 g:transitive:3.0 (*)\n\u2570\u2500\u2500\u2500 app:android:g:implicit:4.0, implicit\n\n"
    end.join
  end

  test('effective settings preserve version-specific scalar and structured Android SDK values') do
    %w[0.11.1 0.12.2].each do |version|
      result = Maintenance::KotlinEvidence.settings(settings(version), modules: ['app'], version: version)
      sdk = result['app']['settings@android']['android']['compileSdk']
      assert(version == '0.11.1' ? sdk == 36 : sdk == { 'apiLevel' => 36 })
    end
    reject(/coverage differs/) { Maintenance::KotlinEvidence.settings(settings('0.12.2'), modules: %w[app missing], version: '0.12.2') }
    reject(/Unsupported/) { Maintenance::KotlinEvidence.settings(settings('0.12.2'), modules: ['app'], version: '9.9.9') }
  end

  test('graphs retain main/test scopes, requested/selected versions, edges and repeated branches') do
    result = Maintenance::KotlinEvidence.graphs(graph, modules: ['app'], version: '0.12.2')
    roots = result['graphs']; assert(roots.size == 4)
    assert(roots[0]['nodes'][0]['coordinate'] == { 'group' => 'g', 'name' => 'library', 'requested' => '1.0', 'selected' => '2.0' })
    assert(roots[0]['nodes'][1]['repeated'])
    assert(roots[0]['edges'][1] == { 'from' => 0, 'to' => 1 })
    assert(!roots[0]['nodes'][2].key?('coordinate'), 'implicit request node misreported as an artifact')
  end

  test('missing test graphs, malformed metadata and unresolved nodes cannot produce complete coverage') do
    reject(/Missing main\/test/) { Maintenance::KotlinEvidence.graphs(graph.gsub("\u2502 - test", "\u2502 - main"), modules: ['app'], version: '0.12.2') }
    reject(/Unknown dependency graph metadata/) { Maintenance::KotlinEvidence.graphs(graph.sub('scope = COMPILE', 'unknown = COMPILE'), modules: ['app'], version: '0.12.2') }
    reject(/Unresolved/) { Maintenance::KotlinEvidence.graphs(graph.sub('g:library:1.0', 'FAILED g:library:1.0'), modules: ['app'], version: '0.12.2') }
  end

  test('network and ambiguous exits remain inconclusive while attributable compilation failures are distinct') do
    assert(Maintenance::KotlinEvidence.classify('Compilation failed', 1) == 'failed')
    assert(Maintenance::KotlinEvidence.classify('Compilation failed: Connection reset', 1) == 'infrastructure')
    assert(Maintenance::KotlinEvidence.classify('No available iOS simulator', 1) == 'missing')
    assert(Maintenance::KotlinEvidence.classify('Unknown failure', 1) == 'infrastructure')
    unsupported = 'ERROR: Platform iosX64 is not supported by the library org.jetbrains.compose.foundation:foundation:1.11.1'
    assert(Maintenance::KotlinEvidence.classify(unsupported, 1) == 'failed')
    assert(Maintenance::KotlinEvidence.classify(unsupported, 0) == 'failed')
    assert(Maintenance::KotlinEvidence.classify(unsupported + ' Connection reset', 1) == 'infrastructure')
  end

  test('a tool mutating authored inputs in the generated copy is refused despite exit zero') do
    Dir.mktmpdir('mobi-kotlin-source-test-') do |root|
      %w[source output cache home tmp control].each { |name| Dir.mkdir(File.join(root, name)) }
      source = File.join(root, 'source')
      File.write(File.join(source, 'project.yaml'), "modules: [app]\n")
      File.write(File.join(source, 'kotlin'), "#!/bin/sh\nkotlin_cli_version=0.11.1\necho changed > project.yaml\necho 'Kotlin Toolchain version 0.11.1 (fixture)'\n")
      File.chmod(0o755, File.join(source, 'kotlin'))
      host = File.join(root, 'host.json'); File.write(host, JSON.generate('ruby' => RbConfig.ruby))
      previous = ENV.to_h
      begin
        ENV.replace('PATH' => '/usr/bin:/bin', 'HOME' => File.join(root, 'home'), 'TMPDIR' => File.join(root, 'tmp'),
                    'MOBI_PHASE' => 'baseline', 'MOBI_RESULT_PATH' => File.join(root, 'control/check.json'))
        check = Maintenance::KotlinCheck.new(source, File.join(root, 'output'), File.join(root, 'cache'), host, 'inputs')
        assert(check.run == 'refused', check.report.inspect)
        assert(File.read(File.join(source, 'project.yaml')) == "modules: [app]\n")
      ensure
        ENV.replace(previous)
      end
    end
  end

  def self.resource_fixture
    Dir.mktmpdir('mobi-kotlin-resource-test-') do |root|
      store = Maintenance::RunStore.new(File.join(root, 'runs')); id = SecureRandom.hex(16)
      journal = store.allocate(id, {}, {})
      workspace = store.directory(journal, 'work/baseline')
      control = store.directory(journal, 'steps/native', disposable: false)
      nonce = SecureRandom.hex(16)
      Maintenance::KotlinResources.prepare(control: control, workspace: workspace, nonce: nonce)
      yield Maintenance::KotlinResources.new(control, nonce), workspace
    end
  end

  test('detached owned process is observed and bounded even when TERM is ignored') do
    resource_fixture do |handler, _workspace|
      pid = Process.spawn(RbConfig.ruby, '-e', 'trap("TERM") {}; sleep 60', '--', handler.tag, pgroup: true, out: File::NULL, err: File::NULL)
      begin
        wait_for { handler.jvms.any? { |current| current['pid'] == pid } }
        handler.observe!
        observed = JSON.parse(File.read(File.join(handler.control, 'observed-jvms.json')))
        assert(observed.any? { |current| current['pid'] == pid })
        handler.stop!; Process.wait(pid)
        assert(handler.quiescent?)
      ensure
        Process.kill('KILL', pid) rescue Errno::ESRCH
        Process.wait(pid) rescue Errno::ECHILD
      end
    end
  end

  test('an unrelated live registry PID cannot be signaled or classified as owned') do
    resource_fixture do |handler, _workspace|
      registry = File.join(handler.state['gradle_home'], 'daemon', 'fixture'); FileUtils.mkdir_p(registry)
      File.write(File.join(registry, "daemon-#{Process.pid}.out.log"), 'unowned')
      reject(/Unowned live process/) { handler.stop! }
      diagnostic = JSON.parse(File.read(File.join(handler.control, 'unowned-jvm.json')))
      assert(diagnostic.dig('identity', 'pid') == Process.pid && diagnostic['from_registry'] && !diagnostic['from_process_scan'])
      assert(Maintenance::ProcessGroup.identity(Process.pid))
    end
  end

  test('argv loss during JVM exit is rechecked without granting registry ownership') do
    resource_fixture do |handler, _workspace|
      registry = File.join(handler.state['gradle_home'], 'daemon', 'fixture'); FileUtils.mkdir_p(registry)
      File.write(File.join(registry, "daemon-#{Process.pid}.out.log"), 'exit fixture')
      original = Maintenance::ProcessGroup.method(:identity)
      exiting = original.call(Process.pid).merge('command' => '(java)'); observations = 0
      begin
        Maintenance::ProcessGroup.define_singleton_method(:identity) do |pid|
          next original.call(pid) unless pid == Process.pid
          observations += 1
          observations <= 2 ? exiting : nil
        end
        assert(handler.jvms.empty?)
        assert(observations == 3)
      ensure
        Maintenance::ProcessGroup.define_singleton_method(:identity, original)
      end
      assert(original.call(Process.pid), 'fixture process was signaled')
    end
  end

  test('reused unowned identity after argv loss still refuses cleanup') do
    resource_fixture do |handler, _workspace|
      registry = File.join(handler.state['gradle_home'], 'daemon', 'fixture'); FileUtils.mkdir_p(registry)
      File.write(File.join(registry, "daemon-#{Process.pid}.out.log"), 'reuse fixture')
      original = Maintenance::ProcessGroup.method(:identity)
      exiting = original.call(Process.pid).merge('command' => '(java)'); observations = 0
      begin
        Maintenance::ProcessGroup.define_singleton_method(:identity) do |pid|
          next original.call(pid) unless pid == Process.pid
          observations += 1
          observations == 1 ? exiting : original.call(pid)
        end
        reject(/Unowned live process/) { handler.stop! }
        assert(observations == 6)
      ensure
        Maintenance::ProcessGroup.define_singleton_method(:identity, original)
      end
      assert(original.call(Process.pid), 'unowned process was signaled')
    end
  end

  test('Tooling API daemon ownership uses an exact private classpath when JVM options are replaced') do
    resource_fixture do |handler, workspace|
      jar = File.join(handler.state['gradle_home'], 'wrapper/dists/gradle-8-bin/fixture/gradle-8/lib/gradle-daemon-main-8.jar')
      FileUtils.mkdir_p(File.dirname(jar)); File.write(jar, 'fixture artifact')
      pid = Process.spawn(RbConfig.ruby, '-e', 'trap("TERM") {}; sleep 60', '--', '-cp', jar, 'org.gradle.launcher.daemon.bootstrap.GradleDaemon', pgroup: true, out: File::NULL, err: File::NULL)
      begin
        owner = wait_for { handler.jvms.find { |current| current['pid'] == pid } }
        assert(owner['ownership_proof']['kind'] == 'owned_gradle_classpath')
        assert(owner['ownership_proof']['sha256'] == Maintenance.file_sha(jar))
        handler.stop!; Process.wait(pid)
        assert(handler.quiescent?)
        outside = File.join(File.dirname(workspace), 'outside.jar'); File.write(outside, 'unowned')
        File.unlink(jar); File.symlink(outside, jar)
        identity = { 'uid' => Process.uid, 'command' => "java -cp #{jar} org.gradle.launcher.daemon.bootstrap.GradleDaemon 8" }
        assert(handler.ownership_proof(identity).nil?, 'symlinked classpath authorized ownership')
      ensure
        Process.kill('KILL', pid) rescue Errno::ESRCH
        Process.wait(pid) rescue Errno::ECHILD
      end
    end
  end

  test('unconfirmed simulator creation cannot authorize workspace deletion') do
    resource_fixture do |handler, _workspace|
      data = handler.state; data['simulator'] = 'creation_planned'; handler.save(data)
      handler.define_singleton_method(:devices) { [] }
      assert(!handler.quiescent?)
      reject(/creation is unconfirmed/) { handler.stop! }
    end
  end

  test('simulator mismatch refuses cleanup and an owned simulator is shut down and deleted precisely') do
    resource_fixture do |handler, _workspace|
      state = handler.state; state.merge!('simulator' => 'created', 'runtime' => 'fixture-runtime', 'device_id' => 'owned-id'); handler.save(state)
      fake = [{ 'name' => state['device_name'], 'runtime' => 'foreign-runtime', 'udid' => 'owned-id', 'state' => 'Shutdown' }]
      handler.define_singleton_method(:devices) { fake }
      reject(/ownership uncertain/) { handler.stop! }
      fake[0].merge!('runtime' => 'fixture-runtime', 'state' => 'Booted')
      calls = []
      handler.define_singleton_method(:simctl) do |*args|
        calls << args
        fake[0]['state'] = 'Shutdown' if args[0] == 'shutdown'
        fake.clear if args[0] == 'delete'
        ''
      end
      handler.stop!
      assert(calls == [['shutdown', 'owned-id'], ['delete', 'owned-id']])
      assert(handler.quiescent?)
    end
  end

  test('Xcode clones are owned by exact nonce names and runtime; unrelated devices remain intact') do
    resource_fixture do |handler, _workspace|
      state = handler.state; state.merge!('simulator' => 'created', 'runtime' => 'fixture-runtime', 'device_id' => 'owned-id'); handler.save(state)
      fake = [
        { 'name' => state['device_name'], 'runtime' => 'fixture-runtime', 'udid' => 'owned-id', 'state' => 'Shutdown' },
        { 'name' => 'Clone 1 of ' + state['device_name'], 'runtime' => 'fixture-runtime', 'udid' => 'clone-id', 'state' => 'Booted' },
        { 'name' => 'Personal iPhone', 'runtime' => 'fixture-runtime', 'udid' => 'unrelated-id', 'state' => 'Booted' }
      ]
      calls = []
      handler.define_singleton_method(:simctl) do |*args|
        if args[0] == 'list'
          JSON.generate('devices' => fake.group_by { |device| device['runtime'] })
        else
          calls << args
          fake.find { |device| device['udid'] == args[1] }['state'] = 'Shutdown' if args[0] == 'shutdown'
          fake.reject! { |device| device['udid'] == args[1] } if args[0] == 'delete'
          ''
        end
      end
      assert(handler.devices.size == 2 && !handler.quiescent?)
      fake[1]['runtime'] = 'foreign-runtime'
      reject(/ownership uncertain/) { handler.stop! }
      fake[1]['runtime'] = 'fixture-runtime'
      fake[1]['name'] = 'Unrecognized clone of ' + state['device_name']
      reject(/ownership uncertain/) { handler.stop! }
      fake[1]['name'] = 'Clone 1 of ' + state['device_name']
      handler.save(state.merge('device_name' => 'Personal iPhone'))
      reject(/owner mismatch/) { handler.state }
      handler.save(state)
      handler.stop!
      assert(calls == [['shutdown', 'clone-id'], ['delete', 'clone-id'], ['delete', 'owned-id']])
      assert(fake.map { |device| device['udid'] } == ['unrelated-id'])
      assert(handler.quiescent?)
    end
  end

  test('workspace identity drift prevents native recovery') do
    resource_fixture do |handler, workspace|
      File.write(File.join(workspace, '.resource-owner.json'), '{}')
      reject(/ownership changed/) { handler.stop! }
    end
  end

  def self.native_fixture(scenario, timeout: 20)
    Dir.mktmpdir('mobi-native-integration-test-') do |root|
      input = File.join(root, 'input'); Dir.mkdir(input)
      _, status = Open3.capture2e('/usr/bin/git', 'init', '-q', input); assert(status.success?)
      File.write(File.join(input, 'dependency.txt'), '1')
      script = File.join(root, 'check.rb')
      File.write(script, <<~'CHECK')
        require 'json'; require 'rbconfig'
        control = File.dirname(ENV.fetch('MOBI_RESULT_PATH'))
        tag = '-Dmobi.maintenance.owner=' + ENV.fetch('MOBI_RESOURCE_NONCE')
        pid = Process.spawn(RbConfig.ruby, '-e', 'trap("TERM") {}; sleep 90', '--', tag, pgroup: true, out: File::NULL, err: File::NULL)
        Process.detach(pid)
        File.write(File.join(control, 'detached.pid'), pid.to_s)
        sleep 90 if ARGV.include?('barrier')
        File.write(ENV.fetch('MOBI_RESULT_PATH'), JSON.generate('schema' => 1, 'check' => 'native', 'phase' => ENV.fetch('MOBI_PHASE'), 'status' => 'passed'))
      CHECK
      adapter = Struct.new(:plan, :code_files).new({ 'schema' => 1, 'id' => 'native-contract', 'scope' => 'synthetic-native-lifecycle',
        'missing_capabilities' => ['native_builds'], 'resource_types' => %w[filesystem process-group kotlin-native], 'edits' => [],
        'checks' => [{ 'id' => 'native', 'required' => true, 'timeout_seconds' => timeout, 'argv' => [RbConfig.ruby, script, scenario] }] },
        [script, File.join(ROOT, 'scripts/maintenance/adapters/kotlin_resources.rb')])
      store = Maintenance::RunStore.new(File.join(root, 'runs'))
      policy = JSON.parse(File.read(File.join(ROOT, 'maintenance-execution-policy.json')))
      executor = Maintenance::Executor.new(source: Maintenance::Source.new(input), adapter: adapter, store: store, policy: policy)
      yield store, executor
    end
  end

  test('executor waits for detached resource cleanup after normal and timed-out checks') do
    [['pass', 20, 'checks_passed'], ['barrier', 1, 'inconclusive']].each do |scenario, timeout, expected|
      native_fixture(scenario, timeout: timeout) do |store, executor|
        result = executor.run
        assert(result['state'] == expected, result.inspect)
        journal = store.load(result['run_id'])
        journal['steps'].each do |step|
          pid = File.read(File.join(journal['root'], step['path'], 'detached.pid')).to_i
          assert(Maintenance::ProcessGroup.identity(pid).nil?, 'detached process survived')
        end
        assert(Maintenance::Recovery.new(store).recover(result['run_id'])['state'] == 'quiescent')
      end
    end
  end

  test('coordinator loss watchdog cleans detached resources and recovery preserves interruption') do
    native_fixture('barrier') do |store, executor|
      pid = fork { executor.run; exit! 0 }
      begin
        marker = wait_for { Dir.glob(File.join(store.root, '*', 'steps', 'baseline-native', 'detached.pid')).first }
        orphan = File.read(marker).to_i
        id = marker.delete_prefix(store.root + '/').split('/').first
        Process.kill('KILL', pid); Process.wait(pid)
        wait_for { Maintenance::ProcessGroup.identity(orphan).nil? }
        wait_for do
          owner = store.load(id)['steps'][0]['owner']
          owner && Maintenance::ProcessGroup.identity(owner['pid']).nil?
        end
        recovery = Maintenance::Recovery.new(store).recover(id, action: 'stop')
        assert(recovery['state'] == 'quiescent' && recovery['recorded_outcome'] == 'inconclusive', recovery.inspect)
      ensure
        Process.kill('KILL', pid) rescue Errno::ESRCH
        Process.wait(pid) rescue Errno::ECHILD
      end
    end
  end

  test('minimum-major simulator selection never falls back to the newest installed runtime') do
    resource_fixture do |handler, _workspace|
      runtime26 = { 'identifier' => 'com.apple.CoreSimulator.SimRuntime.iOS-26-5', 'version' => '26.5', 'isAvailable' => true, 'supportedDeviceTypes' => [{ 'identifier' => 'fixture-type' }] }
      runtime27 = { 'identifier' => 'com.apple.CoreSimulator.SimRuntime.iOS-27-0', 'version' => '27.0', 'isAvailable' => true }
      created = []
      handler.define_singleton_method(:simctl) do |*args|
        case args.first(2)
        when ['list', 'runtimes'] then JSON.generate('runtimes' => [runtime27, runtime26])
        when ['list', 'devicetypes'] then JSON.generate('devicetypes' => [{ 'name' => 'iPhone unsupported', 'identifier' => 'newest-type' }, { 'name' => 'iPhone fixture', 'identifier' => 'fixture-type' }])
        else
          created << args
          '00000000-0000-0000-0000-000000000001'
        end
      end
      handler.define_singleton_method(:devices) { [] }
      handler.create_simulator!(File.dirname(RbConfig.ruby), major: 26)
      assert(created.size == 1 && created.first.last == runtime26['identifier'] && created.first[-2] == 'fixture-type')
      assert(handler.state['runtime'] == runtime26['identifier'])
    end
    resource_fixture do |handler, _workspace|
      handler.define_singleton_method(:simctl) do |*args|
        raise 'unexpected mutation' unless args.first == 'list'
        JSON.generate(args[1] == 'runtimes' ? { 'runtimes' => [] } : { 'devicetypes' => [] })
      end
      reject(/required major 26/) { handler.create_simulator!(File.dirname(RbConfig.ruby), major: 26) }
      assert(handler.state['simulator'] == 'not_created')
    end
  end

  failures = 0
  @tests.each do |name, block|
    begin
      block.call
      puts "PASS #{name}"
    rescue StandardError => error
      failures += 1
      warn "FAIL #{name}: #{error.class}: #{error.message}"
    end
  end
  puts "#{@tests.size} Kotlin rehearsal tests, #{failures} failures"
  exit(failures.zero? ? 0 : 1)
end
