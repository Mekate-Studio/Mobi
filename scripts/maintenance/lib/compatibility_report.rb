# frozen_string_literal: true

require_relative 'recovery'
require_relative '../adapters/compatibility'
require_relative 'upgrade_graph'
require_relative 'roundtrip_evidence'
require_relative 'direct_resolution'
require_relative 'advisory_review'
require_relative 'build_inputs'
require_relative 'jetifier_conditions'
require_relative 'bundled_inputs'

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
        roundtrip = {}
        direct_resolution = {}
        build_inputs = {}
        delegated_inputs = {}
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
            resolution_only = step['check'] == 'direct-resolution'
            build_proof = %w[direct-build-inputs upstream-build-inputs].include?(step['check'])
            packaging = { 'upstream-android-packaging' => %w[android-build-debug android_release android_aab],
                          'upstream-ios-release' => ['ios_release_simulator'], 'upstream-ios-archive' => ['ios_unsigned_archive'],
                          'upstream-packaging' => %w[android-build-debug android_release android_aab ios_release_simulator ios_unsigned_archive] }
            source_manifest = evidence['source-manifest'] && JSON.parse(File.read(File.join(control, evidence.fetch('source-manifest').fetch('file'))))
            adopted_direct = evidence['baseline_kind'] == 'adopted_direct'
            if adopted_direct && (!source_manifest || source_manifest.keys.any? { |path| path.start_with?('gradle-bridge/') || path == Compatibility::CATALOG })
              raise Failure, 'Adopted direct baseline requires a bridge-free source manifest'
            end
            raise Failure, 'Direct mobile profile requires a bridge-free source manifest' if step['check'] == 'direct-mobile' && !adopted_direct
            if adopted_direct
              raise Failure, 'Direct source evidence lost bridge absence' unless evidence['bridge_unavailable'] && evidence.dig('environment', 'bridge') == 'kotlin'
            end
            direct = adopted_direct || %w[direct-facade direct-roundtrip direct-resolution direct-build-inputs].include?(step['check']) && step['phase'] == 'candidate'
            required += %w[native_library_compile framework_link] unless direct || resolution_only || build_proof || packaging.key?(step['check']) && step['check'] != 'upstream-packaging'
            required += ['toolchain_resolution'] if resolution_only || build_proof
            required += %w[android-test android-build-debug native_klib_iosarm64 native_klib_iossimulatorarm64 build_input_evidence] if build_proof
            required += %w[toolchain_resolution bridge_resolution] if step['check'] == 'bridge-review'
            required += %w[android-test android-build-debug ios-test ios-build-debug] unless step['check'] == 'bridge-compile' || resolution_only || build_proof || packaging.key?(step['check'])
            required += packaging.fetch(step['check'], [])
            required += RoundtripEvidence::CELLS if direct && step['check'] == 'direct-roundtrip'
            unless required.all? { |cell| evidence.fetch('cells').dig(cell, 'status') == 'passed' } && evidence['source_preservation'] == 'verified'
              raise Failure, 'Passing compatibility phase lacks required capability evidence'
            end
            if direct && !(evidence['bridge_unavailable'] == true && evidence['di_reachable'] == true)
              raise Failure, 'Passing direct phase lacks bridge absence or DI reachability'
            end
            if resolution_only
              unless DirectResolution::NATIVE_CELLS.all? { |cell| evidence.fetch('cells').dig(cell, 'status') == 'not_attempted' } &&
                     (DirectResolution::GAPS - evidence.fetch('missing_capabilities')).empty? && (DirectResolution::GAPS - result.fetch('missing_capabilities')).empty?
                raise Failure, 'Graph-only evidence overclaims native or artifact capabilities'
              end
              direct_resolution[step['phase']] = DirectResolution.verify!(control, evidence)
            end
            if build_proof
              unless %w[ios-test ios-build-debug].all? { |cell| evidence.fetch('cells').dig(cell, 'status') == 'not_attempted' } && (DirectResolution::GAPS - result.fetch('missing_capabilities')).empty?
                raise Failure, 'Build input evidence overclaims native or advisory capabilities'
              end
              direct_resolution[step['phase']] = DirectResolution.verify!(control, evidence)
              if step['check'] == 'upstream-build-inputs' && !adopted_direct && (evidence['bridge_unavailable'] || evidence.dig('environment', 'bridge') != 'gradle')
                raise Failure, 'Upstream retained-bridge profile changed the bridge path'
              end
              declarations = JSON.parse(File.read(File.join(control, evidence.fetch('resolution-declarations').fetch('file'))))
              version = declarations.fetch('kotlin')[/^kotlin_cli_version=(.+)$/, 1]
              replay = BuildInputs.read(control, compiler_version: BuildInputs::COMPILERS.fetch(version))
              ref = evidence.fetch('build-inputs')
              stored = JSON.parse(File.read(File.join(control, ref.fetch('file'))))
              raise Failure, 'Build input summary differs from producer replay' unless stored == replay
              build_inputs[step['phase']] = replay
              delegated_inputs[step['phase']] = JSON.parse(File.read(File.join(control, evidence.fetch('delegated-graphs').fetch('file'))))
              queries = direct_resolution[step['phase']]['advisory_queries']
              queries['queries'] = (queries['queries'] + replay['delegated_queries']).uniq.sort_by { |q| [q['package']['name'], q['version']] }
              queries['limitations'] += BuildInputs::GAPS
            end
            if step['check'] == 'bridge-review'
              bridge = JSON.parse(File.read(File.join(control, evidence.fetch('bridge-resolution').fetch('file'))))
              toolchain = JSON.parse(File.read(File.join(control, evidence.fetch('resolved-graphs').fetch('file'))))
              resolution[step['phase']] = { 'bridge' => bridge, 'queries' => UpgradeGraph.maven_queries(bridge, toolchain) }
            end
            if step['check'] == 'direct-roundtrip'
              keys = step['phase'] == 'baseline' ? %w[source-manifest native-test-cases] : RoundtripEvidence::REFERENCES
              roundtrip[step['phase']] = keys.to_h do |key|
                reference = evidence.fetch(key)
                raise Failure, 'Invalid roundtrip reference' unless reference.fetch('file').match?(/\A[a-z][a-z0-9-]*\.json\z/)
                path = File.join(control, reference['file']); verify_file!(path, reference.fetch('sha256'))
                [key, JSON.parse(File.read(path))]
              end
              if direct && evidence['bridge_absence_scope'] != 'direct_checks_before_restoration'
                raise Failure, 'Roundtrip lacks direct-stage bridge absence evidence'
              end
            end
          end
          selection = evidence['candidate_selection']
          raise Failure, 'Missing experimental release-age evidence' if result.fetch('missing_capabilities').include?('release_age') && !selection
          if selection
            unless %w[normal experimental].include?(selection['mode']) && %w[age_blocked age_eligible].include?(selection['age_state']) && selection['adoption_authorized'] == false &&
                   (Time.iso8601(selection.fetch('assessed_at')) >= Time.iso8601(selection.fetch('eligible_at'))) == (selection['age_state'] == 'age_eligible') &&
                   (selection['age_state'] != 'age_blocked' || selection['mode'] == 'experimental' && evidence.fetch('missing_capabilities').include?('release_age') && result.fetch('missing_capabilities').include?('release_age'))
              raise Failure, 'Invalid experimental release-age evidence'
            end
          end
          { 'phase' => step['phase'], 'outcome' => step['status'], 'evidence_sha256' => check['evidence_sha256'], 'candidate_selection' => selection,
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
        if direct_resolution.keys.sort == %w[baseline candidate]
          report['direct_resolution'] = direct_resolution
          report['build_inputs'] = build_inputs unless build_inputs.empty?
          unless delegated_inputs.empty?
            report['jetifier_conditions'] = delegated_inputs.to_h { |phase, packets| [phase, JetifierConditions.read(packets)] }
          end
          if result.dig('binding', 'adapter') == 'compatibility-upstream-build-inputs'
            attribution = BundledInputs.match(delegated_inputs.fetch('baseline'), delegated_inputs.fetch('candidate'))
            report['bundled_settings_inputs'] = attribution
            queries = direct_resolution['candidate']['advisory_queries']
            queries['queries'] = (queries['queries'] + attribution['advisory_queries']).uniq.sort_by { |q| [q['package']['name'], q['version']] }
            queries['limitations'] += ['Bundled settings files use exact baseline artifact byte references; candidate Maven resolution and variants are not inferred', 'Unassigned bundled files remain outside advisory lookup']
            report['missing_capabilities'] += ['bundled_settings_classpath_attribution'] unless attribution['unassigned'].empty?
          end
          { 'candidate' => 'advisory-review.json', 'baseline' => 'advisory-review-baseline.json' }.each do |phase, name|
            path = File.join(store.path(id), name)
            next unless File.exist?(path)
            raise Failure, 'Symlinked advisory receipt' if File.symlink?(path)
            receipt = JSON.parse(File.read(path))
            raise Failure, 'Advisory phase differs from receipt path' unless receipt.fetch('phase', 'candidate') == phase
            key = phase == 'candidate' ? 'direct_advisories' : 'baseline_advisories'
            report[key] = AdvisoryReview.verify!(receipt, report)
          end
          if report['direct_advisories'] && report['baseline_advisories']
            baseline = report['baseline_advisories']; candidate = report['direct_advisories']
            complete = [baseline, candidate].all? { |r| %w[provider_complete triage_required].include?(r['state']) }
            report['advisory_comparison'] = { 'state' => complete ? (report.dig('bundled_settings_inputs', 'state') == 'attribution_incomplete' ? 'attribution_incomplete' : 'review_required') : 'incomplete',
              'lookup_removed_ids' => complete ? baseline['finding_ids'] - candidate['finding_ids'] : [],
              'lookup_added_ids' => complete ? candidate['finding_ids'] - baseline['finding_ids'] : [],
              'lookup_remaining_ids' => complete ? candidate['finding_ids'] & baseline['finding_ids'] : [],
              'scope' => 'fresh_named_and_reference_byte_attributed_queries_only', 'remediation_verified' => false, 'adoption_authorized' => false }
          end
        end
        if roundtrip.keys.sort == %w[baseline candidate]
          report['roundtrip'] = RoundtripEvidence.verify!(roundtrip['baseline'], roundtrip['candidate'])
          report['missing_capabilities'] -= %w[incremental_direct_build local_bridge_rollback]
          report['phases'].find { |phase| phase['phase'] == 'candidate' }['missing_capabilities'] -= %w[incremental_direct_build local_bridge_rollback]
        end
        report
      end
    rescue KeyError, TypeError, NoMethodError, ArgumentError, JSON::ParserError
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
