# frozen_string_literal: true

require 'minitest/autorun'
require_relative 'lib/swift_export_pilot/descriptor'
require_relative 'lib/swift_export_pilot/adapter'

class SwiftExportPilotContractTest < Minitest::Test
  ROOT = File.expand_path('../..', __dir__)

  def descriptor(compose)
    Maintenance::SwiftExportPilot::Descriptor.new(root: ROOT, profile: 'coroutine-swift5', repository_policy: 'main-confined', compose: compose)
  end

  def test_native_configuration_excludes_compose_and_scenarios
    native = descriptor('disabled')
    inputs = native.inspection
    names = native.data['modules'].map { |value| value['name'] }
    refute_includes names, 'MobiUI'
    refute_includes names, 'MobiSharedUIOwner'
    assert native.data['native']['sources'].all? { |path| path.start_with?('ios-app/pilot/swift/') }
    refute native.data['native']['sources'].any? { |path| path.include?('RootScenario') || path.include?('Qualification') }
    atomicfu = native.data['compiler']['external_libraries'].select { |value| value['relative_path'].include?('/atomicfu-iossimulatorarm64/') }
    assert_equal 2, atomicfu.size, 'Coroutines cancellation requires atomicfu and its interop runtime'
    assert native.data['compiler']['external_libraries'].none? { |value| value['relative_path'].include?('/compose/') }
    assert inputs['native_pins'].any? { |value| value['identity'] == 'swift-syntax' && value['state']['version'] == '603.0.2' }
  end

  def test_compose_configuration_has_one_declared_delivery_and_real_sources
    composed = descriptor('enabled')
    names = composed.data['modules'].map { |value| value['name'] }
    assert_includes names, 'MobiUI'
    assert_includes names, 'MobiSharedUIOwner'
    assert_equal 1, names.count('MobiAppComposition')
    assert composed.data['native']['sources'].any? { |path| path.end_with?('/SharedHomeDemoView.swift') }
    composed.inspection
  end

  def test_compiler_input_identity_survives_owned_source_snapshot
    original = descriptor('disabled').inspection['selected_files']
    Dir.mktmpdir('mobi-pilot-source-') do |folder|
      copied = File.join(folder, 'source')
      Maintenance::Source.new(ROOT).copy_to(copied)
      snapshot = Maintenance::SwiftExportPilot::Descriptor.new(root: copied, profile: 'coroutine-swift5', repository_policy: 'main-confined', compose: 'disabled')
      assert_equal original, snapshot.inspection['selected_files']
      refute original.keys.any? { |path| path.end_with?('.DS_Store') }
    end
  end

  def test_replay_preflight_refuses_an_unsealed_delivery_without_producing_work
    parent = Maintenance::SwiftExport::Adapter
    original = parent.instance_method(:initialize)
    # This control exercises pilot replay preflight with a known tool identity;
    # no host JDK, Xcode, Gem discovery or producer is invoked.
    parent.define_method(:initialize) do |selected, **_options|
      @descriptor = selected
      @inspection = selected.inspection
      @tools = { 'identity' => 'b' * 64 }
    end
    Dir.mktmpdir('mobi-pilot-replay-') do |folder|
      selected = descriptor('disabled')
      settings = File.join(folder, 'settings.json')
      File.write(settings, JSON.generate('schema' => 1, 'status' => 'experimental',
        'source_identity' => Maintenance.digest(selected.inspection['selected_files']), 'tuple_identity' => 'b' * 64,
        'limits' => Maintenance::SwiftExportPilot::Review::LIMITS.to_h { |key| [key, 1] },
        'busy_retry_behavior' => 'reject-before-registration-and-manual-retry', 'rationale' => 'Preflight control'))
      error = assert_raises(Maintenance::Failure) do
        Maintenance::SwiftExportPilot::Adapter.new(selected, java_home: nil, settings_path: settings,
          action: 'replay', experimental: true, delivery: folder, origin_id: 'c' * 32)
      end
      assert_match(/delivery|manifest/i, error.message)
      assert_equal ['settings.json'], Dir.children(folder)
    end
  ensure
    parent.define_method(:initialize, original) if parent && original
  end

  def test_unknown_selections_refuse_without_fallback
    assert_raises(Maintenance::Failure) { descriptor('auto') }
    assert_raises(Maintenance::Failure) { Maintenance::SwiftExportPilot::Descriptor.new(root: ROOT, profile: 'auto', repository_policy: 'main-confined', compose: 'disabled') }
  end

  def test_simulator_selection_is_explicit_and_bound_to_delivery_inputs
    local = descriptor('disabled')
    hosted = Maintenance::SwiftExportPilot::Descriptor.new(root: ROOT, profile: 'coroutine-swift5', repository_policy: 'main-confined', compose: 'disabled', simulator_major: 27)
    assert_equal 26, local.data.fetch('pilot_simulator_major')
    assert_equal 27, hosted.data.fetch('pilot_simulator_major')
    refute_equal local.inspection.fetch('identity'), hosted.inspection.fetch('identity')
    assert_raises(Maintenance::Failure) { Maintenance::SwiftExportPilot::Descriptor.new(root: ROOT, profile: 'coroutine-swift5', repository_policy: 'main-confined', compose: 'disabled', simulator_major: 25) }
  end
end
