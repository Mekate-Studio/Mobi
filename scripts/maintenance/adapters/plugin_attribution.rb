# frozen_string_literal: true

require_relative '../lib/plugin_attribution'
require 'rbconfig'

module Maintenance
  class PluginAttributionRehearsal
    def initialize(root, store:, original_id:)
      config = JSON.parse(File.read(File.join(root, 'maintenance-plugin-resolution.json')))
      packet = PluginAttribution.input(store, original_id, config)
      java, status = Open3.capture2('/usr/libexec/java_home', '-v', '21')
      raise Failure, 'Plugin resolver requires JDK 21' unless status.success?
      packet['java_home'] = File.realpath(java.strip)
      # Host path is deliberately outside the public proof packet.
      host = { 'java_home' => packet.delete('java_home') }
      inputs = File.join(root, '.maintenance', 'plugin-inputs')
      raise Failure, 'Symlinked plugin input store' if File.symlink?(File.dirname(inputs)) || File.symlink?(inputs)
      FileUtils.mkdir_p(inputs)
      input = File.join(inputs, Maintenance.digest(packet) + '.json')
      host_file = File.join(inputs, Maintenance.digest(host) + '.json')
      { input => packet, host_file => host }.each do |path, value|
        if File.exist?(path)
          raise Failure, 'Plugin input identity changed' unless !File.symlink?(path) && JSON.parse(File.read(path)) == value
        else
          RunStore.atomic(path, value)
        end
      end
      @files = [__FILE__, input, host_file, File.join(host['java_home'], 'bin/java'), File.join(root, 'maintenance-plugin-resolution.json')]
      @files << File.join(root, 'scripts/maintenance/adapters/kotlin_resources.rb')
      @files += Dir.glob(File.join(root, 'scripts/maintenance/lib/*.rb'))
      @files += %w[scripts/maintenance/plugin_check.rb scripts/maintenance/adapters/plugin_resolution.gradle gradle-bridge/gradlew gradle-bridge/gradle/wrapper/gradle-wrapper.jar gradle-bridge/gradle/wrapper/gradle-wrapper.properties].map { |p| File.join(root, p) }
      @plan = { 'schema' => 1, 'id' => 'plugin-attribution', 'scope' => 'retained_paired_compiler_inputs', 'edits' => [],
                'resource_types' => %w[filesystem process-group kotlin-native], 'missing_capabilities' => PluginAttribution::GAPS,
                'checks' => [{ 'id' => 'plugin-attribution', 'required' => true, 'timeout_seconds' => 600,
                               'argv' => [File.realpath(RbConfig.ruby), File.join(root, 'scripts/maintenance/plugin_check.rb'), '{source}', '{output}', '{cache}', input, host_file] }] }
    end
    def plan; @plan; end
    def code_files; @files; end
  end
end
