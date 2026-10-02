# frozen_string_literal: true

require_relative 'core'

module Maintenance
  module RoundtripEvidence
    CELLS = %w[incremental_ios_test incremental_ios_build incremental_framework_change bridge_restore rollback_ios_test rollback_ios_build].freeze
    REFERENCES = %w[source-manifest native-test-cases direct-source-manifest incremental-source-manifest restored-source-manifest incremental-mutation direct-frameworks-before direct-frameworks-after incremental-framework-change roundtrip-restoration incremental-native-test-cases rollback-native-test-cases rollback-frameworks].freeze
    PROBE = 'MobiIncrementalProbeTests/kotlinChangeReachesSwift()'
    PROBE_PATHS = %w[ios-app/tests/Maintenance/MobiIncrementalProbeTests.swift shared-di/src/MobiIncrementalProbe.kt].freeze

    def self.manifest!(data)
      valid = data.is_a?(Hash) && !data.empty? && data.all? do |path, identity|
        path.is_a?(String) && !path.start_with?('/') && !path.split('/').include?('..') && identity.is_a?(Hash) &&
          identity['sha256'].to_s.match?(/\A[0-9a-f]{64}\z/) && [true, false].include?(identity['executable'])
      end
      raise Failure, 'Invalid roundtrip source manifest' unless valid
    end

    def self.frameworks!(data)
      unless data.is_a?(Hash) && !data.empty? && data.all? { |path, sha| path.is_a?(String) && path.start_with?('build/') && path.end_with?('/KotlinModules.framework/KotlinModules') && !path.split('/').include?('..') && sha.to_s.match?(/\A[0-9a-f]{64}\z/) }
        raise Failure, 'Invalid roundtrip framework identities'
      end
    end

    def self.verify!(baseline, candidate)
      original = baseline.fetch('source-manifest')
      manifests = %w[source-manifest direct-source-manifest incremental-source-manifest restored-source-manifest].to_h { |key| [key, candidate.fetch(key)] }
      [original, *manifests.values].each { |data| manifest!(data) }
      unless original.dig('gradle-bridge/gradlew', 'executable') == true && original == manifests['source-manifest'] && original == manifests['restored-source-manifest'] && manifests['direct-source-manifest'].keys.none? { |path| path.start_with?('gradle-bridge/') }
        raise Failure, 'Roundtrip source restoration mismatch'
      end
      before, after = manifests.values_at('direct-source-manifest', 'incremental-source-manifest')
      changed = (before.keys & after.keys).select { |path| before[path] != after[path] }.sort
      mutation = candidate.fetch('incremental-mutation')
      unless before.keys.sort == after.keys.sort && changed == PROBE_PATHS && mutation['schema'] == 1 && mutation['before_source_sha256'] == Maintenance.digest(before) && mutation['after_source_sha256'] == Maintenance.digest(after) &&
             mutation['cache_policy'] == 'preserved' && mutation['generated_products_removed'] == false && mutation['adoption_authorized'] == false && mutation.fetch('changes').map { |change| change['path'] }.sort == PROBE_PATHS &&
             mutation['changes'].all? { |change| change['before_sha256'] == before.fetch(change['path'])['sha256'] && change['after_sha256'] == after.fetch(change['path'])['sha256'] }
        raise Failure, 'Missing bounded incremental mutation evidence'
      end
      restoration = candidate.fetch('roundtrip-restoration')
      unless restoration['schema'] == 1 && restoration['original_source_sha256'] == Maintenance.digest(original) && restoration['restored_source_sha256'] == Maintenance.digest(original) &&
             restoration['generated_products_cleared'] == ['build'] && restoration['fixture_additions_removed'] == true && restoration['bridge_restored'] == true && restoration['adoption_authorized'] == false
        raise Failure, 'Missing verified bridge restoration evidence'
      end
      tests = baseline.fetch('native-test-cases')
      test_lists = [tests] + %w[native-test-cases incremental-native-test-cases rollback-native-test-cases].map { |key| candidate.fetch(key) }
      unless test_lists.all? { |list| list.is_a?(Array) && list == list.uniq.sort && list.all? { |test| test.is_a?(String) && test.match?(/\A[A-Za-z0-9_]+\/[A-Za-z0-9_]+\(\)\z/) } } &&
             tests.size >= 12 && tests.any? { |test| test.start_with?('HomeFeatureTests/') } && tests.any? { |test| test.start_with?('NearbyVehicleMapFeatureTests/') } && !tests.include?(PROBE) &&
             candidate['native-test-cases'] == (tests + [PROBE]).sort && candidate['incremental-native-test-cases'] == (tests + [PROBE]).sort && candidate['rollback-native-test-cases'] == tests
        raise Failure, 'Roundtrip native consumers are incomplete'
      end
      left, right, restored = candidate.values_at('direct-frameworks-before', 'direct-frameworks-after', 'rollback-frameworks')
      [left, right, restored].each { |data| frameworks!(data) }
      changed_frameworks = (left.keys & right.keys).select { |path| left[path] != right[path] }.sort
      unless !changed_frameworks.empty? && candidate.fetch('incremental-framework-change')['changed'] == changed_frameworks
        raise Failure, 'Incremental framework bytes did not change'
      end
      { 'scope' => 'local_simulator_incremental_and_restoration', 'incremental_direct_build' => 'passed', 'local_bridge_rollback' => 'passed',
        'preserved_native_case_count' => tests.size, 'probe_case' => PROBE, 'changed_framework_count' => changed_frameworks.size,
        'restored_source_sha256' => Maintenance.digest(original), 'adoption_authorized' => false }
    rescue KeyError, TypeError, NoMethodError
      raise Failure, 'Malformed roundtrip evidence'
    end
  end
end
