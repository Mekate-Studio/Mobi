# frozen_string_literal: true

require_relative '../lib/core'
require 'yaml'

module Maintenance
  class InteropExperiment
    PROJECT = 'ios-app/module.xcodeproj/project.pbxproj'
    attr_reader :changes

    def initialize(work, fixture_root)
      @work, @fixture_root, @changes = work, fixture_root, []
    end

    def write(relative, content)
      path = File.join(@work, relative)
      raise Failure, 'Experiment path is symlinked' if relative.split('/').each_index.any? { |i| File.symlink?(File.join(@work, *relative.split('/').take(i + 1))) }
      before = File.file?(path) ? File.binread(path) : nil
      @changes << { 'path' => relative, 'before_sha256' => before && Digest::SHA256.hexdigest(before),
                    'after_sha256' => Digest::SHA256.hexdigest(content), 'content' => content }
      FileUtils.mkdir_p(File.dirname(path)); File.binwrite(path, content)
    end

    def prepare!
      bridge = File.join(@work, 'gradle-bridge')
      raise Failure, 'Experiment requires an intact baseline bridge' unless File.directory?(bridge) && !File.symlink?(bridge)
      raise Failure, 'Experiment contains stale build products' unless Dir.glob(File.join(@work, '**', '*')).none? { |p| p.end_with?('.framework', '.app', '.xcresult') || File.basename(p) == 'build' }
      removed = Dir.glob(File.join(bridge, '**', '*'), File::FNM_DOTMATCH).select { |p| File.file?(p) }
      removed.each do |path|
        raise Failure, 'Experiment bridge contains a symlink' if File.symlink?(path)
        @changes << { 'path' => path.delete_prefix(@work + '/'), 'before_sha256' => Maintenance.file_sha(path), 'after_sha256' => nil }
      end
      FileUtils.remove_entry_secure(bridge)
      manifest = File.read(File.join(@work, 'ios-app/module.yaml'))
      raise Failure, 'Unexpected iOS DI declaration' if manifest.include?('../shared-di')
      raise Failure, 'Unexpected iOS dependency layout' unless manifest.scan(/^dependencies:$/).size == 1
      write('ios-app/module.yaml', manifest.sub(/^dependencies:$/, "dependencies:\n  - ../shared-di"))
      project = File.read(File.join(@work, PROJECT))
      phase = project.lines.select { |line| line.include?('shellScript = ') && line.include?('KOTLIN_IOS_BUILDER') }
      raise Failure, 'Unexpected native integration phase' unless phase.size == 1 && project.scan('name = "Build Kotlin Framework";').size == 1
      script = "# !KOTLIN INTEGRATION STEP!\n# This script is managed by the Kotlin Toolchain, do not edit manually!\n\"${KOTLIN_CLI_WRAPPER_PATH}\" tool xcode-integration\n"
      replacement = "\t\t\tshellScript = #{JSON.generate(script)};\n"
      project = project.sub(phase.first, replacement).sub('name = "Build Kotlin Framework";', 'name = "Build Kotlin";')
      write(PROJECT, project)
      %w[kt swift].each do |extension|
        path = extension == 'kt' ? 'shared-di/src/MobiInteropProjection.kt' : 'ios-app/src/MobiInteropProjection.swift'
        raise Failure, 'Experiment facade already exists' if File.exist?(File.join(@work, path))
        write(path, File.read(File.join(@fixture_root, 'MobiInteropProjection.' + extension + '.template')))
      end
      relative = 'ios-app/src/Features/NearbyVehicleMap/NearbyVehicleMapFeature+State.swift'
      state = File.read(File.join(@work, relative))
      raise Failure, 'Unexpected native reason adapter' unless state.scan('switch reason {').size == 1
      write(relative, state.sub('switch reason {', 'switch onEnum(of: reason) {'))
      verify_absence!
      @changes
    end

    def verify_absence!
      raise Failure, 'Generated workspace restored the unavailable bridge' if File.exist?(File.join(@work, 'gradle-bridge')) || File.symlink?(File.join(@work, 'gradle-bridge'))
    end

    def self.reachable_modules(work, name = 'ios-app', visited = [])
      raise Failure, 'Invalid local module dependency' unless name.match?(/\A[a-z][a-z0-9-]*\z/)
      return visited if visited.include?(name)
      visited << name
      declaration = YAML.safe_load(File.read(File.join(work, name, 'module.yaml')))
      declaration.fetch('dependencies', []).each do |dependency|
        dependency = dependency.keys.first if dependency.is_a?(Hash)
        next unless dependency.is_a?(String) && dependency.start_with?('../')
        reachable_modules(work, dependency.delete_prefix('../'), visited)
      end
      visited.sort
    end
  end
end
