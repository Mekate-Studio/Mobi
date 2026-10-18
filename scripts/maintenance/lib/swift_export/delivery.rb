# frozen_string_literal: true

require_relative 'descriptor'
require_relative '../run_store'

module Maintenance
  module SwiftExport
    class Delivery
      MANIFEST = 'artifact-manifest.json'

      def self.files(path)
        raise Failure, 'Symlinked delivery root' if File.symlink?(path)
        root = File.realpath(path)
        Descriptor.inventory(root, Dir.children(root).reject { |n| n == MANIFEST })
      end

      def self.validate(path)
        root = File.realpath(path)
        graph = JSON.parse(File.read(Descriptor.safe(root, 'graph.json')))
        raise Failure, 'Unsupported delivery contract' unless graph['schema'] == 1 && graph['consumer_mode'] == '6' && Descriptor::PROFILES.include?(graph['profile']) && Descriptor::POLICIES.include?(graph['repository_policy']) && graph['input_identity'].to_s.match?(Descriptor::SHA)
        modules = graph.fetch('modules')
        names = modules.map { |m| m.fetch('name') }
        raise Failure, 'Unexpected generated module closure' unless names.uniq == names && names.sort == graph.fetch('expected_modules').sort && %w[KotlinCoroutineSupport KotlinRuntimeSupport ExportedKotlinPackages].all? { |n| names.include?(n) }
        expected_modes = names.to_h { |n| [n, graph['profile'] == 'generated-swift5' || n == 'KotlinCoroutineSupport' ? '5' : '6'] }
        raise Failure, 'Profile mode contract differs' unless graph['module_modes'] == expected_modes
        paths = [graph.fetch('archive'), graph.fetch('aliases'), graph.fetch('runtime_headers') + '/KotlinBase.h', graph['runtime_headers'] + '/module.modulemap']
        modules.each do |m|
          raise Failure, 'Invalid generated module' unless m['name'].match?(Descriptor::NAME) && m['dependencies'].is_a?(Array) && (m['dependencies'] - names).empty?
          paths << m.fetch('swift')
          if m['kind'] == 'bridge'
            raise Failure, 'Invalid bridge name' unless m['bridge'].to_s.match?(Descriptor::NAME)
            paths += [m.fetch('kotlin'), m.fetch('header'), m.fetch('modulemap')]
            text = File.read(Descriptor.safe(root, m['modulemap']))
            raise Failure, 'Nonrelocatable bridge modulemap' unless text == "module #{m['bridge']} { header \"#{File.basename(m['header'])}\" export * }\n"
          elsif m['kind'] != 'swift'
            raise Failure, 'Unknown generated module kind'
          end
        end
        native = graph.fetch('native')
        %w[sources macros products resources].each do |key|
          raise Failure, "Missing native #{key} closure" unless native[key].is_a?(Array) && !native[key].empty?
          paths += native[key]
        end
        paths += [native.fetch('plist'), native.fetch('assets'), native.fetch('offline_style')]
        paths.each { |p| raise Failure, "Missing delivery member: #{p}" unless File.exist?(Descriptor.safe(root, p)) }
        raise Failure, 'Joint archive changed' unless Maintenance.file_sha(Descriptor.safe(root, graph['archive'])) == graph['archive_sha256']
        raise Failure, 'Missing producer/consumer provenance' unless graph['provenance'].is_a?(Hash) && %w[kotlin native].all? { |k| graph['provenance'][k].is_a?(Hash) && !graph['provenance'][k].empty? }
        ordered = []
        until ordered.size == names.size
          next_module = modules.find { |m| !ordered.include?(m['name']) && (m['dependencies'] - ordered).empty? }
          raise Failure, 'Invalid generated dependency closure' unless next_module
          ordered << next_module['name']
        end
        members = files(root) # Also check every directory/member for escapes.
        raise Failure, 'Undeclared/missing delivery members' unless graph['expected_members'].is_a?(Array) && graph['expected_members'].uniq == graph['expected_members'] && graph['expected_members'].sort == members.keys.sort
        graph
      rescue JSON::ParserError, KeyError, NoMethodError, TypeError, Errno::ENOENT
        raise Failure, 'Malformed or incomplete delivery'
      end

      def self.seal(path)
        raise Failure, 'Already sealed delivery' if File.exist?(File.join(path, MANIFEST)) || File.symlink?(File.join(path, MANIFEST))
        validate(path)
        members = files(path)
        identity = Maintenance.digest(members)
        RunStore.atomic(File.join(path, MANIFEST), 'schema' => 1, 'identity' => identity, 'files' => members)
        identity
      end

      def self.verify(path)
        validate(path)
        member = Descriptor.safe(File.realpath(path), MANIFEST)
        manifest = JSON.parse(File.read(member))
        actual = files(path)
        raise Failure, 'Delivery hash/inventory mismatch' unless manifest['schema'] == 1 && manifest['files'] == actual && manifest['identity'] == Maintenance.digest(actual)
        manifest['identity']
      rescue JSON::ParserError, Errno::ENOENT
        raise Failure, 'Missing/malformed delivery manifest'
      end
    end
  end
end
