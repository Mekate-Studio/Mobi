# frozen_string_literal: true

require_relative '../core'

module Maintenance
  module SwiftExport
    module Packaging
      def self.inventory(root)
        Dir.glob(File.join(root, '**', '*'), File::FNM_DOTMATCH).reject { |p| %w[. ..].include?(File.basename(p)) }.each_with_object({}) do |path, files|
          raise Failure, 'Packaged resource symlink' if File.symlink?(path)
          next if File.directory?(path)
          raise Failure, 'Nonregular packaged resource' unless File.file?(path)
          files[path.delete_prefix(root + '/')] = Maintenance.file_sha(path)
        end
      end

      def self.verify(app, inputs:, base:, label:, command:)
        plist = JSON.parse(command.call(label + '-built-plist', ['/usr/bin/plutil', '-convert', 'json', '-o', '-', File.join(app, 'Info.plist')]))
        production = JSON.parse(command.call(label + '-production-plist', ['/usr/bin/plutil', '-convert', 'json', '-o', '-', inputs.fetch('production_plist')]))
        static = production.reject { |_, value| value.is_a?(String) && value.include?('$(') }
        static.each { |key, value| raise Failure, "Production plist key changed: #{key}" unless plist[key] == value }
        expansions = { 'CFBundleDevelopmentRegion' => 'en', 'CFBundleExecutable' => 'SwiftExportConsumer', 'CFBundleIdentifier' => inputs.fetch('app_configuration', {}).fetch('bundle_identifier', 'studio.mekate.mobi.maintenance.swift-export-candidate'), 'CFBundleName' => 'SwiftExportConsumer' }
        expansions.each { |key, value| raise Failure, "Plist expansion changed: #{key}" unless plist[key] == value }
        raise Failure, 'Built app violates single-scene contract' unless plist.dig('UIApplicationSceneManifest', 'UIApplicationSupportsMultipleScenes') == false
        icon = plist.dig('CFBundleIcons', 'CFBundlePrimaryIcon')
        raise Failure, 'Compiled production icon missing' unless icon && icon['CFBundleIconName'] == 'AppIcon' && icon['CFBundleIconFiles'].is_a?(Array) && !icon['CFBundleIconFiles'].empty?
        assets = File.join(app, 'Assets.car')
        names = JSON.parse(command.call(label + '-asset-index', ['/usr/bin/assetutil', '--info', assets])).filter_map { |entry| entry['Name'] }.uniq
        raise Failure, 'Compiled AppIcon rendition missing' unless names.any? { |name| name.start_with?('AppIcon') }
        map_assets = File.join(app, 'Frameworks/MapLibre.framework/Assets.car')
        raise Failure, 'MapLibre resources changed' unless Maintenance.file_sha(map_assets) == Maintenance.file_sha(File.join(inputs.fetch('package_products'), 'MapLibre.framework/Assets.car'))
        style = File.join(app, 'offline-style.json')
        raise Failure, 'Offline style changed' unless Maintenance.file_sha(style) == Maintenance.file_sha(File.join(base, 'offline-style.json'))
        if inputs.dig('app_configuration', 'runtime_resource')
          raise Failure, 'Embedded pilot settings changed' unless Maintenance.file_sha(File.join(app, 'pilot-runtime-settings.json')) == Maintenance.file_sha(File.join(base, 'pilot-runtime-settings.json'))
        end
        bundles = inputs.fetch('resource_bundles').to_h do |resource|
          built = File.join(app, File.basename(resource))
          raise Failure, 'Missing native resource bundle' unless File.directory?(built)
          expected = inventory(resource)
          raise Failure, 'Native resource bundle content changed' unless inventory(built) == expected
          [File.basename(resource), expected]
        end
        { 'production_static_plist_keys' => static.keys.sort, 'build_setting_expansions' => expansions, 'single_scene_verified' => true,
          'icon_names' => names, 'icon_files' => icon['CFBundleIconFiles'], 'compiled_assets_sha256' => Maintenance.file_sha(assets),
          'maplibre_assets_sha256' => Maintenance.file_sha(map_assets), 'offline_style_sha256' => Maintenance.file_sha(style), 'native_resource_bundles' => bundles }
      end
    end
  end
end
