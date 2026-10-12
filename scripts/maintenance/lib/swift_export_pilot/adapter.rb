# frozen_string_literal: true

require_relative '../swift_export/adapter'
require_relative '../swift_export/delivery'
require_relative 'descriptor'
require_relative 'review'

module Maintenance
  module SwiftExportPilot
    class Adapter < SwiftExport::Adapter
      def initialize(descriptor, java_home:, settings_path:, action:, experimental:, delivery: nil, origin_id: nil)
        super(descriptor, java_home: java_home)
        @settings_path = File.realpath(settings_path)
        @action, @experimental = action, experimental
        @pilot_delivery, @pilot_origin = delivery && File.realpath(delivery), origin_id
        @review = Review.settings(@settings_path, source_identity: Maintenance.digest(@inspection['selected_files']), tuple_identity: @tools['identity'], qualified: !experimental)
        if action == 'replay'
          require_relative '../swift_export/origin'
          raise Failure, 'Explicit replay delivery and origin ID required' unless @pilot_delivery && @pilot_origin
          graph = SwiftExport::Delivery.validate(@pilot_delivery)
          raise Failure, 'Replay app configuration differs' unless graph['profile'] == descriptor.profile && graph['repository_policy'] == descriptor.repository_policy && graph.dig('app_configuration', 'compose') == descriptor.compose
          @origin_receipt = SwiftExport::Origin.verify(RunStore.new(File.join(descriptor.root, '.maintenance/runs-swift-export-pilot')), @pilot_origin, SwiftExport::Delivery.verify(@pilot_delivery))
          origin = JSON.parse(File.read(@origin_receipt.fetch('check_path')))
          raise Failure, 'Replay requires passed integrated origin tests' unless origin.dig('runtime', 'status') == 'passed'
          descriptor.data['pilot_action'] = 'test'
          descriptor.data['runtime_settings'] = @review['limits'].merge('scope' => 'diagnostic-only')
          expected = Maintenance.digest([descriptor.inspection['identity'], @tools.reject { |key, _| key == 'locations' }, graph['enum_variant']])
          raise Failure, 'Replay shipping source/settings tuple differs' unless graph['input_identity'] == expected
        end
      end

      def plan
        if @action == 'replay'
          return { 'schema' => 1, 'id' => 'swift-export-pilot-replay', 'scope' => 'guarded-real-app-post-cleanup-replay', 'edits' => [],
                   'missing_capabilities' => %w[fresh_kotlin_production fresh_native_dependency_production hosted device minimum_runtime android_parity signed_release advisory_review],
                   'resource_types' => %w[filesystem process-group kotlin-native],
                   'checks' => [{ 'id' => 'swift-export-pilot-replay', 'required' => true, 'timeout_seconds' => 1300,
                                  'argv' => [File.realpath(RbConfig.ruby), File.join(__dir__, 'replay.rb'), '{source}', '{output}', '{cache}', @pilot_delivery,
                                             File.join(@descriptor.root, '.maintenance/runs-swift-export-pilot'), @pilot_origin, @descriptor.profile, @descriptor.repository_policy, @gem_path, JSON.generate(@tools)] }] }
        end
        { 'schema' => 1, 'id' => 'swift-export-app-pilot', 'scope' => 'opt-in-real-app-pilot', 'edits' => [],
          'missing_capabilities' => %w[production_default hosted published_clean_clone device minimum_runtime android_parity signed_release advisory_review],
          'resource_types' => %w[filesystem process-group kotlin-native],
          'checks' => [{ 'id' => 'swift-export-app-pilot', 'required' => true, 'timeout_seconds' => 1300,
                         'argv' => [File.realpath(RbConfig.ruby), File.join(__dir__, 'check.rb'), '{source}', '{output}', '{cache}',
                                    @descriptor.profile, @descriptor.repository_policy, @descriptor.compose, @java, @gem_path, JSON.generate(@tools), @settings_path, @action, @experimental.to_s] }] }
      end

      def code_files
        retained = @pilot_delivery ? SwiftExport::Delivery.files(@pilot_delivery).keys.map { |p| File.join(@pilot_delivery, p) } + [File.join(@pilot_delivery, SwiftExport::Delivery::MANIFEST), @origin_receipt.fetch('check_path')] : []
        super + retained + [@settings_path] + SwiftExport::Descriptor.inventory(@descriptor.root, ['scripts/maintenance/lib/swift_export_pilot', 'ios-app/pilot']).keys.map { |p| File.join(@descriptor.root, p) }
      end
    end
  end
end
