# frozen_string_literal: true

require 'optparse'
require_relative 'lib/swift_export_pilot/descriptor'
require_relative 'lib/swift_export/tool_identity'

if $PROGRAM_NAME == __FILE__
  begin
    options = { 'experimental' => false }
    parser = OptionParser.new do |p|
      p.banner = 'Usage: swift_export_pilot.rb --action inspect|build|test --profile NAME --repository-policy NAME --compose enabled|disabled [--runtime-settings PATH --experimental --java-home PATH]'
      %w[action profile repository-policy compose runtime-settings java-home delivery origin-run].each { |key| p.on("--#{key} VALUE") { |value| options[key] = value } }
      p.on('--simulator-major VALUE', Integer) { |value| options['simulator-major'] = value }
      p.on('--experimental') { options['experimental'] = true }
    end
    parser.parse!(ARGV)
    raise Maintenance::Failure, parser.to_s unless ARGV.empty? && %w[inspect build test replay].include?(options['action'])
    root = File.expand_path('../..', __dir__)
    descriptor = Maintenance::SwiftExportPilot::Descriptor.new(root: root, profile: options['profile'], repository_policy: options['repository-policy'], compose: options['compose'], simulator_major: options.fetch('simulator-major', 26))
    java_home = options['java-home'] || ENV['JAVA_HOME']
    raise Maintenance::Failure, 'Explicit JDK installation required through --java-home or JAVA_HOME' unless java_home && File.executable?(File.join(java_home, 'bin/java'))
    tools = Maintenance::SwiftExport::ToolIdentity.capture(File.realpath(File.join(java_home, 'bin/java')))
    inspection = descriptor.inspection
    if options['action'] == 'inspect'
      puts JSON.pretty_generate('schema' => 1, 'source_identity' => Maintenance.digest(inspection['selected_files']), 'tuple_identity' => tools['identity'],
                                'profile' => descriptor.profile, 'repository_policy' => descriptor.repository_policy, 'compose' => descriptor.compose, 'selected_files' => inspection['selected_files'],
                                'production_selection' => 'pending')
      exit 0
    end
    raise Maintenance::Failure, 'Explicit runtime settings record required' unless options['runtime-settings']
    require_relative 'lib/swift_export_pilot/adapter'
    require_relative 'lib/executor'
    source = Maintenance::Source.new(root)
    adapter = Maintenance::SwiftExportPilot::Adapter.new(descriptor, java_home: java_home, settings_path: options['runtime-settings'], action: options['action'], experimental: options['experimental'], delivery: options['delivery'], origin_id: options['origin-run'])
    result = Maintenance::Executor.new(source: source, adapter: adapter, store: Maintenance::RunStore.new(File.join(root, '.maintenance/runs-swift-export-pilot')),
                                      policy: JSON.parse(File.read(File.join(root, 'maintenance-execution-policy.json'))), input_files: [File.realpath(options['runtime-settings'])]).run
    puts JSON.pretty_generate(result)
    exit Maintenance::Executor::EXIT_CODES.fetch(result['state'])
  rescue Maintenance::Failure, OptionParser::ParseError, KeyError, Errno::ENOENT, JSON::ParserError => e
    warn e.message
    exit 23
  end
end
