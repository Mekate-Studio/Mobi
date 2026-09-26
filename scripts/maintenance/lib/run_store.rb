# frozen_string_literal: true

require_relative 'process_group'
require 'securerandom'

module Maintenance
  class RunStore
    ID = /\A[0-9a-f]{32}\z/
    attr_reader :root

    def self.atomic(path, value)
      raise Failure, 'Symlinked state file' if File.symlink?(path)
      temp = path + '.tmp-' + SecureRandom.hex(8)
      begin
        File.open(temp, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
          file.write(JSON.pretty_generate(value) + "\n"); file.flush; file.fsync
        end
        File.rename(temp, path)
      ensure
        File.unlink(temp) if File.exist?(temp)
      end
    end

    def initialize(path)
      path = File.expand_path(path)
      raise Failure, 'Symlinked run store' if File.symlink?(path) || File.symlink?(File.dirname(path))
      FileUtils.mkdir_p(File.dirname(path))
      @root = File.join(File.realpath(File.dirname(path)), File.basename(path))
      marker = File.join(@root, '.mobi-run-store.json')
      if Dir.exist?(@root)
        raise Failure, 'Unowned run store' unless File.file?(marker) && !File.symlink?(marker)
        owner = JSON.parse(File.read(marker))
        raise Failure, 'Run store host or owner mismatch' unless owner == store_owner
      else
        Dir.mkdir(@root, 0o700)
        self.class.atomic(marker, store_owner)
      end
    end

    def store_owner
      { 'schema' => 1, 'host' => ProcessGroup.host, 'uid' => Process.uid, 'root' => @root }
    end

    def verify_store!
      marker = File.join(@root, '.mobi-run-store.json')
      raise Failure, 'Run store identity changed' unless Dir.exist?(@root) && !File.symlink?(@root) && File.realpath(@root) == @root && File.file?(marker) && !File.symlink?(marker) && JSON.parse(File.read(marker)) == store_owner
    end

    def path(id, suffix = '')
      verify_store!
      raise Failure, 'Invalid run ID' unless id.is_a?(String) && id.match?(ID)
      File.join(@root, id + suffix)
    end

    def lock(id, create: true)
      lock_path = path(id, '.lock')
      raise Failure, 'Symlinked run lease' if File.symlink?(lock_path)
      raise Failure, 'Missing run lease' if !create && !File.file?(lock_path)
      File.open(lock_path, File::RDWR | (create ? File::CREAT : 0), 0o600) do |file|
        raise Failure, 'Run is active; lease held' unless file.flock(File::LOCK_EX | File::LOCK_NB)
        yield
      end
    end

    def save(journal)
      self.class.atomic(path(journal.fetch('id'), '.json'), journal)
    end

    def event(journal, name, details = {})
      target = path(journal.fetch('id'), '.events.jsonl')
      raise Failure, 'Symlinked event log' if File.symlink?(target)
      File.open(target, File::WRONLY | File::APPEND | File::CREAT, 0o600) do |file|
        file.write(JSON.generate({ 'schema' => 1, 'at' => Time.now.utc.iso8601, 'event' => name }.merge(details)) + "\n")
        file.flush; file.fsync
      end
    end

    def allocate(id, binding, policy)
      raise Failure, 'Run already exists' if File.exist?(path(id)) || File.exist?(path(id, '.json'))
      journal = { 'schema' => 1, 'id' => id, 'nonce' => SecureRandom.hex(16), 'root' => path(id), 'owner' => store_owner,
                  'created_at' => Time.now.utc.iso8601, 'heartbeat_at' => Time.now.utc.iso8601, 'state' => 'allocating',
                  'hold' => false, 'binding' => binding, 'policy' => policy, 'resources' => [], 'steps' => [] }
      save(journal) # Allocation intent exists before its directory.
      event(journal, 'allocation_planned')
      Dir.mkdir(path(id), 0o700)
      self.class.atomic(File.join(path(id), '.owner.json'), { 'id' => id, 'nonce' => journal['nonce'], 'root' => path(id) })
      journal['state'] = 'running'; save(journal)
      journal
    end

    def load(id)
      file = path(id, '.json')
      raise Failure, 'Missing or symlinked journal' unless File.file?(file) && !File.symlink?(file)
      journal = JSON.parse(File.read(file))
      raise Failure, 'Journal identity mismatch' unless journal['schema'] == 1 && journal['id'] == id && journal['root'] == path(id) && journal['owner'] == store_owner
      verify_root!(journal)
      events = path(id, '.events.jsonl')
      raise Failure, 'Missing or symlinked run history' unless File.file?(events) && !File.symlink?(events)
      history = File.binread(events)
      raise Failure, 'Truncated run history' unless history.end_with?("\n")
      history.lines.each { |line| JSON.parse(line) }
      result_path = path(id, '.result.json')
      if File.exist?(result_path)
        raise Failure, 'Symlinked result' if File.symlink?(result_path)
        result = JSON.parse(File.read(result_path))
        prefix = history.byteslice(0, result.fetch('history_bytes'))
        raise Failure, 'Recorded history changed' unless Digest::SHA256.hexdigest(prefix) == result.fetch('history_sha256')
      end
      journal
    end

    def verify_root!(journal)
      dir = path(journal.fetch('id')); marker = File.join(dir, '.owner.json')
      raise Failure, 'Run ownership incomplete; inspect allocation intent' unless Dir.exist?(dir) && !File.symlink?(dir) && File.realpath(dir) == dir && File.file?(marker) && !File.symlink?(marker)
      expected = { 'id' => journal['id'], 'nonce' => journal['nonce'], 'root' => dir }
      raise Failure, 'Run ownership marker mismatch' unless JSON.parse(File.read(marker)) == expected
    end

    def safe_path(journal, relative)
      raise Failure, 'Invalid owned resource path' unless relative.is_a?(String) && !Pathname.new(relative).absolute? && !relative.split('/').any? { |part| part.empty? || %w[. ..].include?(part) }
      verify_root!(journal)
      full = File.join(journal.fetch('root'), relative)
      parts = relative.split('/')
      raise Failure, 'Resource path contains symlink' if parts.each_index.any? { |i| File.symlink?(File.join(journal['root'], *parts.take(i + 1))) }
      full
    end

    def directory(journal, relative, disposable: true)
      full = safe_path(journal, relative)
      raise Failure, 'Resource already exists' if File.exist?(full)
      resource = { 'type' => 'directory', 'path' => relative, 'disposable' => disposable, 'state' => 'planned', 'nonce' => SecureRandom.hex(16) }
      journal['resources'] << resource; save(journal); event(journal, 'resource_planned', 'path' => relative)
      FileUtils.mkdir_p(full)
      # Mark the resource root, outside its nested authored-source directory.
      self.class.atomic(File.join(full, '.resource-owner.json'), { 'run_id' => journal['id'], 'nonce' => resource['nonce'] })
      stat = File.stat(full)
      resource.merge!('device' => stat.dev, 'inode' => stat.ino, 'state' => 'created'); save(journal)
      full
    end

    def result(journal, value)
      target = path(journal.fetch('id'), '.result.json')
      raise Failure, 'Result already exists; append recovery history instead' if File.exist?(target)
      history = File.binread(path(journal.fetch('id'), '.events.jsonl'))
      value = value.merge('history_bytes' => history.bytesize, 'history_sha256' => Digest::SHA256.hexdigest(history))
      self.class.atomic(target, value)
      journal['state'] = value.fetch('state'); journal['ended_at'] = value.fetch('ended_at')
      save(journal); event(journal, 'result_recorded', 'state' => value['state'])
      value
    end
  end
end
