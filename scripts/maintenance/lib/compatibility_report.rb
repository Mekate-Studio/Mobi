# frozen_string_literal: true

require_relative 'recovery'
require_relative '../adapters/compatibility'
require_relative 'upgrade_graph'

module Maintenance
  class CompatibilityReport
    def self.read(store, id)
      store.lock(id, create: false) do
        journal = store.load(id)
        result_path = store.path(id, '.result.json')
        raise Failure, 'Compatibility run is not complete' unless File.file?(result_path)
        result = JSON.parse(File.read(result_path))
        unless result['run_id'] == id && result['state'] == journal['state'] && result['ended_at'] == journal['ended_at'] && result['binding'] == journal['binding'] && result.dig('binding', 'adapter').to_s.start_with?('compatibility-') && result['adoption_authorized'] == false
          raise Failure, 'Compatibility result binding mismatch'
        end
        if result['state'] == 'checks_passed'
          steps = result.fetch('steps')
          unless steps.map { |s| s['phase'] }.sort == %w[baseline candidate] && steps.all? { |s| s['status'] == 'passed' && s['exit'] == 0 }
            raise Failure, 'Successful compatibility result lacks both passing phases'
          end
        end
        resolution = {}
        phases = result.fetch('steps').map do |step|
          record = journal.fetch('steps').find { |s| s['id'] == step['phase'] + '-' + step['check'] }
          raise Failure, 'Compatibility step is missing from journal' unless record && record['state'] == 'stopped'
          control = store.safe_path(journal, record['path'])
          hashes = step.fetch('output_sha256')
          unless hashes.keys.sort == %w[check.json stderr.log stdout.log] && record['process_exit'] == step['exit']
            raise Failure, 'Compatibility step lacks complete process/output evidence'
          end
          hashes.each do |name, sha|
            raise Failure, 'Unknown compatibility log name' unless %w[stdout.log stderr.log check.json].include?(name)
            verify_file!(File.join(control, name), sha)
            raise Failure, 'Compatibility journal output mismatch' unless record.fetch('output_sha256')[name] == sha
          end
          check = JSON.parse(File.read(File.join(control, 'check.json')))
          raise Failure, 'Compatibility check identity mismatch' unless check['phase'] == step['phase'] && check['check'] == step['check'] && check['status'] == step['status']
          file = File.join(control, 'evidence.json'); verify_file!(file, check.fetch('evidence_sha256'))
          evidence = JSON.parse(File.read(file))
          raise Failure, 'Compatibility phase evidence mismatch' unless evidence['phase'] == step['phase'] && evidence['profile'] == step['check'] && evidence['adoption_authorized'] == false
          evidence.fetch('commands').each do |command|
            raise Failure, 'Invalid command log path' unless command.fetch('log').match?(/\A[a-z][a-z0-9_-]*\.log\z/)
            verify_file!(File.join(control, command['log']), command.fetch('sha256'))
          end
          evidence.values.select { |value| value.is_a?(Hash) && value.key?('file') }.each do |reference|
            raise Failure, 'Invalid evidence reference' unless reference['file'].match?(/\A[a-z][a-z0-9-]*\.json\z/)
            verify_file!(File.join(control, reference['file']), reference.fetch('sha256'))
          end
          if step['status'] == 'passed'
            required = %w[effective_toolchain]
            direct = step['check'] == 'direct-facade' && step['phase'] == 'candidate'
            required += %w[native_library_compile framework_link] unless direct
            required += %w[toolchain_resolution bridge_resolution] if step['check'] == 'bridge-review'
            required += %w[android-test android-build-debug ios-test ios-build-debug] unless step['check'] == 'bridge-compile'
            unless required.all? { |cell| evidence.fetch('cells').dig(cell, 'status') == 'passed' } && evidence['source_preservation'] == 'verified'
              raise Failure, 'Passing compatibility phase lacks required capability evidence'
            end
            if direct && !(evidence['bridge_unavailable'] == true && evidence['di_reachable'] == true)
              raise Failure, 'Passing direct phase lacks bridge absence or DI reachability'
            end
            if step['check'] == 'bridge-review'
              bridge = JSON.parse(File.read(File.join(control, evidence.fetch('bridge-resolution').fetch('file'))))
              toolchain = JSON.parse(File.read(File.join(control, evidence.fetch('resolved-graphs').fetch('file'))))
              resolution[step['phase']] = { 'bridge' => bridge, 'queries' => UpgradeGraph.maven_queries(bridge, toolchain) }
            end
          end
          { 'phase' => step['phase'], 'outcome' => step['status'], 'evidence_sha256' => check['evidence_sha256'],
            'diagnostic' => diagnostic(evidence),
            'cells' => evidence.fetch('cells'), 'di_reachable' => evidence['di_reachable'], 'bridge_unavailable' => evidence.fetch('bridge_unavailable', false),
            'source_preservation' => evidence['source_preservation'], 'missing_capabilities' => evidence['missing_capabilities'] }
        end
        report = { 'schema' => 1, 'run_id' => id, 'state' => result['state'], 'reason' => result['reason'], 'binding' => result['binding'],
          'result_sha256' => Maintenance.file_sha(result_path), 'phases' => phases, 'missing_capabilities' => result['missing_capabilities'],
          'bridge_retirement' => 'defer', 'adoption_authorized' => false }
        if resolution.keys.sort == %w[baseline candidate]
          report['resolution'] = { 'bridge_diff' => UpgradeGraph.diff(resolution['baseline']['bridge'], resolution['candidate']['bridge']),
                                   'baseline_advisory_queries' => resolution['baseline']['queries'], 'candidate_advisory_queries' => resolution['candidate']['queries'] }
          report['missing_capabilities'] -= ['complete_bridge_target_graph']
          report['phases'].each { |phase| phase['missing_capabilities'] -= ['complete_bridge_target_graph'] }
        end
        report
      end
    rescue KeyError, TypeError, NoMethodError, JSON::ParserError
      raise Failure, 'Malformed compatibility evidence'
    end

    def self.diagnostic(evidence)
      detail = evidence.slice('exception_class', 'setup_stage', 'failure_origin')
      valid = (!detail['exception_class'] || detail['exception_class'].is_a?(String) && detail['exception_class'].match?(/\A[A-Za-z]\w*(?:::[A-Za-z]\w*)*\z/)) &&
              (!detail['setup_stage'] || %w[android_sdk_copy gradle_configuration android_sdk_inventory simulator_creation complete].include?(detail['setup_stage'])) &&
              (!detail['failure_origin'] || detail['failure_origin'].is_a?(String) && detail['failure_origin'].match?(/\A[a-z_]+\.rb:[1-9]\d*\z/))
      raise Failure, 'Unsafe compatibility diagnostic' unless valid
      detail
    end

    def self.verify_file!(path, sha)
      unless sha.is_a?(String) && sha.match?(/\A[0-9a-f]{64}\z/) && File.file?(path) && !File.symlink?(path) && Maintenance.file_sha(path) == sha
        raise Failure, 'Compatibility evidence digest mismatch'
      end
    end
  end
end
