# frozen_string_literal: true

require_relative 'lib/run_store'

# This supervisor owns the group for its entire lifetime; it never execs a job.
control, nonce = ARGV
raise Maintenance::Failure, 'Invalid supervisor nonce' unless nonce.to_s.match?(Maintenance::RunStore::ID)
config = JSON.parse(File.read(File.join(control, 'command.json')))
started = Maintenance::ProcessGroup.identity(Process.pid).merge('nonce' => nonce, 'host' => Maintenance::ProcessGroup.host)
Maintenance::RunStore.atomic(File.join(control, 'started.json'), started)
trap('TERM') { } # Keep the leader available for the coordinator's final ownership check.
trap('INT') { }
clock = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
deadline = clock.call + config.fetch('lifetime_seconds')
owner = config.fetch('coordinator')
parent_alive = lambda do
  current = Maintenance::ProcessGroup.identity(owner['pid'])
  current && %w[uid pid pgid start].all? { |key| current[key] == owner[key] }
end
stop_self = lambda do
  # The supervisor can prove its own group without trusting persisted PIDs.
  Process.kill('TERM', -Process.getpgrp)
  sleep config.fetch('grace_seconds')
  Process.kill('KILL', -Process.getpgrp)
end
begin
  until File.file?(File.join(control, 'grant'))
    stop_self.call if clock.call >= deadline || !parent_alive.call
    sleep 0.02
  end
  raise Maintenance::Failure, 'Invalid supervisor grant' unless File.read(File.join(control, 'grant')) == nonce
  argv = config.fetch('argv')
  child = Process.spawn(config.fetch('env'), [argv.first, argv.first], *argv.drop(1), chdir: config.fetch('cwd'),
                        unsetenv_others: true, close_others: true, in: File::NULL,
                        out: File.join(control, 'stdout.log'), err: File.join(control, 'stderr.log'), umask: 0o077)
  status = nil
  until status
    pair = Process.wait2(child, Process::WNOHANG); status = pair && pair.last
    stop_self.call if clock.call >= deadline || !parent_alive.call
    sleep 0.02 unless status
  end
  Maintenance::RunStore.atomic(File.join(control, 'finished.json'), { 'schema' => 1, 'nonce' => nonce, 'exit' => status.exitstatus, 'signal' => status.termsig })
  loop do
    break if File.file?(File.join(control, 'release')) && File.read(File.join(control, 'release')) == nonce
    stop_self.call if clock.call >= deadline || !parent_alive.call
    sleep 0.02
  end
rescue StandardError => error
  Maintenance::RunStore.atomic(File.join(control, 'worker-error.json'), { 'schema' => 1, 'class' => error.class.name })
  stop_self.call
end
