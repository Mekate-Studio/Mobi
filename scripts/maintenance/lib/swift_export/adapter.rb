# frozen_string_literal: true

require_relative 'descriptor'
require_relative 'tool_identity'
require 'rbconfig'

module Maintenance
  module SwiftExport
    class Adapter
      def initialize(descriptor, java_home:, replay_delivery: nil, origin_id: nil)
        @descriptor = descriptor
        raise Failure, 'An explicit JDK installation is required for rehearsal' unless java_home && File.executable?(File.join(java_home, 'bin/java'))
        @java = File.realpath(File.join(java_home, 'bin/java'))
        @tools = ToolIdentity.capture(@java)
        gem 'xcodeproj', '= 1.28.1'
        require 'xcodeproj'
        @gems = Gem.loaded_specs.values
        @gem_path = Gem.path.join(File::PATH_SEPARATOR)
        @inspection = descriptor.inspection
        @replay_delivery, @origin_id = replay_delivery, origin_id
        if @replay_delivery
          require_relative 'delivery'
          require_relative 'origin'
          @replay_delivery = File.realpath(@replay_delivery)
          Delivery.verify(@replay_delivery)
          raise Failure, 'Replay requires an origin run ID' unless @origin_id.to_s.match?(RunStore::ID)
          @origin_receipt = Origin.verify(RunStore.new(File.join(@descriptor.root, '.maintenance/runs-swift-export')), @origin_id, Delivery.verify(@replay_delivery))
        end
      end

      def plan
        if @replay_delivery
          return { 'schema' => 1, 'id' => 'swift-export-replay', 'scope' => 'post_cleanup_source_archive_replay', 'edits' => [],
                   'resource_types' => %w[filesystem process-group kotlin-native], 'missing_capabilities' => %w[fresh_kotlin_production fresh_native_dependency_production production_adoption hosted device signed_release advisory_review],
                   'checks' => [{ 'id' => 'swift-export-replay', 'required' => true, 'timeout_seconds' => 1300,
                                  'argv' => [File.realpath(RbConfig.ruby), File.join(__dir__, 'replay.rb'), '{source}', '{output}', '{cache}', @replay_delivery,
                                             File.join(@descriptor.root, '.maintenance/runs-swift-export'), @origin_id, @descriptor.profile, @descriptor.repository_policy, @gem_path, JSON.generate(@tools)] }] }
        end
        { 'schema' => 1, 'id' => 'swift-export-candidate', 'scope' => 'optional_source_bound_swift_export_candidate', 'edits' => [],
          'missing_capabilities' => %w[production_adoption supported_toolchain_export hosted device minimum_runtime android_parity signed_release advisory_review],
          'resource_types' => %w[filesystem process-group kotlin-native],
          'checks' => [{ 'id' => 'swift-export', 'required' => true, 'timeout_seconds' => 1300,
                         'argv' => [File.realpath(RbConfig.ruby), File.join(__dir__, 'check.rb'), '{source}', '{output}', '{cache}',
                                    @descriptor.path.delete_prefix(@descriptor.root + '/'), @descriptor.profile, @descriptor.repository_policy, @java, @gem_path, JSON.generate(@tools)] }] }
      end

      def code_files
        gem_files = @gems.flat_map { |g| Dir.glob(File.join(g.full_gem_path, 'lib', '**', '*')).select { |p| File.file?(p) } }
        selected = Descriptor.inventory(@descriptor.root, ['scripts/maintenance/lib/swift_export', 'scripts/maintenance/fixtures/swift-export', 'scripts/maintenance/adapters/kotlin_resources.rb']).keys.map { |p| File.join(@descriptor.root, p) }
        if @replay_delivery
          selected += Delivery.files(@replay_delivery).keys.map { |p| File.join(@replay_delivery, p) } + [File.join(@replay_delivery, Delivery::MANIFEST)]
          origin = File.join(@descriptor.root, '.maintenance/runs-swift-export', @origin_id)
          selected << @origin_receipt.fetch('check_path')
          selected += %w[.json .events.jsonl .result.json].map { |suffix| origin + suffix }.select { |p| File.file?(p) }
        end
        selected + gem_files + @tools['locations'].keys + [@descriptor.path]
      end
    end
  end
end
