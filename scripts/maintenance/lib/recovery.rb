# frozen_string_literal: true

require_relative 'executor'

module Maintenance
  class Recovery
    def initialize(store)
      @store = store
    end

    def resource_path(journal, resource)
      @store.resource_path(journal, resource)
    end

    def process_state(journal, step)
      path = @store.safe_path(journal, step.fetch('path'))
      started = File.join(path, 'started.json')
      owner = step['owner']
      if !owner && File.file?(started) && !File.symlink?(started)
        owner = JSON.parse(File.read(started))
      end
      return { 'check' => step['id'], 'state' => 'uncertain' } unless owner && owner['nonce'] == step['nonce']
      current = ProcessGroup.identity(owner.fetch('pid'))
      state = if current
                ProcessGroup.owned?(owner, current) ? 'owned_active' : 'uncertain'
              else
                ProcessGroup.members(owner.fetch('pgid')).empty? ? 'absent' : 'uncertain'
              end
      if state == 'absent' && !ResourceHandlers.quiescent?(step['managed_resources'])
        state = 'owned_resources_active'
      end
      { 'check' => step['id'], 'state' => state, 'owner' => owner }
    end

    def recover(id, action: nil)
      raise Failure, 'Unknown recovery action' unless [nil, 'stop', 'hold', 'release-hold'].include?(action)
      @store.lock(id, create: false) do
        journal = @store.load(id)
        if %w[hold release-hold].include?(action)
          journal['hold'] = action == 'hold'; @store.save(journal)
          @store.event(journal, action)
        end
        states = journal['steps'].map { |step| process_state(journal, step) }
        blocked = states.any? { |state| state['state'] == 'uncertain' }
        if action == 'stop' && !blocked
          states.select { |state| state['state'] == 'owned_active' }.each do |state|
            @store.event(journal, 'recovery_stop_planned', 'check' => state['check'])
            ProcessGroup.stop(state['owner'], grace: journal['policy']['termination_grace_seconds'])
          end
          journal['steps'].each { |step| ResourceHandlers.stop(step['managed_resources']) }
          states = journal['steps'].map { |step| process_state(journal, step) }
          blocked = states.any? { |state| state['state'] != 'absent' }
          unless blocked
            result_path = @store.path(id, '.result.json')
            unless File.exist?(result_path)
              @store.result(journal, { 'schema' => 1, 'run_id' => id, 'state' => 'inconclusive', 'reason' => 'coordinator_interrupted',
                                       'started_at' => journal['created_at'], 'ended_at' => Time.now.utc.iso8601, 'binding' => journal['binding'],
                                       'steps' => [], 'scope' => 'interrupted_run', 'missing_capabilities' => ['unrecorded_checks'], 'adoption_authorized' => false })
            end
            @store.event(journal, 'recovery_quiescent')
          end
        end
        { 'schema' => 1, 'operation' => 'recover', 'run_id' => id, 'state' => blocked ? 'ownership_uncertain' : states.any? { |s| %w[owned_active owned_resources_active].include?(s['state']) } ? 'owned_processes_active' : 'quiescent',
          'hold' => journal['hold'], 'processes' => states.map { |state| state.reject { |key, _| key == 'owner' } },
          'recorded_outcome' => journal['state'], 'resume_allowed' => false, 'adoption_authorized' => false }
      end
    end

    def cleanup(id, apply: false, discard: false, now: Time.now.utc)
      @store.lock(id, create: false) do
        journal = @store.load(id)
        raise Failure, 'Run is held for review' if journal['hold']
        raise Failure, 'Recover interrupted run before cleanup' unless journal['ended_at'] && Executor::EXIT_CODES.key?(journal['state'])
        states = journal['steps'].map { |step| process_state(journal, step) }
        raise Failure, 'Process ownership is uncertain or active; recover first' unless states.all? { |state| state['state'] == 'absent' }
        resources = journal['resources'].select { |resource| resource['disposable'] }
        paths = resources.map { |resource| resource_path(journal, resource) }
        days = journal['policy'][journal['state'] == 'checks_passed' ? 'success_retention_days' : 'failure_retention_days']
        due_at = Time.iso8601(journal['ended_at']) + days * 86_400
        eligible = discard || now >= due_at
        state = 'dry_run'
        if apply && eligible
          state = @store.remove_resources!(journal, resources)
        elsif apply
          state = 'retained'
        end
        { 'schema' => 1, 'operation' => 'cleanup', 'run_id' => id, 'state' => state, 'eligible' => eligible,
          'retention_due_at' => due_at.utc.iso8601, 'paths' => resources.map { |resource| resource['path'] },
          'evidence_retained' => true, 'recorded_outcome' => journal['state'], 'adoption_authorized' => false }
      end
    end
  end
end
