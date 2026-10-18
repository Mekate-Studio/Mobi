# frozen_string_literal: true

require 'optparse'
require_relative 'lib/swift_export/descriptor'

if $PROGRAM_NAME == __FILE__
  begin
    trap('TERM') { raise Interrupt }
    options = {}
    command = ARGV.shift
    parser = OptionParser.new do |p|
      p.banner = 'Usage: ruby scripts/maintenance/swift_export.rb inspect|rehearse|replay --descriptor PATH --profile NAME --repository-policy NAME [--java-home PATH] [--delivery PATH --origin-run ID]'
      %w[descriptor profile repository-policy java-home delivery origin-run registry report reader].each { |key| p.on("--#{key} VALUE") { |v| options[key] = v } }
      %w[logical-bytes minimum-age-seconds expected-generation].each { |key| p.on("--#{key} INTEGER", Integer) { |v| options[key] = v } }
    end
    parser.parse!(ARGV)
    raise Maintenance::Failure, parser.to_s unless ARGV.empty?
    root = File.expand_path('../..', __dir__)
    if %w[registry-create publish collection-report collect recover-reader verify-delivery].include?(command)
      require_relative 'lib/swift_export/registry'
      if command == 'verify-delivery'
        puts JSON.pretty_generate('identity' => Maintenance::SwiftExport::Delivery.verify(options.fetch('delivery')))
      elsif command == 'registry-create'
        puts JSON.pretty_generate(Maintenance::SwiftExport::Registry.create(options.fetch('registry'), logical_bytes: options['logical-bytes'], minimum_age_seconds: options['minimum-age-seconds']).report)
      else
        registry = Maintenance::SwiftExport::Registry.new(options.fetch('registry'))
        value = case command
                when 'collection-report' then registry.report
                when 'collect' then registry.collect(JSON.parse(File.read(options.fetch('report'))))
                when 'recover-reader' then registry.recover(options.fetch('reader'))
                when 'publish' then registry.publish(registry.stage(options.fetch('delivery')), expected: options.fetch('expected-generation'))
                end
        puts JSON.pretty_generate(value)
      end
      exit 0
    end
    raise Maintenance::Failure, parser.to_s unless %w[inspect rehearse replay].include?(command) && options['descriptor']
    descriptor = Maintenance::SwiftExport::Descriptor.new(root: root, path: options['descriptor'], profile: options['profile'], repository_policy: options['repository-policy'])
    if command == 'inspect'
      puts JSON.pretty_generate(descriptor.inspection)
    else
      require_relative 'lib/swift_export/adapter'
      require_relative 'lib/executor'
      source = Maintenance::Source.new(root)
      adapter = Maintenance::SwiftExport::Adapter.new(descriptor, java_home: options['java-home'], replay_delivery: command == 'replay' ? options['delivery'] : nil, origin_id: options['origin-run'])
      raise Maintenance::Failure, 'Replay delivery required' if command == 'replay' && !options['delivery']
      result = Maintenance::Executor.new(source: source, adapter: adapter, store: Maintenance::RunStore.new(File.join(root, '.maintenance/runs-swift-export')),
                                       policy: JSON.parse(File.read(File.join(root, 'maintenance-execution-policy.json'))), input_files: [descriptor.path]).run
      puts JSON.pretty_generate(result)
      exit Maintenance::Executor::EXIT_CODES.fetch(result['state'])
    end
  rescue Maintenance::Failure, OptionParser::ParseError, KeyError, Errno::ENOENT, JSON::ParserError => e
    warn e.message
    exit 23
  end
end
