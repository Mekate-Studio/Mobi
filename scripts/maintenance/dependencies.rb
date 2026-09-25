# frozen_string_literal: true

require_relative 'lib/tools'
require_relative 'lib/policy'
require_relative 'adapters/elixir'

module Maintenance
  def self.discover(root, tools: Tools.new(root))
    tools.verify!
    source = Source.new(root)
    native = NativeExtraction.run(source, tools)
    config = JSON.parse(File.read(File.join(root, 'renovate.json')))
    adapter = if source.files.key?('project.yaml') && source.files.key?('kotlin')
                require_relative 'adapters/kotlin'
                Kotlin.new(root, source.files, native, config).inventory
              else
                { 'adapter' => 'kotlin', 'state' => 'not_applicable', 'components' => [], 'coverage' => [], 'resolved_inputs' => [] }
              end
    backend = Elixir.inventory(source.files)
    adapter['coverage'] << { 'id' => 'elixir:activation', 'state' => 'incomplete', 'reason' => backend['reason'], 'required' => true } if backend['state'] == 'incomplete'
    policy = JSON.parse(File.read(File.join(root, 'maintenance-policy.json')))
    Policy.new(policy)
    source.verify!
    result = { 'schema' => 1, 'created_at' => Time.now.utc.iso8601, 'state' => 'inventory_recorded',
               'source' => source.public_identity, 'tools' => { 'identity' => tools.identity, 'pins' => tools.pins },
               'policy' => policy, 'policy_sha256' => Maintenance.digest(policy),
               'native_extraction' => native, 'adapters' => { 'kotlin' => adapter.reject { |key, _| %w[components coverage resolved_inputs].include?(key) }, 'elixir' => backend },
               'components' => adapter['components'], 'coverage' => adapter['coverage'], 'resolved_inputs' => adapter['resolved_inputs'],
               'release_discovery' => 'not_requested', 'vulnerability_status' => 'incomplete', 'adoption_authorized' => false }
    result['id'] = Maintenance.digest(result)
    result
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    root = File.expand_path('../..', __dir__)
    trap('TERM') { raise Interrupt }
    command = ARGV.shift || 'discover'
    case command
    when 'install'
      raise Maintenance::Failure, 'Usage: install [--repair]' unless ARGV.empty? || ARGV == ['--repair']
      puts JSON.pretty_generate('state' => 'installed', 'identity' => Maintenance::Tools.new(root).install!(repair: ARGV == ['--repair']))
    when 'verify'
      raise Maintenance::Failure, 'Usage: verify' unless ARGV.empty?
      puts JSON.pretty_generate('state' => 'verified', 'identity' => Maintenance::Tools.new(root).verify!)
    when 'discover'
      raise Maintenance::Failure, 'Usage: discover (JSON goes to stdout; redirect outside source inputs)' unless ARGV.empty?
      puts JSON.pretty_generate(Maintenance.discover(root))
    when 'evaluate'
      raise Maintenance::Failure, 'Usage: evaluate <inventory.json> <evidence.json>' unless ARGV.size == 2
      inventory, evidence = ARGV.map { |path| JSON.parse(File.read(path)) }
      policy = JSON.parse(File.read(File.join(root, 'maintenance-policy.json')))
      raise Maintenance::Failure, 'Policy changed since inventory capture; rerun discovery' unless inventory['policy_sha256'] == Maintenance.digest(policy)
      result = Maintenance::Policy.new(policy).evaluate(inventory, evidence)
      puts JSON.pretty_generate(result)
      exit(result['state'] == 'checks_passed' ? 0 : 2)
    else
      raise Maintenance::Failure, 'Usage: dependency_updates.sh [discover|verify|evaluate <inventory.json> <evidence.json>]'
    end
  rescue StandardError, Interrupt => error
    warn JSON.generate('schema' => 1, 'state' => 'failed', 'message' => error.message)
    exit 1
  end
end
