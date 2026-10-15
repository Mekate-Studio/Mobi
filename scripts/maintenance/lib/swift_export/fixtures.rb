# frozen_string_literal: true

require_relative 'descriptor'

module Maintenance
  module SwiftExport
    module Fixtures
      def self.materialize(root, destination)
        source = File.join(root, 'scripts/maintenance/fixtures/swift-export')
        inputs = Descriptor.inventory(source, Dir.children(source))
        raise Failure, 'Fixture workspace already exists' if File.exist?(destination)
        Dir.mkdir(destination)
        outputs = {}
        inputs.each do |relative, identity|
          target_name = relative.delete_suffix('.template')
          raise Failure, 'Fixture output collision' if outputs.key?(target_name)
          target = Descriptor.safe(destination, target_name)
          FileUtils.mkdir_p(File.dirname(target))
          FileUtils.cp(Descriptor.safe(source, relative), target, preserve: true)
          raise Failure, 'Materialized fixture bytes differ' unless Maintenance.file_sha(target) == identity['sha256']
          outputs[target_name] = identity.merge('source' => relative)
        end
        { 'directory' => destination, 'files' => outputs }
      end
    end
  end
end
