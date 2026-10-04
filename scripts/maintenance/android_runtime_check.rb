# frozen_string_literal: true
require_relative 'lib/executor'
require 'timeout'
include Maintenance
source, output, cache, host_file = ARGV
host = JSON.parse(File.read(host_file)); control = File.dirname(ENV.fetch('MOBI_RESULT_PATH'))
phase = ENV.fetch('MOBI_PHASE'); nonce = ENV.fetch('MOBI_RESOURCE_NONCE')
report = { 'schema' => 1, 'phase' => phase, 'scope' => 'android_api_36_install_launch_smoke', 'commands' => [], 'adoption_authorized' => false }
children = []; status = 'infrastructure'; env = ENV.to_h.merge('PATH' => '/usr/bin:/bin:/usr/sbin:/sbin')
begin
  sdk = host.fetch('sdk'); apk = host.fetch('apks').fetch(phase)
  raise Failure, 'Producer APK changed' unless Maintenance.file_sha(apk['path']) == apk['sha256']
  adb = File.join(sdk, 'platform-tools/adb'); emulator = File.join(sdk, 'emulator/emulator')
  %w[adb emulator].each { |key| raise Failure, 'Runtime tool changed' unless Maintenance.file_sha(key == 'adb' ? adb : emulator) == host.fetch(key + '_sha256') }
  image = File.join(sdk, 'system-images/android-36/google_apis/arm64-v8a')
  raise Failure, 'API 36 image changed' unless Maintenance.file_sha(File.join(image, 'source.properties')) == host.fetch('image_sha256')
  reserve = TCPServer.new('127.0.0.1', 0); adb_port = reserve.addr[1]; reserve.close
  ports = (5554..5584).step(2).find do |port|
    handles = []
    begin
      handles << TCPServer.new('127.0.0.1', port); handles << TCPServer.new('127.0.0.1', port + 1); true
    rescue Errno::EADDRINUSE
      false
    ensure
      handles.each(&:close)
    end
  end
  raise Failure, 'No free emulator port pair' unless ports
  avds = File.join(cache, 'avds'); name = 'mobi_' + nonce; avd = File.join(avds, name + '.avd'); FileUtils.mkdir_p(avd)
  env.merge!('ANDROID_HOME' => sdk, 'ANDROID_SDK_ROOT' => sdk, 'ANDROID_USER_HOME' => File.join(cache, 'android'), 'ANDROID_EMULATOR_HOME' => File.join(cache, 'emulator'), 'ANDROID_AVD_HOME' => avds, 'ANDROID_ADB_SERVER_PORT' => adb_port.to_s, 'ADB_SERVER_SOCKET' => "tcp:127.0.0.1:#{adb_port}", 'ADB_VENDOR_KEYS' => File.join(cache, 'adb-keys'), 'ADB_MDNS_AUTO_CONNECT' => '')
  File.write(File.join(avds, name + '.ini'), "avd.ini.encoding=UTF-8\npath=#{avd}\ntarget=android-36\n")
  File.write(File.join(avd, 'config.ini'), "AvdId=#{name}\navd.ini.encoding=UTF-8\nabi.type=arm64-v8a\nhw.cpu.arch=arm64\nhw.cpu.ncore=2\nhw.ramSize=2048\nhw.lcd.width=1080\nhw.lcd.height=1920\nhw.lcd.density=420\nhw.keyboard=yes\nhw.gpu.enabled=yes\nhw.gpu.mode=swiftshader\nimage.sysdir.1=#{image}/\ntag.id=google_apis\ndisk.dataPartition.size=2G\n")
  report.merge!('producer_apk_sha256' => apk['sha256'], 'toolchain' => apk['version'], 'image_sha256' => host['image_sha256'], 'adb_port' => adb_port, 'emulator_port' => ports, 'avd_name' => name)
  RunStore.atomic(File.join(control, 'runtime-intent.json'), report)
  spawn_child = lambda do |label, argv|
    log = File.join(control, label + '.log')
    pid = File.open(log, 'w') { |stream| Process.spawn(env, *argv, unsetenv_others: true, in: File::NULL, out: stream, err: [:child, :out]) }
    identity = ProcessGroup.identity(pid)
    raise Failure, 'Runtime child escaped supervisor group' unless identity && identity['pgid'] == Process.getpgrp
    children << identity; RunStore.atomic(File.join(control, 'runtime-children.json'), children)
    pid
  end
  server = spawn_child.call('adb-server', [adb, '-L', "tcp:#{adb_port}", 'nodaemon', 'server'])
  Timeout.timeout(10) do
    loop do
      raise Failure, 'Private ADB server exited' if Process.waitpid(server, Process::WNOHANG)
      begin
        connection = TCPSocket.new('127.0.0.1', adb_port); connection.close; break
      rescue Errno::ECONNREFUSED
        sleep 0.2
      end
    end
  end
  device = spawn_child.call('emulator', [emulator, '-avd', name, '-ports', "#{ports},#{ports + 1}", '-no-window', '-no-audio', '-no-boot-anim', '-no-snapshot', '-gpu', 'swiftshader', '-no-metrics', '-no-direct-adb', '-adb-path', adb])
  serial = 'emulator-' + ports.to_s
  invoke = lambda do |label, *args|
    argv = [adb, '-H', '127.0.0.1', '-P', adb_port.to_s, '-s', serial] + args
    log = File.join(control, label + '.log'); code = nil
    File.open(log, 'w') do |stream|
      pid = Process.spawn(env, *argv, unsetenv_others: true, in: File::NULL, out: stream, err: [:child, :out])
      begin
        code = Timeout.timeout(60) { Process.wait2(pid).last.exitstatus }
      ensure
        unless code
          Process.kill('KILL', pid) rescue Errno::ESRCH
          Process.wait(pid) rescue Errno::ECHILD
        end
      end
    end
    report['commands'] << { 'check' => label, 'exit' => code, 'log_sha256' => Maintenance.file_sha(log) }
    raise Failure, 'Runtime command failed: ' + label unless code == 0
    File.read(log)
  end
  invoke.call('wait-device', 'wait-for-device')
  Timeout.timeout(180) do
    count = 0
    loop do
      raise Failure, 'Owned emulator exited' if Process.waitpid(device, Process::WNOHANG)
      break if invoke.call('boot-' + count.to_s, 'shell', 'getprop', 'sys.boot_completed').strip == '1'
      count += 1; sleep 2
    end
  end
  report['api_level'] = invoke.call('api-level', 'shell', 'getprop', 'ro.build.version.sdk').strip
  report['os_build'] = invoke.call('os-build', 'shell', 'getprop', 'ro.build.fingerprint').strip
  raise Failure, 'Runtime is not API 36' unless report['api_level'] == '36'
  invoke.call('install', 'install', '--no-streaming', apk['path'])
  package = invoke.call('package', 'shell', 'dumpsys', 'package', 'studio.mekate.mobi')
  report['sdk_declaration'] = package[/minSdk=\d+ targetSdk=\d+/]
  raise Failure, 'Installed minimum/target differs' unless report['sdk_declaration'] == 'minSdk=36 targetSdk=36'
  component = invoke.call('resolve', 'shell', 'cmd', 'package', 'resolve-activity', '--brief', 'studio.mekate.mobi').lines.map(&:strip).find { |line| line.start_with?('studio.mekate.mobi/') }
  raise Failure, 'No Mobi launcher' unless component
  invoke.call('grant-coarse', 'shell', 'pm', 'grant', 'studio.mekate.mobi', 'android.permission.ACCESS_COARSE_LOCATION')
  invoke.call('grant-fine', 'shell', 'pm', 'grant', 'studio.mekate.mobi', 'android.permission.ACCESS_FINE_LOCATION')
  invoke.call('synthetic-location', 'emu', 'geo', 'fix', '-122.084', '37.422')
  report['location_fixture'] = 'owned_emulator_precise_permission_synthetic_googleplex_coordinates'
  invoke.call('clear-log', 'logcat', '-c')
  launch = invoke.call('launch', 'shell', 'am', 'start', '-W', '-n', component)
  report['launch_wait_status'] = launch[/Status: (.+)/, 1]
  raise Failure, 'Launcher returned an error' if launch.include?('Error:')
  sleep 5
  invoke.call('ui-dump', 'shell', 'uiautomator', 'dump', '/sdcard/mobi-window.xml')
  ui = invoke.call('ui-tree', 'exec-out', 'cat', '/sdcard/mobi-window.xml')
  Timeout.timeout(60) do
    attempt = 0
    until ui.include?('package="studio.mekate.mobi"')
      sleep 2; attempt += 1
      invoke.call('ui-dump-retry-' + attempt.to_s, 'shell', 'uiautomator', 'dump', '/sdcard/mobi-window.xml')
      ui = invoke.call('ui-tree-retry-' + attempt.to_s, 'exec-out', 'cat', '/sdcard/mobi-window.xml')
    end
  end
  crashes = invoke.call('crash-log', 'logcat', '-d', '-b', 'crash')
  raise Failure, 'Runtime crash recorded' if crashes.include?('FATAL EXCEPTION') || crashes.include?('Fatal signal')
  report['ui_visible'] = true; report['crash_buffer'] = 'no_fatal_entry_during_bounded_smoke'; status = 'passed'
rescue StandardError => error
  report['failure'] = error.message; report['exception_class'] = error.class.name
  begin
    invoke.call('failure-crash-log', 'logcat', '-d', '-b', 'crash') if defined?(invoke) && invoke
  rescue StandardError
    report['failure_crash_capture'] = 'unavailable'
  end
ensure
  children.reverse_each do |owner|
    live = ProcessGroup.identity(owner['pid'])
    next unless live
    unless %w[uid pgid start].all? { |key| live[key] == owner[key] }
      status = 'infrastructure'; report['cleanup'] = 'identity_changed_retained'; next
    end
    Process.kill('TERM', owner['pid']) rescue Errno::ESRCH
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 3
    sleep 0.1 while ProcessGroup.identity(owner['pid']) && Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
    live = ProcessGroup.identity(owner['pid'])
    if live && %w[uid pgid start].all? { |key| live[key] == owner[key] }
      Process.kill('KILL', owner['pid']) rescue Errno::ESRCH
    end
    Process.wait(owner['pid']) rescue Errno::ECHILD
  end
  report['status'] = status
  RunStore.atomic(File.join(control, 'evidence.json'), report)
  RunStore.atomic(ENV.fetch('MOBI_RESULT_PATH'), { 'schema' => 1, 'check' => 'android-runtime', 'phase' => phase, 'status' => status, 'evidence_sha256' => Maintenance.file_sha(File.join(control, 'evidence.json')) })
end
exit(status == 'passed' ? 0 : 1)
