# frozen_string_literal: true

require 'minitest/autorun'
require_relative 'lib/swift_export/packaging'

class SwiftExportPackagingTest < Minitest::Test
  def test_compiled_resource_contract_and_negative_controls
    Dir.mktmpdir('mobi-packaging-') do |root|
      app = File.join(root, 'app'); base = File.join(root, 'base'); products = File.join(root, 'products'); bundle = File.join(root, 'Privacy.bundle')
      [app, base, products, bundle, File.join(app, 'Privacy.bundle'), File.join(app, 'Frameworks/MapLibre.framework'), File.join(products, 'MapLibre.framework')].each { |p| FileUtils.mkdir_p(p) }
      [File.join(app, 'Assets.car'), File.join(app, 'Frameworks/MapLibre.framework/Assets.car'), File.join(products, 'MapLibre.framework/Assets.car'), File.join(app, 'offline-style.json'), File.join(base, 'offline-style.json'), File.join(bundle, 'PrivacyInfo.xcprivacy'), File.join(app, 'Privacy.bundle/PrivacyInfo.xcprivacy')].each { |p| File.write(p, 'declared bytes') }
      production = { 'NSLocationWhenInUseUsageDescription' => 'Local location', 'CFBundleIdentifier' => '$(PRODUCT_BUNDLE_IDENTIFIER)' }
      metadata = production.merge('CFBundleIdentifier' => 'studio.mekate.mobi.maintenance.swift-export-candidate', 'CFBundleDevelopmentRegion' => 'en', 'CFBundleExecutable' => 'SwiftExportConsumer', 'CFBundleName' => 'SwiftExportConsumer', 'UIApplicationSceneManifest' => { 'UIApplicationSupportsMultipleScenes' => false }, 'CFBundleIcons' => { 'CFBundlePrimaryIcon' => { 'CFBundleIconName' => 'AppIcon', 'CFBundleIconFiles' => ['AppIcon60x60'] } })
      inputs = { 'production_plist' => File.join(base, 'Info.plist'), 'package_products' => products, 'resource_bundles' => [bundle] }
      command = lambda do |name, _argv|
        JSON.generate(name.end_with?('-production-plist') ? production : name.end_with?('-asset-index') ? [{ 'Name' => 'AppIcon' }] : metadata)
      end
      verify = -> { Maintenance::SwiftExport::Packaging.verify(app, inputs: inputs, base: base, label: 'test', command: command) }
      assert verify.call['single_scene_verified']
      privacy = File.join(app, 'Privacy.bundle/PrivacyInfo.xcprivacy')
      File.write(privacy, 'corrupt'); assert_raises(Maintenance::Failure) { verify.call }; File.write(privacy, 'declared bytes')
      extra = File.join(app, 'Privacy.bundle/stale'); File.write(extra, 'extra'); assert_raises(Maintenance::Failure) { verify.call }; File.delete(extra)
      metadata['UIApplicationSceneManifest']['UIApplicationSupportsMultipleScenes'] = true
      assert_raises(Maintenance::Failure) { verify.call }; metadata['UIApplicationSceneManifest']['UIApplicationSupportsMultipleScenes'] = false
      metadata['NSLocationWhenInUseUsageDescription'] = 'Changed'; assert_raises(Maintenance::Failure) { verify.call }; metadata['NSLocationWhenInUseUsageDescription'] = 'Local location'
      File.write(File.join(app, 'Frameworks/MapLibre.framework/Assets.car'), 'corrupt'); assert_raises(Maintenance::Failure) { verify.call }
      File.symlink(privacy, File.join(app, 'Privacy.bundle/escape')); assert_raises(Maintenance::Failure) { Maintenance::SwiftExport::Packaging.inventory(File.join(app, 'Privacy.bundle')) }
    end
  end
end
