# frozen_string_literal: true

require_relative 'core'

module Maintenance
  module UpgradeGraph
    PREFIX = 'MOBI_RESOLUTION_JSON='

    def self.parse(text)
      records = text.lines.grep(/^#{PREFIX}/)
      raise Failure, 'Missing or duplicate bridge graph output' unless records.size == 1
      data = JSON.parse(records.first.delete_prefix(PREFIX))
      validate!(data)
      data
    rescue JSON::ParserError
      raise Failure, 'Malformed bridge graph output'
    end

    def self.validate!(data)
      rows = data.fetch('configurations')
      raise Failure, 'Unsupported bridge graph schema' unless data['schema'] == 1 && data['gradle'].to_s.match?(/\A\d+\.\d+(?:\.\d+)?\z/) && rows.is_a?(Array) && !rows.empty?
      keys = rows.map { |row| row.values_at('project', 'owner', 'configuration') }
      raise Failure, 'Duplicate bridge configurations' unless keys.uniq == keys
      rows.each do |row|
        unless row['project'].to_s.match?(/\A:(?:[A-Za-z0-9_-]+(?::[A-Za-z0-9_-]+)*)?\z/) && %w[project buildscript].include?(row['owner']) &&
               row['configuration'].to_s.match?(/\A[A-Za-z0-9_-]+\z/) && [true, false].include?(row['resolvable']) && row['attributes'].is_a?(Hash)
          raise Failure, 'Invalid bridge configuration identity'
        end
        if row['resolvable']
          raise Failure, 'Bridge resolution is incomplete' unless row['state'] == 'resolved' && row['nodes'].is_a?(Array) && row['edges'].is_a?(Array) && row['artifacts'].is_a?(Array) && row['failures'] == []
          row['nodes'].each { |node| component!(node.fetch('component')); raise Failure, 'Missing component variants' unless node['variants'].is_a?(Array) }
          row['nodes'].each { |node| node['variants'].each { |variant| variant!(variant) } }
          components = row['nodes'].map { |node| node['component'] }
          row['edges'].each do |edge|
            component!(edge.fetch('from')); component!(edge.fetch('selected')); variant!(edge.fetch('variant'))
            raise Failure, 'Unresolved bridge edge' if edge['failure'] || !edge['requested'].is_a?(String) || !components.include?(edge['from']) || !components.include?(edge['selected'])
          end
          row['artifacts'].each do |artifact|
            component!(artifact.fetch('component'))
            raise Failure, 'Artifact component is absent from graph' unless components.include?(artifact['component'])
            variant!(artifact.fetch('variant'))
            identity = artifact.fetch('identity')
            unless artifact['name'].is_a?(String) && !artifact['name'].empty? && !artifact['name'].include?('/') && identity['sha256'].to_s.match?(/\A[0-9a-f]{64}\z/) && identity['bytes'].is_a?(Integer) && identity['bytes'] > 0 && %w[file directory].include?(identity['kind']) && artifact['variant'].is_a?(Hash)
              raise Failure, 'Missing bridge artifact identity'
            end
            if identity['kind'] == 'directory' && !(identity['entries'].is_a?(Integer) && identity['entries'] > 0 && identity['digest_format'] == 'sorted_relative_file_hashes_and_symlinks_v1')
              raise Failure, 'Missing directory artifact fingerprint'
            end
          end
        else
          raise Failure, 'Invalid unresolvable configuration state' unless row['state'] == 'not_resolvable'
        end
      end
      %w[iosArm64 iosSimulatorArm64].each do |target|
        scoped = rows.select { |r| r['project'] == ':shared-kit' && r['owner'] == 'project' && r['resolvable'] && r['configuration'].downcase.include?(target.downcase) }
        raise Failure, 'Missing bridge target compile/test graph scope' unless scoped.any? { |r| r['configuration'].downcase.include?('compile') && !r['configuration'].downcase.include?('test') } && scoped.any? { |r| r['configuration'].downcase.include?('test') }
      end
      raise Failure, 'Missing bridge plugin classpath scope' unless rows.any? { |r| r['project'] == ':shared-kit' && r['owner'] == 'buildscript' && r['configuration'] == 'classpath' && r['resolvable'] && !r['artifacts'].empty? }
      raise Failure, 'Unsafe bridge graph content' if JSON.generate(data).match?(%r{/Users/|/home/|/private/|Bearer |github_pat_|gh[pousr]_})
      data
    rescue KeyError, TypeError, NoMethodError
      raise Failure, 'Malformed bridge graph evidence'
    end

    def self.component!(component)
      valid = component.is_a?(Hash) && case component['kind']
                                     when 'maven' then %w[group name version].all? { |key| component[key].is_a?(String) && component[key].match?(/\A[A-Za-z0-9_.+\-]+\z/) }
                                     when 'project' then component['id'].is_a?(String) && (component['id'] == 'root' || component['id'].match?(/\A(?:project|root project) [A-Za-z0-9_:'\- ]+\z/))
                                     else false
                                     end
      raise Failure, 'Invalid resolved component' unless valid
    end

    def self.variant!(variant)
      raise Failure, 'Missing selected variant identity' unless variant.is_a?(Hash) && variant['name'].is_a?(String) && !variant['name'].empty? && variant['attributes'].is_a?(Hash)
    end

    def self.maven_queries(bridge, toolchain)
      validate!(bridge)
      unless toolchain['format'] == 'toolchain-pretty-graph-v1' && toolchain['graphs'].is_a?(Array) && !toolchain['graphs'].empty?
        raise Failure, 'Missing Toolchain query input'
      end
      pairs = bridge['configurations'].flat_map { |row| Array(row['nodes']).map { |node| node['component'] } }.select { |c| c['kind'] == 'maven' }.map { |c| [c['group'] + ':' + c['name'], c['version']] }
      normalizations = []
      constraints = 0
      toolchain['graphs'].each do |graph|
        raise Failure, 'Missing Toolchain query nodes' unless graph['nodes'].is_a?(Array)
        graph['nodes'].each do |node|
          if node['constraint']
            constraints += 1
            next
          end
          coordinate = node['coordinate']; next unless coordinate
          component!({ 'kind' => 'maven', 'group' => coordinate['group'], 'name' => coordinate['name'], 'version' => coordinate.fetch('selected').split('@').first })
          selected = coordinate['selected']
          raise Failure, 'Unsupported Toolchain artifact suffix' unless selected.match?(/\A[A-Za-z0-9_.+\-]+(?:@(?:aar|jar|klib))?\z/)
          version = selected.split('@').first
          name = coordinate['group'] + ':' + coordinate['name']
          normalizations << { 'package' => name, 'label_version' => selected, 'query_version' => version } if selected != version
          pairs << [name, version]
        end
      end
      { 'scope' => 'named_resolved_maven_packages_only',
        'queries' => pairs.uniq.sort.map { |name, version| { 'package' => { 'ecosystem' => 'Maven', 'name' => name }, 'version' => version } },
        'normalizations' => normalizations.uniq.sort_by { |item| JSON.generate(item) },
        'constraint_nodes_excluded' => constraints,
        'provider_state' => 'not_queried',
        'limitations' => %w[shaded_code native_bundle_internals toolchain_delegated_android_plugin_graph swift_ruby_npm_dependencies],
        'adoption_authorized' => false }
    rescue KeyError, TypeError, NoMethodError
      raise Failure, 'Malformed Maven query input'
    end

    def self.diff(before, after)
      [before, after].each { |data| validate!(data) }
      normalized = [before, after].map do |data|
        data.fetch('configurations').to_h do |row|
          key = row.values_at('project', 'owner', 'configuration').join('/')
          nodes = Array(row['nodes']).map { |node| node.merge('variants' => node['variants'].sort_by { |v| JSON.generate(v) }) }
          [key, row.merge('nodes' => nodes.sort_by { |v| JSON.generate(v) }, 'edges' => Array(row['edges']).sort_by { |v| JSON.generate(v) }, 'artifacts' => Array(row['artifacts']).sort_by { |v| JSON.generate(v) })]
        end
      end
      left, right = normalized
      { 'schema' => 1, 'scope' => 'all_gradle_project_and_buildscript_configurations',
        'before_sha256' => Maintenance.digest(before), 'after_sha256' => Maintenance.digest(after),
        'added' => (right.keys - left.keys).sort, 'removed' => (left.keys - right.keys).sort,
        'changed' => (left.keys & right.keys).sort.select { |key| left[key] != right[key] },
        'adoption_authorized' => false }
    end
  end
end
