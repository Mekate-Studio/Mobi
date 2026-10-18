# frozen_string_literal: true

require_relative 'delivery'

module Maintenance
  module SwiftExport
    # A cooperating local registry. Collection and pin registration use one lock;
    # an uncertain or incomplete intent protects all objects until reviewed.
    class Registry
      attr_reader :root

      def self.create(path, logical_bytes:, minimum_age_seconds:, run: nil)
        raise Failure, 'Explicit cache policy required' unless logical_bytes.is_a?(Integer) && logical_bytes > 0 && minimum_age_seconds.is_a?(Integer) && minimum_age_seconds >= 0
        parent = File.realpath(File.dirname(path))
        raise Failure, 'Symlink registry parent' unless parent == File.expand_path(File.dirname(path))
        root = File.join(parent, File.basename(path))
        ancestor = parent
        loop do
          if File.file?(File.join(ancestor, '.resource-owner.json'))
            raise Failure, 'Disposable workspace registry requires its owning run binding' unless run
            store = RunStore.new(run.fetch('store')); journal = store.load(run.fetch('run_id'))
            raise Failure, 'Registry escaped its owning run' unless root.start_with?(journal['root'] + '/')
            break
          end
          break if ancestor == File.dirname(ancestor)
          ancestor = File.dirname(ancestor)
        end
        Dir.mkdir(root, 0o700) # Never adopt an existing/unowned directory.
        %w[objects pending readers references].each { |n| Dir.mkdir(File.join(root, n), 0o700) }
        owner = { 'schema' => 1, 'root' => root, 'nonce' => SecureRandom.hex(16), 'host' => ProcessGroup.host, 'uid' => Process.uid }
        owner['owning_run'] = run if run
        RunStore.atomic(File.join(root, 'owner.json'), owner)
        RunStore.atomic(File.join(root, 'policy.json'), 'logical_payload_byte_limit' => logical_bytes, 'minimum_age_seconds' => minimum_age_seconds)
        new(root)
      end

      def initialize(path)
        @root = File.expand_path(path)
        raise Failure, 'Symlink registry root' if File.symlink?(@root) || File.realpath(@root) != @root
        @owner = read('owner.json')
        raise Failure, 'Registry ownership mismatch' unless @owner['schema'] == 1 && @owner['root'] == @root && @owner['host'] == ProcessGroup.host && @owner['uid'] == Process.uid && @owner['nonce'].to_s.match?(RunStore::ID)
        verify!
      end

      def read(relative)
        JSON.parse(File.read(Descriptor.safe(root, relative)))
      rescue JSON::ParserError, Errno::ENOENT
        raise Failure, "Missing/malformed registry state: #{relative}"
      end

      def verify!
        raise Failure, 'Registry identity changed' unless File.realpath(root) == root && !File.symlink?(root) && read('owner.json') == @owner
        %w[objects pending readers references].each { |n| raise Failure, 'Missing registry directory' unless File.directory?(Descriptor.safe(root, n)) }
        p = read('policy.json')
        raise Failure, 'Invalid cache policy' unless p['logical_payload_byte_limit'].is_a?(Integer) && p['logical_payload_byte_limit'] > 0 && p['minimum_age_seconds'].is_a?(Integer) && p['minimum_age_seconds'] >= 0
      end

      def locked
        verify!
        File.open(Descriptor.safe(root, 'writer.lock'), File::RDWR | File::CREAT, 0o600) do |lock|
          lock.flock(File::LOCK_EX)
          verify!
          yield
        end
      end

      def current
        return { 'generation' => 0, 'object' => nil } unless File.exist?(Descriptor.safe(root, 'current.json'))
        p = read('current.json')
        raise Failure, 'Invalid registry pointer' unless p.keys.sort == %w[generation object] && p['generation'].is_a?(Integer) && p['generation'] > 0 && p['object'].to_s.match?(Descriptor::SHA)
        p
      end

      def stage(delivery)
        Delivery.verify(delivery)
        locked do
          destination = File.join(root, 'pending', SecureRandom.hex(16))
          Dir.mkdir(destination, 0o700)
          FileUtils.cp_r(File.join(delivery, '.'), destination, preserve: true)
          Delivery.verify(destination)
          destination
        end
      end

      def publish(payload, expected:, retained_run: nil, checkpoint: nil)
        locked do
          raise Failure, 'Expected generation required' unless expected.is_a?(Integer) && expected >= 0 && current['generation'] == expected
          relative = File.expand_path(payload).delete_prefix(root + '/')
          raise Failure, 'Payload is not owned staging' unless relative.match?(%r{\Apending/[0-9a-f]{32}\z}) && Descriptor.safe(root, relative) == File.expand_path(payload)
          id = Delivery.verify(payload)
          state = snapshot
          raise Failure, 'Uncertain registry refuses publication' unless state['uncertainty'].empty?
          raise Failure, 'Logical cache capacity exhausted; protected content retained' if state['logical_payload_bytes'] > state['policy']['logical_payload_byte_limit']
          destination = File.join(root, 'objects', id)
          if File.exist?(destination)
            raise Failure, 'Existing object corrupt' unless Delivery.verify(destination) == id
          else
            File.rename(payload, destination)
            File.utime(Time.now, Time.now, destination)
          end
          checkpoint&.call('object_installed')
          # Establish the evidence intent before the object becomes selected.
          if retained_run
            validate_run!(retained_run)
            RunStore.atomic(File.join(root, 'references', retained_run.fetch('run_id') + '.json'),
                            'object' => id, 'kind' => 'retained-run', 'registry_nonce' => @owner['nonce'], 'run' => retained_run)
          end
          RunStore.atomic(File.join(root, 'current.json'), 'generation' => expected + 1, 'object' => id)
          checkpoint&.call('pointer_installed')
          current
        end
      end

      def validate_run!(binding)
        raise Failure, 'Invalid retained run reference' unless binding.keys.sort == %w[run_id store] && binding['run_id'].to_s.match?(RunStore::ID)
        RunStore.new(binding.fetch('store')).load(binding.fetch('run_id'))
      end

      def pin(owner:, run:)
        locked do
          validate_run!(run)
          raise Failure, 'Scratch registry reader belongs to another run' if @owner['owning_run'] && @owner['owning_run'] != run
          journal = RunStore.new(run['store']).load(run['run_id'])
          raise Failure, 'Reader group is not registered in its run' unless journal['steps'].any? { |s| s['nonce'] == owner['nonce'] && s['owner'] == owner }
          current_owner = ProcessGroup.identity(owner['pid'])
          raise Failure, 'Reader group ownership unavailable' unless ProcessGroup.owned?(owner, current_owner) && Process.getpgrp == owner['pgid']
          pointer = current
          raise Failure, 'No selected delivery' unless pointer['object']
          path = File.join(root, 'objects', pointer['object'])
          raise Failure, 'Selected delivery corrupt' unless Delivery.verify(path) == pointer['object']
          id = SecureRandom.hex(16)
          # One atomic record combines ownership and pin; no partially separate
          # owner/pin writes can make an abandoned pin appear collectible.
          record = { 'schema' => 1, 'id' => id, 'registry_nonce' => @owner['nonce'], 'object' => pointer['object'],
                     'generation' => pointer['generation'], 'owner' => owner, 'run' => run }
          RunStore.atomic(File.join(root, 'readers', id + '.json'), record)
          [path, record]
        end
      end

      def reader(id)
        raise Failure, 'Invalid reader ID' unless id.to_s.match?(RunStore::ID)
        r = read('readers/' + id + '.json')
        raise Failure, 'Malformed reader intent' unless r['schema'] == 1 && r['id'] == id && r['registry_nonce'] == @owner['nonce'] && r['object'].to_s.match?(Descriptor::SHA) && r['generation'].is_a?(Integer) && r['generation'] > 0 && r['owner'].is_a?(Hash)
        raise Failure, 'Reader ownership record invalid' unless ProcessGroup.owned?(r['owner'], r['owner'])
        validate_run!(r.fetch('run'))
        live = ProcessGroup.identity(r['owner']['pid'])
        state = if live
                  ProcessGroup.owned?(r['owner'], live) ? 'live' : 'uncertain_identity'
                elsif ProcessGroup.members(r['owner']['pgid']).empty?
                  'quiescent_unrecovered'
                else
                  'uncertain_descendants'
                end
        r.merge('state' => state)
      end

      def release(id)
        locked do
          r = reader(id)
          raise Failure, 'Only owning live group can release' unless r['state'] == 'live' && Process.getpgrp == r['owner']['pgid']
          File.unlink(Descriptor.safe(root, 'readers/' + id + '.json'))
          r
        end
      end

      def recover(id)
        locked do
          r = reader(id)
          raise Failure, 'Reader is not positively quiescent' unless r['state'] == 'quiescent_unrecovered'
          # Also require all run-owned processes/resources to be quiescent.
          require_relative '../recovery'
          recovery = Recovery.new(RunStore.new(r['run']['store'])).recover(r['run']['run_id'])
          raise Failure, 'Run resources are not positively quiescent' unless recovery['state'] == 'quiescent'
          File.unlink(Descriptor.safe(root, 'readers/' + id + '.json'))
          r.merge('recovery' => 'positive_resource_quiescence')
        end
      end

      def reference(name, object, kind)
        raise Failure, 'Invalid explicit reference' unless name.to_s.match?(/\A[a-z][a-z0-9-]*\z/) && object.to_s.match?(Descriptor::SHA) && %w[held evidence].include?(kind)
        locked do
          raise Failure, 'Referenced object unavailable' unless Delivery.verify(File.join(root, 'objects', object)) == object
          RunStore.atomic(File.join(root, 'references', name + '.json'), 'object' => object, 'kind' => kind, 'registry_nonce' => @owner['nonce'])
        end
      end

      def snapshot
        pointer = current
        policy = read('policy.json')
        uncertain, pins, refs = [], [], []
        Dir.children(File.join(root, 'readers')).sort.each do |name|
          begin
            raise Failure, 'Invalid reader filename' unless name.match?(/\A[0-9a-f]{32}\.json\z/)
            pin = reader(name.delete_suffix('.json'))
            pins << pin
            uncertain << { 'reader' => pin['id'], 'finding' => pin['state'] } if pin['state'].start_with?('uncertain_')
          rescue StandardError => e
            uncertain << { 'reader' => name, 'finding' => e.message }
          end
        end
        Dir.children(File.join(root, 'references')).sort.each do |name|
          begin
            r = read('references/' + name)
            raise Failure, 'Invalid reference' unless r['registry_nonce'] == @owner['nonce'] && r['object'].to_s.match?(Descriptor::SHA) && %w[held evidence retained-run].include?(r['kind'])
            validate_run!(r.fetch('run')) if r['kind'] == 'retained-run'
            refs << r.merge('reference' => name)
          rescue StandardError => e
            uncertain << { 'reference' => name, 'finding' => e.message }
          end
        end
        objects = Dir.children(File.join(root, 'objects')).sort.map do |id|
          path = Descriptor.safe(root, 'objects/' + id)
          reasons, size = [], 0
          begin
            raise Failure, 'Invalid object identity' unless id.match?(Descriptor::SHA) && Delivery.verify(path) == id
            size = Descriptor.inventory(root, ['objects/' + id]).keys.sum { |p| File.size(File.join(root, p)) }
          rescue StandardError => e
            reasons << 'corrupt'
            uncertain << { 'object' => id, 'finding' => e.message }
          end
          reasons << 'active' if pointer['object'] == id
          pins.select { |p| p['object'] == id }.each { |p| reasons << 'reader_' + p['state'] }
          refs.select { |r| r['object'] == id }.each { |r| reasons << r['kind'] }
          reasons << 'unexpired' if File.exist?(path) && Time.now - File.mtime(path) < policy['minimum_age_seconds']
          { 'object' => id, 'bytes' => size, 'eligible' => reasons.empty?, 'reasons' => reasons.uniq.sort }
        end
        protected_ids = pins.map { |p| p['object'] } + refs.map { |r| r['object'] } + [pointer['object']].compact
        (protected_ids - objects.map { |o| o['object'] }).uniq.each { |id| uncertain << { 'object' => id, 'finding' => 'Protected object missing' } }
        pending_bytes = 0
        begin
          pending_bytes = Descriptor.inventory(root, ['pending']).keys.sum { |p| File.size(File.join(root, p)) }
        rescue StandardError => e
          uncertain << { 'pending' => true, 'finding' => e.message }
        end
        objects.each { |o| o['eligible'] = false; o['reasons'] << 'registry_uncertain' } unless uncertain.empty?
        { 'schema' => 1, 'pointer' => pointer, 'policy' => policy, 'objects' => objects, 'readers' => pins, 'references' => refs,
          'uncertainty' => uncertain, 'logical_payload_bytes' => objects.sum { |o| o['bytes'] } + pending_bytes }
      end

      def report
        locked { s = snapshot; s.merge('fingerprint' => Maintenance.digest(s)) }
      end

      def collect(report)
        locked do
          actual = snapshot
          raise Failure, 'Stale collection report' unless Maintenance.digest(actual) == report['fingerprint']
          raise Failure, 'Uncertain registry refuses collection' unless actual['uncertainty'].empty?
          selected = actual['objects'].select { |o| o['eligible'] }.map { |o| o['object'] }
          selected.each { |id| FileUtils.remove_entry_secure(Descriptor.safe(root, 'objects/' + id)) }
          { 'deleted' => selected, 'protected' => actual['objects'].reject { |o| o['eligible'] }.map { |o| o['object'] }, 'report_fingerprint' => report['fingerprint'] }
        end
      end
    end
  end
end
