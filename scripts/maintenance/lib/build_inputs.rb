# frozen_string_literal: true

require_relative 'run_store'
require_relative 'upgrade_graph'

module Maintenance
  module BuildInputs
    COMPILERS = { '0.12.2' => '2.4.10', '0.13.0' => '2.4.20' }.freeze
    MODULES = %w[shared-core shared-di shared-feature-home shared-feature-nearby-vehicle-map shared-ui-home].freeze
    GAPS = %w[compiler_plugin_coordinate_attribution native_test_compiler_inputs native_bundle_internals shaded_code delegated_unrehearsed_configurations].freeze

    REQUIRED_CONFIGURATIONS = %w[debugCompileClasspath debugRuntimeClasspath debugAnnotationProcessorClasspath kotlinBuildToolsApiClasspath kotlinCompilerClasspath kotlinCompilerPluginClasspath kotlinCompilerPluginClasspathDebug androidJdkImage androidLintTool coreLibraryDesugaring].freeze

    def self.safe_file!(path, root)
      unless File.file?(path) && !File.symlink?(path) && File.realpath(path).start_with?(File.realpath(root) + '/')
        raise Failure, 'Build input artifact escaped owned storage'
      end
    end

    def self.capture(work, cache, home, control, compiler_version: '2.4.10')
      roots = { '{work}' => work, '{cache}' => cache, '{home}' => home }
      normalize = lambda do |value|
        case value
        when String
          roots.values.sort_by { |v| -v.size }.reduce(value) { |s, prefix| s.gsub(prefix, roots.key(prefix)) }
        when Array then value.map { |v| normalize.call(v) }
        when Hash then value.to_h { |k, v| [k, normalize.call(v)] }
        else value
        end
      end
      files = Dir.glob(File.join(work, 'build', '**', 'kotlin_cli_traces.jsonl')).sort
      raise Failure, 'Missing compiler telemetry producer' if files.empty?
      traces = files.map do |path|
        safe_file!(path, work)
        { 'source' => path.delete_prefix(work + '/'), 'raw_sha256' => Maintenance.file_sha(path),
          'payloads' => File.readlines(path).reject { |line| line.strip.empty? }.map { |line| normalize.call(JSON.parse(line)) } }
      end
      inputs = {}
      invocations(traces, compiler_version: compiler_version).each do |entry|
        entry.fetch('plugins').each do |token|
          root, prefix = roots.find { |key, _path| token.start_with?(key + '/') }
          raise Failure, 'Plugin path is outside owned roots' unless root
          path = File.join(prefix, token.delete_prefix(root + '/'))
          safe_file!(path, prefix)
          inputs[token] = { 'sha256' => Maintenance.file_sha(path), 'bytes' => File.size(path) }
        end
      end
      paths = Dir.glob(File.join(cache, 'gradle', 'mobi-delegated-evidence', '*.json')).sort
      raise Failure, 'Missing delegated Gradle observer output' if paths.empty?
      delegated = paths.map do |path|
        safe_file!(path, cache)
        { 'source' => File.basename(path), 'raw_sha256' => Maintenance.file_sha(path), 'data' => JSON.parse(File.read(path)) }
      end
      RunStore.atomic(File.join(control, 'compiler-traces.json'), traces)
      RunStore.atomic(File.join(control, 'selected-plugin-artifacts.json'), inputs)
      RunStore.atomic(File.join(control, 'delegated-graphs.json'), delegated)
    rescue JSON::ParserError
      raise Failure, 'Malformed build input producer output'
    end

    def self.attribute(value)
      return value['stringValue'] if value.key?('stringValue')
      if value.key?('intValue')
        raise Failure, 'Malformed integer compiler attribute' unless value['intValue'].to_s.match?(/\A-?\d+\z/)
        return Integer(value['intValue'])
      end
      return value['arrayValue'].fetch('values', []).map { |v| attribute(v) } if value.key?('arrayValue')
      return value['boolValue'] if value.key?('boolValue')
      raise Failure, 'Unsupported compiler telemetry attribute'
    end

    def self.invocations(traces, compiler_version: '2.4.10')
      rows = []
      traces.each do |file|
        raise Failure, 'Missing compiler trace identity' unless file['raw_sha256'].to_s.match?(/\A[0-9a-f]{64}\z/) && file['source'].is_a?(String) && file['payloads'].is_a?(Array)
        file['payloads'].each do |payload|
          payload.fetch('resourceSpans').each do |resource|
            resource.fetch('scopeSpans').each do |scope|
              scope.fetch('spans').each do |span|
                next unless %w[konanc kotlin-compilation].include?(span['name'])
                attrs = span.fetch('attributes').select { |item| %w[amper-module args compiler-args version compiler-version exit-code].include?(item['key']) }.to_h { |item| [item.fetch('key'), attribute(item.fetch('value'))] }
                args = attrs[span['name'] == 'konanc' ? 'args' : 'compiler-args']
                raise Failure, 'Incomplete compiler invocation arguments' unless args.is_a?(Array) && args.all? { |a| a.is_a?(String) }
                raise Failure, 'Failed compiler invocation cannot prove selection' if span.dig('status', 'code').to_s == '2' || span.dig('status', 'code') == 'STATUS_CODE_ERROR' || attrs['exit-code'] && attrs['exit-code'] != 0
                platform = if span['name'] == 'konanc'
                             targets = args.grep(/\A-target=/).map { |a| a.delete_prefix('-target=') }
                             args.each_with_index { |a, i| targets << args[i + 1] if a == '-target' }
                             raise Failure, 'Missing or ambiguous native compiler target' unless targets.size == 1
                             { 'ios_arm64' => 'iosArm64', 'ios_simulator_arm64' => 'iosSimulatorArm64' }.fetch(targets.first)
                           else
                             'android'
                           end
                raise Failure, 'Unexpected compiler version in invocation' unless (attrs['version'] || attrs['compiler-version']) == compiler_version
                plugins = args.grep(/\A-Xplugin=/).map { |a| a.delete_prefix('-Xplugin=') }.uniq.sort
                rows << { 'module' => attrs.fetch('amper-module'), 'platform' => platform,
                          'producer' => span['name'], 'version' => attrs['version'] || attrs['compiler-version'],
                          'span_id' => span.fetch('spanId'), 'plugins' => plugins, 'arguments_sha256' => Maintenance.digest(args) }
              end
            end
          end
        end
      end
      raise Failure, 'Missing compiler invocation evidence' if rows.empty?
      rows
    rescue KeyError, TypeError, NoMethodError
      raise Failure, 'Malformed compiler telemetry'
    end

    def self.delegated!(data)
      raise Failure, 'Unsupported delegated graph schema' unless data['schema'] == 1 && data['gradle'].to_s.match?(/\A\d+\.\d+(?:\.\d+)?\z/) && data['generated_task'].to_s.match?(/\A_android-app_[A-Za-z0-9]+\z/) && data['build_outcome'] == 'passed'
      rows = data.fetch('configurations')
      raise Failure, 'Missing delegated configuration inventory' unless rows.is_a?(Array) && !rows.empty?
      keys = rows.map { |row| row.values_at('project', 'owner', 'configuration') }
      raise Failure, 'Duplicate delegated graph scopes' unless keys.uniq == keys
      rows.each do |row|
        raise Failure, 'Unknown delegated configuration identity' unless row['project'].to_s.match?(/\A:[A-Za-z0-9_-]*\z/) && %w[settings buildscript project].include?(row['owner']) && row['configuration'].to_s.match?(/\A[A-Za-z0-9_-]+\z/) && [true, false].include?(row['resolvable']) && row['attributes'].is_a?(Hash)
        if !row['resolvable']
          raise Failure, 'Invalid delegated unresolved scope' unless row['state'] == 'not_resolvable'
          next
        end
        if row['owner'] == 'project' && !REQUIRED_CONFIGURATIONS.include?(row['configuration'])
          raise Failure, 'Unmeasured delegated scope lacks explicit state' unless row['state'] == 'not_collected' && row['reason'] == 'outside_android_debug_main_scope' && (row.keys & %w[nodes edges artifacts]).empty?
          next
        end
        raise Failure, 'Incomplete delegated resolution' unless row['state'] == 'resolved' && row['failures'] == [] && %w[nodes edges artifacts].all? { |key| row[key].is_a?(Array) }
        components = row['nodes'].map { |node| component!(node.fetch('component')); node.fetch('variants').each { |v| UpgradeGraph.variant!(v) }; node['component'] }
        row['edges'].each do |edge|
          component!(edge.fetch('from')); component!(edge.fetch('selected')); UpgradeGraph.variant!(edge.fetch('variant'))
          raise Failure, 'Unresolved delegated edge' unless edge['requested'].is_a?(String) && !edge['failure'] && components.include?(edge['from']) && components.include?(edge['selected'])
        end
        row['artifacts'].each do |artifact|
          component!(artifact.fetch('component')); UpgradeGraph.variant!(artifact.fetch('variant'))
          id = artifact.fetch('identity')
          unless artifact['name'].is_a?(String) && !artifact['name'].include?('/') && %w[file directory].include?(id['kind']) && id['sha256'].to_s.match?(/\A[0-9a-f]{64}\z/) && id['bytes'].is_a?(Integer) && id['bytes'] > 0 && (artifact['component']['kind'] == 'opaque' || components.include?(artifact['component']))
            raise Failure, 'Missing delegated artifact identity or component binding'
          end
          if id['kind'] == 'directory' && !(id['entries'].is_a?(Integer) && id['entries'] > 0 && id['digest_format'] == 'sorted_relative_file_hashes_and_symlinks_v1')
            raise Failure, 'Missing delegated directory fingerprint'
          end
        end
      end
      unless rows.any? { |r| r['owner'] == 'settings' && r['configuration'] == 'classpath' && r['resolvable'] && !r['artifacts'].empty? } &&
             %w[debugCompileClasspath debugRuntimeClasspath].all? { |name| rows.any? { |r| r['owner'] == 'project' && r['configuration'] == name && r['resolvable'] } }
        raise Failure, 'Missing delegated settings plugin or Android debug graph scope'
      end
      raise Failure, 'Unsafe delegated graph content' if JSON.generate(data).match?(%r{/Users/|/home/|/private/|Bearer |github_pat_})
      rows
    rescue KeyError, TypeError, NoMethodError
      raise Failure, 'Malformed delegated graph evidence'
    end

    def self.component!(component)
      case component['kind']
      when 'maven' then UpgradeGraph.component!(component)
      when 'project' then raise Failure, 'Invalid delegated project' unless component['id'].to_s.match?(/\A:[A-Za-z0-9_-]*\z/)
      when 'opaque' then raise Failure, 'Invalid delegated opaque artifact' unless component['id'].to_s.match?(/\A[0-9a-f]{64}\z/)
      else raise Failure, 'Unknown delegated component'
      end
    end

    def self.read(control, compiler_version: '2.4.10')
      traces, artifacts, delegated = %w[compiler-traces selected-plugin-artifacts delegated-graphs].map { |name| JSON.parse(File.read(File.join(control, name + '.json'))) }
      calls = invocations(traces, compiler_version: compiler_version)
      MODULES.each do |name|
        %w[android iosArm64 iosSimulatorArm64].each do |platform|
          selected = calls.select { |c| c['module'] == name && c['platform'] == platform }
          raise Failure, 'Missing required module/platform compiler plugin scope' unless !selected.empty? && selected.any? { |c| !c['plugins'].empty? }
        end
      end
      selected = calls.flat_map { |c| c['plugins'] }.uniq.sort
      raise Failure, 'Selected plugin fingerprint coverage differs' unless artifacts.keys.sort == selected
      artifacts.each do |path, identity|
        raise Failure, 'Unsafe selected plugin identity' unless path.match?(%r{\A\{(?:work|cache|home)\}/}) && (path.split('/') & %w[. ..]).empty? && identity['sha256'].to_s.match?(/\A[0-9a-f]{64}\z/) && identity['bytes'].is_a?(Integer) && identity['bytes'] > 0
      end
      rows = delegated.flat_map { |packet| delegated!(packet.fetch('data')) }
      pairs = rows.flat_map { |row| Array(row['nodes']).map { |n| n['component'] } }.select { |c| c['kind'] == 'maven' }.map { |c| [c['group'] + ':' + c['name'], c['version']] }.uniq.sort
      { 'schema' => 1, 'scope' => 'selected_compiler_plugin_paths_and_generated_android_configurations', 'invocations' => calls,
        'selected_plugin_artifacts' => artifacts, 'delegated_builds' => delegated.size, 'delegated_configurations' => rows.size, 'uncollected_configurations' => rows.count { |r| r['state'] == 'not_collected' },
        'delegated_queries' => pairs.map { |name, version| { 'package' => { 'ecosystem' => 'Maven', 'name' => name }, 'version' => version } },
        'producer_sha256' => { 'traces' => Maintenance.digest(traces), 'artifacts' => Maintenance.digest(artifacts), 'delegated' => Maintenance.digest(delegated) },
        'missing_capabilities' => GAPS, 'adoption_authorized' => false }
    end
  end
end
