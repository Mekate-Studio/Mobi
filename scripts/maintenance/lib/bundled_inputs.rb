# frozen_string_literal: true

require_relative 'build_inputs'

module Maintenance
  module BundledInputs
    # Same bytes establish a reference artifact identity, not a candidate Maven
    # resolution or variant. Never obtain coordinates from bundled filenames.
    def self.match(baseline, candidate)
      reference = Hash.new { |hash, key| hash[key] = [] }
      baseline.flat_map { |packet| BuildInputs.delegated!(packet.fetch('data')) }.each do |row|
        Array(row['artifacts']).each do |artifact|
          next unless artifact['component']['kind'] == 'maven' && artifact['identity']['kind'] == 'file'
          identity = artifact['identity']
          reference[[identity['sha256'], identity['bytes']]] << artifact['component']
        end
      end
      inputs = candidate.flat_map { |packet| BuildInputs.delegated!(packet.fetch('data')) }.select { |row| row['owner'] == 'settings' }.flat_map { |row| Array(row['artifacts']) }.select { |a| a['component']['kind'] == 'opaque' }
      inputs = inputs.uniq { |a| a.values_at('name', 'identity') }.sort_by { |a| [a['name'], a['identity']['sha256']] }
      matches = []; unassigned = []
      inputs.each do |artifact|
        identity = artifact['identity']
        choices = identity['kind'] == 'file' ? reference[[identity['sha256'], identity['bytes']]].uniq : []
        item = artifact.slice('name', 'identity')
        if choices.size == 1
          matches << item.merge('reference_component' => choices.first, 'evidence_kind' => 'unique_baseline_component_byte_match')
        else
          unassigned << item.merge('state' => choices.empty? ? 'unattributed' : 'ambiguous_reference', 'reference_component_count' => choices.size)
        end
      end
      queries = matches.map do |item|
        component = item['reference_component']
        { 'package' => { 'ecosystem' => 'Maven', 'name' => component['group'] + ':' + component['name'] }, 'version' => component['version'] }
      end.uniq.sort_by { |q| [q['package']['name'], q['version']] }
      { 'schema' => 1, 'scope' => 'candidate_settings_files_against_verified_baseline_maven_artifact_bytes',
        'state' => unassigned.empty? ? 'reference_bytes_attributed' : 'attribution_incomplete',
        'candidate_maven_resolution' => 'not_inferred', 'candidate_variant' => 'not_inferred',
        'opaque_artifact_count' => inputs.size, 'matches' => matches, 'unassigned' => unassigned, 'advisory_queries' => queries,
        'producer_sha256' => { 'baseline' => Maintenance.digest(baseline), 'candidate' => Maintenance.digest(candidate) },
        'deriver_sha256' => Maintenance.file_sha(__FILE__), 'remediation_verified' => false, 'adoption_authorized' => false }
    rescue KeyError, TypeError, NoMethodError
      raise Failure, 'Malformed bundled settings input attribution'
    end
  end
end
