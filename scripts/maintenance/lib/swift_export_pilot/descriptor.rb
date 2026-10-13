# frozen_string_literal: true

require_relative '../swift_export/descriptor'

module Maintenance
  module SwiftExportPilot
    # Reuse the locked compiler recipe with an explicit real-app source closure.
    class Descriptor < SwiftExport::Descriptor
      attr_reader :compose
      def initialize(root:, profile:, repository_policy:, compose:, simulator_major: 26)
        raise Failure, 'Explicit Compose selection required' unless %w[enabled disabled].include?(compose)
        raise Failure, 'Pilot simulator major must be 26 or 27' unless [26, 27].include?(simulator_major)
        @compose = compose
        super(root: root, path: 'scripts/maintenance/swift-export-inputs.json', profile: profile, repository_policy: repository_policy)
        data['id'] = 'swift-export-app-pilot'
        data['pilot_scope'] = 'opt-in-real-app'
        data['compose'] = compose
        data['pilot_simulator_major'] = simulator_major
        shared = data['modules'].select { |m| %w[MobiCore MobiHome MobiNearby MobiDI].include?(m['name']) || (compose == 'enabled' && m['name'] == 'MobiUI') }
        shared.each do |entry|
          folder = entry['inputs'].first
          entry['inputs'] = [folder + '/module.yaml'] + Dir.glob(File.join(@root, folder, 'src*/**/*.kt')).map { |path| path.delete_prefix(@root + '/') }.sort
        end
        transport = [
          { 'name' => 'MobiHomeTransport', 'visibility' => 'full', 'dependencies' => %w[MobiCore MobiHome], 'inputs' => ['shared-ios-export/src/HomeFacade.kt'] },
          { 'name' => 'MobiNearbyTransport', 'visibility' => 'full', 'dependencies' => %w[MobiCore MobiNearby], 'inputs' => ['shared-ios-export/src/NearbyFacade.kt'] },
          { 'name' => 'MobiAppComposition', 'visibility' => 'full', 'dependencies' => %w[MobiDI MobiHomeTransport MobiNearbyTransport], 'inputs' => ['shared-ios-export/src/AppComposition.kt'] }
        ]
        transport << { 'name' => 'MobiSharedUIOwner', 'visibility' => 'full', 'dependencies' => %w[MobiHome MobiUI], 'inputs' => ['shared-ios-export-compose/src/HomeRouteOwner.kt'] } if compose == 'enabled'
        data['modules'] = shared + transport
        if compose == 'disabled'
          data['compiler']['external_libraries'].select! { |entry| entry['relative_path'].include?('/metro/runtime-iossimulatorarm64/') || entry['relative_path'].include?('/kotlinx-coroutines-core-iossimulatorarm64/') || entry['relative_path'].include?('/atomicfu-iossimulatorarm64/') }
        end
        data['native']['sources'] = Dir.glob(File.join(@root, 'ios-app/pilot/swift/*.swift')).map { |p| p.delete_prefix(@root + '/') }.sort
        data['native']['sources'] += Dir.glob(File.join(@root, 'ios-app/pilot/compose/*.swift')).map { |p| p.delete_prefix(@root + '/') }.sort if compose == 'enabled'
        data['inputs'] = {
          'generator' => ['scripts/maintenance/fixtures/swift-export/ExportHarness.kt.template', 'scripts/maintenance/fixtures/swift-export/ReorderedNearbyState.kt.template'],
          'schema' => ['ios-app/pilot/config/selection.json', 'ios-app/pilot/config/promotion-inventory.json', 'ios-app/pilot/tests', 'ios-app/module.xcodeproj/project.pbxproj'],
          'native' => data['native']['sources'],
          'build' => ['scripts/maintenance/lib/swift_export', 'scripts/maintenance/lib/swift_export_pilot', 'scripts/maintenance/swift-export-inputs.json', 'project.yaml', 'kotlin', 'shared-ios-export/module.yaml'] + (compose == 'enabled' ? ['shared-ios-export-compose/module.yaml'] : [])
        }
        validate!
      end

      def inspection
        result = super
        expected = JSON.parse(File.read(File.join(root, 'ios-app/pilot/config/selection.json'))).fetch('native_pins')
        expected.each do |name, state|
          pin = result['native_pins'].find { |value| value['identity'] == name }
          raise Failure, 'Approved native repair differs' unless pin && pin['state']['version'] == state['version'] && pin['state']['revision'] == state['revision']
        end
        project = File.read(File.join(root, 'ios-app/module.xcodeproj/project.pbxproj'))
        raise Failure, 'Matching Xcode Perception constraint missing' unless project.match?(/kind = exactVersion;\s*version = 2\.0\.10;/)
        result
      end
    end
  end
end
