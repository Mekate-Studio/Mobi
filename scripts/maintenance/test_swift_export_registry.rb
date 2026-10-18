# frozen_string_literal: true

require 'minitest/autorun'
require 'rbconfig'
require_relative 'lib/swift_export/registry'

class SwiftExportRegistryTest < Minitest::Test
  S = Maintenance::SwiftExport
  def setup
    @temporary = Dir.mktmpdir('mobi-export-registry-test-', '/private/tmp')
    @registry = S::Registry.create(File.join(@temporary, 'registry'), logical_bytes: 1_000_000, minimum_age_seconds: 0)
    @children = []
  end

  def teardown
    @children.each do |pid|
      Process.kill('KILL', -pid) rescue Errno::ESRCH
      Process.wait(pid) rescue Errno::ECHILD
    end
    FileUtils.remove_entry_secure(@temporary)
  end

  # Synthetic protocol data proves registry safety, never native qualification.
  def delivery(revision)
    path = File.join(@temporary, SecureRandom.hex(8)); Dir.mkdir(path)
    members = %w[KotlinCoroutineSupport.swift KotlinRuntimeSupport.swift ExportedKotlinPackages.swift libNative.a Aliases.swift kotlin_runtime/KotlinBase.h kotlin_runtime/module.modulemap NativeProducts/MapLibre.framework/MapLibre NativeProducts/M.o NativeProducts/macros/M NativeSources/App.swift NativeResources/R.bundle/Info.plist App.plist Assets.xcassets/Contents.json offline.json]
    members.each do |p|
      target = File.join(path, p); FileUtils.mkdir_p(File.dirname(target)); File.write(target, revision.to_s)
    end
    names = %w[KotlinCoroutineSupport KotlinRuntimeSupport ExportedKotlinPackages]
    graph = { 'schema' => 1, 'consumer_mode' => '6', 'input_identity' => 'a' * 64, 'profile' => 'coroutine-swift5', 'repository_policy' => 'main-confined',
              'modules' => names.map { |n| { 'name' => n, 'kind' => 'swift', 'swift' => n + '.swift', 'dependencies' => [] } }, 'expected_modules' => names,
              'module_modes' => names.to_h { |n| [n, n == 'KotlinCoroutineSupport' ? '5' : '6'] }, 'archive' => 'libNative.a', 'archive_sha256' => Maintenance.file_sha(File.join(path, 'libNative.a')),
              'aliases' => 'Aliases.swift', 'runtime_headers' => 'kotlin_runtime', 'provenance' => { 'kotlin' => { 'fixture' => true }, 'native' => { 'fixture' => true } },
              'native' => { 'sources' => ['NativeSources/App.swift'], 'macros' => ['NativeProducts/macros/M'], 'products' => ['NativeProducts/M.o', 'NativeProducts/MapLibre.framework'], 'resources' => ['NativeResources/R.bundle'], 'plist' => 'App.plist', 'assets' => 'Assets.xcassets', 'offline_style' => 'offline.json' } }
    graph['expected_members'] = (S::Delivery.files(path).keys + ['graph.json']).sort
    File.write(File.join(path, 'graph.json'), JSON.generate(graph)); S::Delivery.seal(path)
    path
  end

  def publish(revision, expected)
    @registry.publish(@registry.stage(delivery(revision)), expected: expected)
  end

  def test_exact_inventory_corruption_executable_and_symlink_refusal
    path = delivery(1); identity = S::Delivery.verify(path)
    File.write(File.join(path, 'stale.swift'), 'old API')
    assert_raises(Maintenance::Failure) { S::Delivery.verify(path) }
    File.unlink(File.join(path, 'stale.swift'))
    File.chmod(0o700, File.join(path, 'Aliases.swift'))
    assert_raises(Maintenance::Failure) { S::Delivery.verify(path) }
    File.chmod(0o644, File.join(path, 'Aliases.swift'))
    assert_equal identity, S::Delivery.verify(path)
    File.symlink('/private/tmp', File.join(path, 'escape'))
    assert_raises(Maintenance::Failure) { S::Delivery.verify(path) }
  end

  def test_fencing_aba_and_report_first_collection
    first = publish(1, 0)
    publish(2, 1)
    publish(1, 2) # Same bytes are a new generation.
    before = @registry.current
    assert_raises(Maintenance::Failure) { publish(3, 1) }
    assert_equal before, @registry.current
    report = @registry.report
    assert_equal [first['object']], report['objects'].reject { |o| o['eligible'] }.map { |o| o['object'] }
    result = @registry.collect(report)
    assert_equal 1, result['deleted'].size
    assert_equal first['object'], @registry.current['object']
  end

  def test_killed_writer_before_and_after_pointer_commit
    publish(1, 0)
    %w[object_installed pointer_installed].each_with_index do |event, index|
      read, write = IO.pipe
      payload = @registry.stage(delivery(index + 2))
      pid = fork do
        read.close
        @registry.publish(payload, expected: 1, checkpoint: ->(stage) { if stage == event; write.write('ready'); write.flush; sleep 300; end })
        exit! 2
      end
      write.close
      begin
        Timeout.timeout(5) { assert_equal 'ready', read.read(5) }
        Process.kill('KILL', pid); assert_equal 9, Process.wait2(pid).last.termsig
      ensure
        Process.kill('KILL', pid) rescue Errno::ESRCH
        Process.wait(pid) rescue Errno::ECHILD
        read.close
      end
      assert_equal index == 0 ? 1 : 2, @registry.current['generation']
      assert_equal @registry.current['object'], S::Delivery.verify(File.join(@registry.root, 'objects', @registry.current['object']))
    end
  end

  def test_concurrent_writers_have_one_winner
    publish(1, 0)
    payloads = [2, 3].map { |r| @registry.stage(delivery(r)) }
    pids = payloads.map do |payload|
      fork do
        begin; @registry.publish(payload, expected: 1); exit! 0
        rescue Maintenance::Failure; exit! 23; end
      end
    end
    assert_equal [0, 23], pids.map { |pid| Process.wait2(pid).last.exitstatus }.sort
    assert_equal 2, @registry.current['generation']
  end

  def reader(mode = 'hold')
    store = Maintenance::RunStore.new(File.join(@temporary, 'runs'))
    run_id = SecureRandom.hex(16)
    store.lock(run_id) { store.allocate(run_id, {}, {}) }
    output = File.join(@temporary, 'reader-' + run_id); Dir.mkdir(output)
    nonce = SecureRandom.hex(16)
    pid = Process.spawn(RbConfig.ruby, File.join(__dir__, 'fixtures/swift-export/reader.rb'), nonce, @registry.root, store.root, run_id, output, mode, pgroup: true, out: File.join(output, 'log'), err: [:child, :out])
    @children << pid
    begin
      Timeout.timeout(5) { sleep 0.01 until File.exist?(File.join(output, 'ready.json')) }
    rescue Timeout::Error
      raise File.read(File.join(output, 'log'))
    end
    pin = JSON.parse(File.read(File.join(output, 'ready.json')))['pin']
    [pid, pin, output]
  end

  def test_live_and_killed_readers_protect_old_deliveries_and_stale_reports
    old = publish(1, 0)
    stale = @registry.report
    pid, pin, output = reader
    assert_raises(Maintenance::Failure) { @registry.collect(stale) }
    publish(2, 1)
    assert_raises(Maintenance::Failure) { @registry.collect(stale) }
    assert_raises(Maintenance::Failure) { @registry.recover(pin['id']) }
    assert_equal [], @registry.collect(@registry.report)['deleted']
    File.write(File.join(output, 'release'), 'go')
    assert Process.wait2(pid).last.success?; @children.delete(pid)
    assert_equal old['object'], JSON.parse(File.read(File.join(output, 'done.json')))['identity']
    assert_equal [old['object']], @registry.collect(@registry.report)['deleted']
    pid, pin, = reader
    publish(3, 2)
    Process.kill('KILL', pid); Process.wait(pid); @children.delete(pid)
    assert_equal [], @registry.collect(@registry.report)['deleted']
    assert_equal 'positive_resource_quiescence', @registry.recover(pin['id'])['recovery']
    assert_equal [pin['object']], @registry.collect(@registry.report)['deleted']
  end

  def test_uncertain_owners_corruption_evidence_and_capacity_fail_closed
    old = publish(1, 0); publish(2, 1)
    @registry.reference('kept-evidence', old['object'], 'evidence')
    assert_equal [], @registry.collect(@registry.report)['deleted']
    pid, pin, = reader
    file = File.join(@registry.root, 'readers', pin['id'] + '.json')
    altered = JSON.parse(File.read(file)); altered['owner']['start'] = 'unknown identity'
    Maintenance::RunStore.atomic(file, altered)
    assert_raises(Maintenance::Failure) { @registry.recover(pin['id']) }
    assert_raises(Maintenance::Failure) { @registry.collect(@registry.report) }
    File.write(File.join(@registry.root, 'references', 'uncertain.json'), '{}')
    assert_raises(Maintenance::Failure) { @registry.collect(@registry.report) }
    File.unlink(File.join(@registry.root, 'references', 'uncertain.json'))
    active = @registry.current
    archive = File.join(@registry.root, 'objects', active['object'], 'libNative.a')
    File.write(archive, 'corruption')
    assert_raises(Maintenance::Failure) { @registry.collect(@registry.report) }
    assert_raises(Maintenance::Failure) { publish(3, 2) }
    assert_equal active, @registry.current
  end

  def test_exhausted_storage_does_not_evict_protected_objects
    active = publish(1, 0)
    Maintenance::RunStore.atomic(File.join(@registry.root, 'policy.json'), 'logical_payload_byte_limit' => 1, 'minimum_age_seconds' => 0)
    assert_raises(Maintenance::Failure) { publish(2, 1) }
    assert_equal active, @registry.current
    assert_equal [], @registry.collect(@registry.report)['deleted']
  end

  def test_descendant_survives_leader_and_blocks_recovery
    publish(1, 0)
    pid, pin, output = reader('descendant')
    assert Process.wait2(pid).last.success?
    @children.delete(pid)
    child = JSON.parse(File.read(File.join(output, 'descendant.json')))
    begin
      assert_equal 'uncertain_descendants', @registry.reader(pin['id'])['state']
      assert_raises(Maintenance::Failure) { @registry.recover(pin['id']) }
    ensure
      live = Maintenance::ProcessGroup.identity(child['pid'])
      assert %w[pid uid pgid start].all? { |key| child[key] == live[key] } && live['command'].split.include?(child['nonce'])
      Process.kill('KILL', child['pid'])
      Timeout.timeout(5) { sleep 0.01 while Maintenance::ProcessGroup.identity(child['pid']) }
    end
    assert_equal 'positive_resource_quiescence', @registry.recover(pin['id'])['recovery']
  end

  def test_age_and_retained_run_references_protect_objects
    old = publish(1, 0); publish(2, 1)
    Maintenance::RunStore.atomic(File.join(@registry.root, 'policy.json'), 'logical_payload_byte_limit' => 1_000_000, 'minimum_age_seconds' => 3600)
    assert_equal [], @registry.collect(@registry.report)['deleted']
    Maintenance::RunStore.atomic(File.join(@registry.root, 'policy.json'), 'logical_payload_byte_limit' => 1_000_000, 'minimum_age_seconds' => 0)
    store = Maintenance::RunStore.new(File.join(@temporary, 'evidence-runs'))
    id = SecureRandom.hex(16)
    store.lock(id) { store.allocate(id, {}, {}) }
    third = @registry.publish(@registry.stage(delivery(3)), expected: 2, retained_run: { 'store' => store.root, 'run_id' => id })
    publish(4, 3)
    report = @registry.report
    assert_equal ['retained-run'], report['objects'].find { |o| o['object'] == third['object'] }['reasons']
    assert_includes @registry.collect(report)['protected'], third['object']
    File.unlink(store.path(id, '.json'))
    assert_raises(Maintenance::Failure) { @registry.collect(@registry.report) }
    assert File.directory?(File.join(@registry.root, 'objects', third['object']))
  end

  def test_partial_staging_never_becomes_selected
    active = publish(1, 0)
    path = File.join(@registry.root, 'pending', SecureRandom.hex(16))
    read, write = IO.pipe
    pid = fork do
      read.close; Dir.mkdir(path); File.write(File.join(path, 'part.swift'), 'partial')
      write.write('ready'); write.flush; sleep 300
    end
    write.close
    begin
      Timeout.timeout(5) { assert_equal 'ready', read.read(5) }
      Process.kill('KILL', pid); Process.wait(pid)
      assert_equal active, @registry.current
      assert_raises(Maintenance::Failure) { @registry.publish(path, expected: 1) }
      assert_equal active, @registry.current
    ensure
      Process.kill('KILL', pid) rescue Errno::ESRCH
      Process.wait(pid) rescue Errno::ECHILD
      read.close
    end
  end

  def test_disposable_registry_requires_owning_run_binding
    store = Maintenance::RunStore.new(File.join(@temporary, 'scratch-runs'))
    id = SecureRandom.hex(16); journal = store.allocate(id, {}, {})
    workspace = store.directory(journal, 'work/baseline')
    path = File.join(workspace, 'registry')
    assert_raises(Maintenance::Failure) { S::Registry.create(path, logical_bytes: 1_000_000, minimum_age_seconds: 0) }
    assert !File.exist?(path)
    registry = S::Registry.create(path, logical_bytes: 1_000_000, minimum_age_seconds: 0, run: { 'store' => store.root, 'run_id' => id })
    assert_equal 0, registry.current['generation']
  end
end
