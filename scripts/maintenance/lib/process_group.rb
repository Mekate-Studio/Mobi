# frozen_string_literal: true

require_relative 'core'
require 'socket'

module Maintenance
  module ProcessGroup
    def self.host
      Maintenance.digest([Socket.gethostname, Process.uid])
    end

    def self.identity(pid)
      raise Failure, 'Invalid process identifier' unless pid.is_a?(Integer) && pid > 1
      output, status = Open3.capture2({ 'LC_ALL' => 'C' }, '/bin/ps', '-ww', '-p', pid.to_s, '-o', 'uid=', '-o', 'pgid=', '-o', 'lstart=', '-o', 'stat=', '-o', 'command=', unsetenv_others: true)
      return nil if status.exitstatus == 1 && output.strip.empty?
      raise Failure, 'Process inspection unavailable' unless status.success?
      parts = output.strip.split(/\s+/, 9)
      raise Failure, 'Unsupported process identity format' unless parts.size == 9
      return nil if parts[7].start_with?('Z')
      { 'pid' => pid, 'uid' => Integer(parts[0]), 'pgid' => Integer(parts[1]), 'start' => parts[2..6].join(' '), 'command' => parts[8] }
    end

    def self.members(pgid)
      output, status = Open3.capture2({ 'LC_ALL' => 'C' }, '/bin/ps', '-axo', 'pid=,pgid=,stat=', unsetenv_others: true)
      raise Failure, 'Process group inspection unavailable' unless status.success?
      output.lines.map { |line| line.split }.select { |pid, group, state| pid && group.to_i == pgid && !state.start_with?('Z') }.map { |pid, _group, _state| pid.to_i }
    end

    def self.owned?(record, current)
      return false unless record.is_a?(Hash) && current && record['host'] == host && record['nonce'].to_s.match?(/\A[0-9a-f]{32}\z/)
      %w[pid uid pgid start].all? { |key| record[key] == current[key] } && current['uid'] == Process.uid &&
        current['pid'] == current['pgid'] && current['command'].split.include?(record['nonce'])
    end

    def self.stop(record, grace: 1)
      current = identity(record.fetch('pid'))
      if current.nil?
        raise Failure, 'Leader absent but group ownership unresolved' unless members(record.fetch('pgid')).empty?
        return 'absent'
      end
      raise Failure, 'Process ownership mismatch; no signal sent' unless owned?(record, current)
      Process.kill('TERM', -record.fetch('pgid'))
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + grace
      sleep 0.02 while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline && !members(record['pgid']).empty?
      unless members(record['pgid']).empty?
        # The supervisor deliberately stays alive on TERM, so ownership can be rechecked.
        raise Failure, 'Process identity changed during termination' unless owned?(record, identity(record['pid']))
        Process.kill('KILL', -record['pgid'])
      end
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 3
      until members(record['pgid']).empty?
        raise Failure, 'Owned process group did not stop' if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        sleep 0.02
      end
      'stopped'
    rescue Errno::ESRCH
      raise Failure, 'Process group ownership changed during termination' unless members(record['pgid']).empty?
      'absent'
    end
  end
end
