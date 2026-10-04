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
    support = if source.files.key?('maintenance-support-policy.json')
                require_relative 'adapters/mobile_support'
                MobileSupport.new(root).assess(source: source)
              else
                { 'state' => 'not_configured', 'adoption_authorized' => false }
              end
    source.verify!
    result = { 'schema' => 1, 'created_at' => Time.now.utc.iso8601, 'state' => 'inventory_recorded',
               'source' => source.public_identity, 'tools' => { 'identity' => tools.identity, 'pins' => tools.pins },
               'policy' => policy, 'policy_sha256' => Maintenance.digest(policy),
               'native_extraction' => native, 'adapters' => { 'kotlin' => adapter.reject { |key, _| %w[components coverage resolved_inputs].include?(key) }, 'elixir' => backend },
               'components' => adapter['components'], 'coverage' => adapter['coverage'], 'resolved_inputs' => adapter['resolved_inputs'],
               'release_discovery' => 'not_requested', 'support_assessment' => support,
               'architecture_assessment' => { 'state' => 'manual_review_required', 'automatic_migration' => false },
               'vulnerability_status' => 'incomplete', 'adoption_authorized' => false }
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
    when 'assess-support'
      raise Maintenance::Failure, 'Usage: assess-support' unless ARGV.empty?
      require_relative 'adapters/mobile_support'
      result = Maintenance::MobileSupport.new(root).assess
      puts JSON.pretty_generate(result)
      exit(result['state'] == 'assessed' ? 0 : 2)
    when 'assess-compatibility'
      raise Maintenance::Failure, 'Usage: assess-compatibility' unless ARGV.empty?
      require_relative 'adapters/compatibility'
      puts JSON.pretty_generate(Maintenance::Compatibility.new(root).assessment)
    when 'watch-compatibility'
      require_relative 'watch_cli'
      exit Maintenance::WatchCLI.call(root, ARGV)
    when 'compatibility-watch-history'
      raise Maintenance::Failure, 'Usage: compatibility-watch-history (Actions environment required)' unless ARGV.empty?
      require_relative 'lib/watch_history'
      Maintenance::WatchHistory.from_environment!
    when 'rehearse-fixture', 'rehearse-kotlin', 'rehearse-support', 'rehearse-compatibility', 'rehearse-upstream', 'compatibility-report', 'rehearse-plugin-attribution', 'plugin-report', 'review-advisories', 'attribute-bundled', 'bundled-report', 'review-bundled-advisories', 'prepare-kotlin', 'recover', 'cleanup'
      require_relative 'execution_cli'
      result, code = Maintenance::ExecutionCLI.call(root, command, ARGV)
      puts JSON.pretty_generate(result)
      exit code
    when 'review-toolchain-risk'
      raise Maintenance::Failure, 'Usage: review-toolchain-risk' unless ARGV.empty?
      require_relative 'lib/toolchain_risk_review'
      result = Maintenance::ToolchainRiskReview.review(root)
      puts JSON.pretty_generate(result)
      exit(result['state'] == 'accepted_risk_for_scoped_manual_use' ? 0 : 2)
    when 'evaluate'
      raise Maintenance::Failure, 'Usage: evaluate <inventory.json> <evidence.json>' unless ARGV.size == 2
      inventory, evidence = ARGV.map { |path| JSON.parse(File.read(path)) }
      policy = JSON.parse(File.read(File.join(root, 'maintenance-policy.json')))
      raise Maintenance::Failure, 'Policy changed since inventory capture; rerun discovery' unless inventory['policy_sha256'] == Maintenance.digest(policy)
      result = Maintenance::Policy.new(policy).evaluate(inventory, evidence)
      puts JSON.pretty_generate(result)
      exit(result['state'] == 'checks_passed' ? 0 : 2)
    else
      raise Maintenance::Failure, 'Usage: dependency_updates.sh [discover|assess-support|assess-compatibility|watch-compatibility [--previous FILE] [--output DIR]|compatibility-watch-history|verify|evaluate <inventory.json> <evidence.json>|prepare-kotlin|rehearse-kotlin <version> <inputs|mobile> [current|apple-silicon]|rehearse-support <inputs|mobile>|rehearse-compatibility <bridge-compile|bridge-mobile|bridge-review|direct-facade|direct-roundtrip|direct-resolution|direct-build-inputs|direct-mobile|direct-ios-release|direct-ios-archive>|rehearse-upstream [--experimental] [--compile-sdk 37] [--profile build-inputs|mobile|android-packaging|ios-release|ios-archive]|compatibility-report RUN_ID|rehearse-plugin-attribution BUILD_RUN_ID|plugin-report RUN_ID|review-advisories RUN_ID|review-toolchain-risk|attribute-bundled RUN_ID|bundled-report RUN_ID|review-bundled-advisories RUN_ID|rehearse-fixture <kotlin|elixir> [case]|recover RUN_ID [--stop|--hold|--release-hold]|cleanup RUN_ID [--apply] [--discard]] (execution commands accept trailing --store NAME)'
    end
  rescue StandardError, Interrupt => error
    warn JSON.generate('schema' => 1, 'state' => 'failed', 'message' => error.message)
    exit 1
  end
end
