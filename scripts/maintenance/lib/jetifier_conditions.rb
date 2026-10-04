# frozen_string_literal: true

require_relative 'build_inputs'

module Maintenance
  module JetifierConditions
    def self.identity!(value)
      unless value.is_a?(Hash) && value['kind'] == 'file' && value['sha256'].to_s.match?(/\A[0-9a-f]{64}\z/) && value['bytes'].is_a?(Integer) && value['bytes'] > 0
        raise Failure, 'Invalid Jetifier class/input container identity'
      end
    end

    def self.count!(value)
      raise Failure, 'Invalid Jetifier event count' unless value.is_a?(Integer) && value.between?(0, 100_000)
    end

    def self.build(packet)
      data = packet.fetch('data')
      rows = BuildInputs.delegated!(data)
      base = { 'generated_task' => data.fetch('generated_task'), 'gradle' => data.fetch('gradle') }
      return base.merge('state' => 'unmeasured', 'reason' => 'historical_producer_without_condition_fields') unless data.key?('jetifier_conditions')
      raise Failure, 'Missing Jetifier raw producer identity' unless packet['raw_sha256'].to_s.match?(/\A[0-9a-f]{64}\z/)
      value = data.fetch('jetifier_conditions')
      unless value.is_a?(Hash) && value['schema'] == 1 && value['projects'].is_a?(Array) && value['transforms'].is_a?(Hash)
        raise Failure, 'Malformed Jetifier condition producer'
      end
      raise Failure, 'Unsafe Jetifier producer content' if JSON.generate(value).match?(%r{/Users/|/home/|/private/|Bearer |github_pat_})
      expected = rows.select { |r| r['owner'] == 'project' && r['configuration'] == 'debugCompileClasspath' }.map { |r| r['project'] }.uniq.sort
      projects = value['projects']
      names = projects.map { |p| p.fetch('project') }
      raise Failure, 'Invalid or duplicate Jetifier project scope' unless names.uniq.size == names.size && (names - expected).empty?
      reasons = []
      reasons << 'missing_android_project_options' unless names.sort == expected && !expected.empty?
      projects.each do |project|
        case project['state']
        when 'collected'
          unless [true, false].include?(project['enabled']) && project['agp_version'] == '9.3.1' && project['option_api'] == 'actual_plugin_project_services_project_options'
            raise Failure, 'Unsupported effective Jetifier option binding'
          end
          %w[plugin_identity options_identity].each { |key| identity!(project.fetch(key)) }
          explicit = project.fetch('explicit_property')
          unless explicit.is_a?(Hash) && [true, false].include?(explicit['present']) && (explicit['present'] ? [true, false].include?(explicit['value']) : explicit['value'].nil?)
            raise Failure, 'Malformed explicit Jetifier option'
          end
          reasons << 'effective_and_explicit_option_disagree' if explicit['present'] && explicit['value'] != project['enabled']
        when 'incomplete'
          raise Failure, 'Incomplete Jetifier option invents a boolean' if project.key?('enabled') || project['reason'].to_s.empty?
          reasons << 'effective_option_unavailable'
        else raise Failure, 'Unknown Jetifier project observation state'
        end
      end
      transforms = value['transforms']
      unless %w[observed incomplete].include?(transforms['state']) && transforms['gradle'] == data['gradle'] && transforms['interval'] == 'init_script_to_build_finished' && transforms['events'].is_a?(Array) && transforms['events'].size <= 256
        raise Failure, 'Invalid Jetifier observer interval or support state'
      end
      %w[planned_count action_count].each { |key| count!(transforms.fetch(key)) }
      if transforms['state'] == 'observed'
        raise Failure, 'Unreviewed Jetifier observer version' unless %w[9.5.0 9.6.1].include?(transforms['gradle']) && transforms['reason'].nil?
      else
        raise Failure, 'Incomplete Jetifier observer has no reason' if transforms['reason'].to_s.empty?
        reasons << 'transform_observer_incomplete'
      end
      if transforms['observer_api'] != 'planned_identify_action_v1' || !transforms['identified_count'].is_a?(Integer)
        reasons << 'identify_transform_coverage_unmeasured'
      else
        count!(transforms['identified_count'])
        reasons << 'actions_without_identity_observations' if transforms['action_count'] > 0 && transforms['identified_count'].zero?
      end
      actions = 0
      transforms['events'].each do |event|
        count!(event.fetch('action_count')); actions += event['action_count']
        identity!(event.fetch('implementation_identity'))
        unless event['implementation'].is_a?(String) && event['implementation'].match?(/\A[A-Za-z0-9_.$]+\z/) && event['transformer'].is_a?(String) && event['subject'].is_a?(String) && %w[running passed failed].include?(event['outcome'])
          raise Failure, 'Malformed Jetifier transform event'
        end
        reasons << 'unreviewed_transform_implementation' unless event['implementation'] == 'com.android.build.gradle.internal.dependency.JetifyTransform'
        reasons << 'transform_did_not_finish_successfully' unless event['outcome'] == 'passed'
        input = event.fetch('input_identity')
        if input['state'] == 'verified'
          identity!(input.fetch('identity'))
        elsif input['state'] == 'unavailable' && !input['reason'].to_s.empty?
          reasons << 'executed_transform_input_bytes_unavailable' if event['action_count'] > 0
        else raise Failure, 'Invalid Jetifier transform input state'
        end
      end
      raise Failure, 'Jetifier event totals contradict observer counts' if transforms['planned_count'] + transforms.fetch('identified_count', 0) < transforms['events'].size || transforms['action_count'] < actions
      disabled = !projects.empty? && projects.all? { |p| p['state'] == 'collected' && p['enabled'] == false }
      reasons << 'disabled_options_with_observed_jetifier_action' if disabled && actions > 0
      state = if !reasons.empty? then 'incomplete'
              elsif disabled && actions.zero? then 'bounded_disabled'
              else 'review_required'
              end
      base.merge('state' => state, 'producer_raw_sha256' => packet['raw_sha256'], 'projects' => projects, 'transforms' => transforms, 'reasons' => reasons.uniq.sort)
    rescue KeyError, TypeError, NoMethodError
      raise Failure, 'Malformed Jetifier condition evidence'
    end

    def self.read(packets)
      raise Failure, 'Missing delegated Jetifier producer set' unless packets.is_a?(Array) && !packets.empty?
      builds = packets.map { |p| build(p) }
      state = if builds.all? { |b| b['state'] == 'bounded_disabled' } then 'bounded_disabled'
              elsif builds.any? { |b| %w[incomplete unmeasured].include?(b['state']) } then 'incomplete'
              else 'review_required'
              end
      { 'schema' => 1, 'state' => state, 'scope' => 'observed_generated_android_debug_builds', 'builds' => builds,
        'producer_sha256' => Maintenance.digest(packets), 'advisory_state' => 'review_required', 'mitigation_verified' => false,
        'adoption_authorized' => false, 'limits' => %w[not_all_variants not_parser_unreachability not_shaded_inventory not_policy_waiver] }
    end
  end
end
