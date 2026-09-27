# frozen_string_literal: true

require_relative '../lib/run_store'

module Maintenance
  class KotlinResources
    attr_reader :control, :nonce

    def self.prepare(control:, workspace:, nonce:)
      raise Failure, 'Invalid native resource nonce' unless nonce.match?(RunStore::ID)
      marker = File.join(workspace, '.resource-owner.json')
      RunStore.atomic(File.join(control, 'native-resources.json'), {
        'schema' => 1, 'host' => ProcessGroup.host, 'nonce' => nonce,
        'workspace' => File.realpath(workspace), 'workspace_owner' => JSON.parse(File.read(marker)),
        'gradle_home' => File.join(File.realpath(workspace), 'cache', 'gradle'),
        'device_name' => 'Mobi Maintenance ' + nonce, 'simulator' => 'not_created', 'jvms' => []
      })
    end

    def initialize(control, nonce)
      @control, @nonce = control, nonce
      state # Validate before querying or signaling anything.
    end

    def state
      path = File.join(@control, 'native-resources.json')
      raise Failure, 'Missing native resource intent' unless File.file?(path) && !File.symlink?(path)
      data = JSON.parse(File.read(path))
      unless data['schema'] == 1 && data['host'] == ProcessGroup.host && data['nonce'] == @nonce && @nonce.match?(RunStore::ID) && data['device_name'] == 'Mobi Maintenance ' + @nonce
        raise Failure, 'Native resource owner mismatch'
      end
      work = data.fetch('workspace')
      raise Failure, 'Native resource root escaped phase' unless File.expand_path(work) == work && data['gradle_home'] == File.join(work, 'cache', 'gradle')
      if File.exist?(work)
        marker = File.join(work, '.resource-owner.json')
        unless File.realpath(work) == work && !File.symlink?(marker) && File.file?(marker) && JSON.parse(File.read(marker)) == data['workspace_owner']
          raise Failure, 'Native workspace ownership changed'
        end
      end
      data
    end

    def save(data)
      RunStore.atomic(File.join(@control, 'native-resources.json'), data)
    end

    def tag
      '-Dmobi.maintenance.owner=' + @nonce
    end

    def tagged?(identity)
      identity && identity['uid'] == Process.uid && identity['command'].split.include?(tag)
    end

    def ownership_proof(identity)
      return nil unless identity && identity['uid'] == Process.uid
      return { 'kind' => 'jvm_tag', 'nonce' => @nonce } if tagged?(identity)
      data = state
      return nil unless identity['command'].split.include?('org.gradle.launcher.daemon.bootstrap.GradleDaemon')
      # Toolchain's Tooling API replaces org.gradle.jvmargs. Its daemon still
      # executes from the private distribution rooted in this random run/phase.
      # Match a real classpath entry, not a PID or a broad process-name pattern.
      jars = Dir.glob(File.join(data['gradle_home'], 'wrapper/dists/*/*/gradle-*/lib/gradle-daemon-main-*.jar'))
      jars.each do |jar|
        next unless File.file?(jar) && File.realpath(jar) == jar && jar.start_with?(data['workspace'] + '/')
        if %w[-cp -classpath --class-path].any? { |flag| identity['command'].include?(" #{flag} #{jar} ") }
          return { 'kind' => 'owned_gradle_classpath', 'relative_path' => jar.delete_prefix(data['workspace'] + '/'), 'sha256' => Maintenance.file_sha(jar) }
        end
      end
      nil
    end

    def jvms
      data = state
      text, status = Open3.capture2({ 'LC_ALL' => 'C' }, '/bin/ps', '-ww', '-axo', 'pid=,command=', unsetenv_others: true)
      raise Failure, 'Native process inspection unavailable' unless status.success?
      tagged_ids = text.lines.map do |line|
        pid, command = line.strip.split(/\s+/, 2)
        next unless command
        args = command.split
        pid.to_i if args.include?(tag) || (args.include?('org.gradle.launcher.daemon.bootstrap.GradleDaemon') && command.include?(data['gradle_home'] + '/wrapper/dists/'))
      end.compact
      registry = File.join(data['gradle_home'], 'daemon')
      raise Failure, 'Symlinked Gradle resource' if [data['gradle_home'], registry].any? { |p| File.symlink?(p) }
      logs = Dir.glob(File.join(registry, '*', 'daemon-*.out.log'))
      registry_ids = logs.map do |path|
        raise Failure, 'Gradle registry escaped workspace' unless File.realpath(path).start_with?(data['workspace'] + '/') && !File.symlink?(path)
        Integer(File.basename(path)[/\Adaemon-(\d+)\.out\.log\z/, 1])
      end
      (tagged_ids + registry_ids).uniq.map do |pid|
        current = ProcessGroup.identity(pid)
        next unless current
        # A known completed identity does not authorize a newly reused PID.
        proof = ownership_proof(current)
        raise Failure, 'Unowned live process in private Gradle registry' unless proof
        current.merge('ownership_proof' => proof)
      end.compact
    end

    def stop_jvms!
      owners = jvms
      data = state; data['jvms'] = owners; save(data)
      owners.each do |owner|
        current = ProcessGroup.identity(owner['pid'])
        next unless current
        same = ->(live) { live && ownership_proof(live) == owner['ownership_proof'] && %w[pid uid pgid start].all? { |key| owner[key] == live[key] } }
        raise Failure, 'Native process identity changed; no signal sent' unless same.call(current)
        Process.kill('TERM', owner['pid'])
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 2
        sleep 0.05 while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline && ProcessGroup.identity(owner['pid'])
        current = ProcessGroup.identity(owner['pid'])
        if current
          raise Failure, 'Native process identity changed during termination' unless same.call(current)
          Process.kill('KILL', owner['pid'])
        end
      rescue Errno::ESRCH
        next
      end
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 3
      until jvms.empty?
        raise Failure, 'Native process did not stop' if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        sleep 0.05
      end
    end

    def observe!
      path = File.join(@control, 'observed-jvms.json')
      raise Failure, 'Symlinked native observation file' if File.symlink?(path)
      observations = File.file?(path) ? JSON.parse(File.read(path)) : []
      jvms.each do |current|
        observations << current unless observations.any? { |previous| %w[pid uid start].all? { |key| previous[key] == current[key] } }
      end
      RunStore.atomic(path, observations)
    end

    def simctl(*args)
      data = state
      env = { 'PATH' => '/usr/bin:/bin:/usr/sbin:/sbin', 'LC_ALL' => 'C', 'DEVELOPER_DIR' => data.fetch('developer_dir') }
      log = File.join(@control, 'simctl-' + SecureRandom.hex(6) + '.log')
      status = nil; pid = nil
      begin
        File.open(log, 'w') do |stream|
          # Keep simulator operations in the supervisor group. A killed check
          # must not leave an unrecorded detached simctl child creating devices.
          pid = Process.spawn(env, '/usr/bin/xcrun', 'simctl', *args, chdir: @control, unsetenv_others: true,
                              close_others: true, in: File::NULL, out: stream, err: [:child, :out])
          status = Timeout.timeout(30) { Process.wait2(pid).last }
        end
      ensure
        unless status || !pid
          Process.kill('KILL', pid) rescue Errno::ESRCH
          Process.wait(pid) rescue Errno::ECHILD
        end
      end
      raise Failure, 'Simulator resource operation failed; inspect retained log' unless status.success?
      File.read(log, encoding: 'UTF-8')
    end

    def devices
      data = state
      return [] if %w[not_created removed].include?(data['simulator'])
      JSON.parse(simctl('list', 'devices', '--json')).fetch('devices').flat_map do |runtime, items|
        items.select { |device| device['name'].include?(data['device_name']) }.map { |device| device.merge('runtime' => runtime) }
      end
    end

    def create_simulator!(developer_dir, major: nil)
      data = state
      raise Failure, 'Simulator already allocated' unless data['simulator'] == 'not_created'
      data['developer_dir'] = File.realpath(developer_dir); save(data)
      runtime = JSON.parse(simctl('list', 'runtimes', '--json')).fetch('runtimes').select do |r|
        r['isAvailable'] && r.fetch('identifier', '').include?('.iOS-') && (major.nil? || r['version'].split('.').first.to_i == major)
      end.max_by { |r| r['version'].scan(/\d+/).map(&:to_i) }
      supported = runtime ? runtime.fetch('supportedDeviceTypes', []).map { |t| t.fetch('identifier') } : []
      type = JSON.parse(simctl('list', 'devicetypes', '--json')).fetch('devicetypes').find do |t|
        t['name'].start_with?('iPhone') && supported.include?(t['identifier'])
      end
      raise Failure, 'No available iOS simulator runtime/device type' + (major ? ' for required major ' + major.to_s : '') unless runtime && type
      data.merge!('runtime' => runtime['identifier'], 'device_type' => type['identifier'], 'simulator' => 'creation_planned'); save(data)
      id = simctl('create', data['device_name'], data['device_type'], data['runtime']).strip
      raise Failure, 'Invalid created simulator ID' unless id.match?(/\A[0-9A-Fa-f-]{36}\z/)
      data.merge!('simulator' => 'created', 'device_id' => id); save(data)
      verify_devices!(devices)
      id
    end

    def verify_devices!(found)
      data = state
      base = data['device_name']
      clones = /\AClone [1-9]\d* of #{Regexp.escape(base)}\z/
      # Xcode can create temporary test clones. The unique base-name intent
      # predates the test; reject unfamiliar names carrying that nonce instead
      # of silently declaring the run quiescent.
      uncertain = found.map { |d| d['name'] }.uniq.size != found.size || found.any? do |device|
        device['runtime'] != data['runtime'] ||
          (device['name'] == base ? data['device_id'] && device['udid'] != data['device_id'] : !device['name'].match?(clones))
      end
      raise Failure, 'Simulator ownership uncertain' if uncertain
      found.sort_by { |device| device['name'] == base ? 1 : 0 } # Remove clones first.

    end

    def stop!
      # The coordinator stops the process group first so no new JVM/device can
      # be created after this final ownership scan.
      stop_jvms!
      found = verify_devices!(devices)
      raise Failure, 'Simulator creation is unconfirmed; retain resources for inspection' if state['simulator'] == 'creation_planned' && found.none? { |device| device['name'] == state['device_name'] }
      RunStore.atomic(File.join(@control, 'observed-simulators.json'), found) unless found.empty?
      found.each do |device|
        simctl('shutdown', device['udid']) unless device['state'] == 'Shutdown'
        verify_devices!(devices)
        simctl('delete', device['udid'])
      end
      raise Failure, 'Owned simulator did not disappear' unless devices.empty?
      data = state; data['simulator'] = 'removed' unless data['simulator'] == 'not_created'; data['jvms'] = []; save(data)
    end

    def quiescent?
      return false if state['simulator'] == 'creation_planned'
      jvms.empty? && verify_devices!(devices).empty?
    end
  end
end
