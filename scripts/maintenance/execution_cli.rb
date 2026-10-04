# frozen_string_literal: true

require_relative 'lib/recovery'

module Maintenance
  module ExecutionCLI
    def self.store_path(root, args)
      name = nil
      if args.include?('--store')
        raise Failure, 'Use a trailing --store NAME with lowercase letters, digits and hyphens' unless args.size >= 2 && args[-2] == '--store' && args.count('--store') == 1 && args[-1].match?(/\A[a-z][a-z0-9-]{0,39}\z/)
        name = args.pop; args.pop
      end
      File.join(root, '.maintenance', name ? 'runs-' + name : 'runs')
    end

    def self.archive_receipt!(path)
      raise Failure, 'Symlinked attribution/provider receipt' if File.symlink?(path)
      RunStore.atomic(path + '.' + Maintenance.file_sha(path) + '.json', JSON.parse(File.read(path))) if File.exist?(path)
    end

    def self.call(root, command, args)
      args = args.dup
      if command == 'prepare-kotlin'
        raise Failure, 'Usage: prepare-kotlin (downloads only reviewed wrappers)' unless args.empty?
        require_relative 'lib/kotlin_wrappers'
        identity = KotlinWrappers.new(root).prepare!
        return [{ 'schema' => 1, 'operation' => command, 'state' => 'prepared', 'identity' => identity, 'adoption_authorized' => false }, 0]
      end
      store_path = self.store_path(root, args)
      raise Failure, 'No execution store; run a rehearsal first' if !%w[rehearse-fixture rehearse-kotlin rehearse-support rehearse-compatibility rehearse-upstream].include?(command) && !Dir.exist?(store_path)
      store = RunStore.new(store_path)
      case command
      when 'attribute-bundled', 'bundled-report', 'review-bundled-advisories'
        require_relative 'lib/bundled_attribution'
        raise Failure, 'Usage: attribute-bundled|bundled-report|review-bundled-advisories RUN_ID [--store NAME]' unless args.size == 1
        id = args.first
        if command == 'attribute-bundled'
          config = BundledAttribution.configuration(root)
          original = CompatibilityReport.read(store, id)
          receipt = store.lock(id, create: false) do
            raise Failure, 'Original result changed before attribution' unless Maintenance.file_sha(store.path(id, '.result.json')) == original['result_sha256']
            path = File.join(store.path(id), 'bundled-attribution.json')
            archive_receipt!(path)
            provider = File.join(store.path(id), 'bundled-advisory-review.json')
            archive_receipt!(provider)
            File.unlink(provider) if File.exist?(provider)
            BundledAttribution.collect(root, original, config, checkpoint: ->(packet) { RunStore.atomic(path, packet) })
          end
          return [receipt, 20] unless receipt['state'] == 'collected'
        end
        report = BundledAttribution.report(root, store, id)
        if command == 'review-bundled-advisories'
          store.lock(id, create: false) do
            raise Failure, 'Original result changed before bundled advisory collection' unless Maintenance.file_sha(store.path(id, '.result.json')) == report['result_sha256']
            path = File.join(store.path(id), 'bundled-advisory-review.json')
            archive_receipt!(path)
            AdvisoryReview.collect(report, checkpoint: ->(packet) { RunStore.atomic(path, packet) })
          end
          report = BundledAttribution.report(root, store, id)
        end
        complete = command != 'review-bundled-advisories' || report['direct_advisories'] && %w[provider_complete triage_required].include?(report['direct_advisories']['state'])
        [report, complete ? 0 : 20]
      when 'rehearse-upstream'
        require_relative 'adapters/upstream_remediation'
        raise Failure, 'Experimental flag must appear once' if args.count('--experimental') > 1
        experimental = args.delete('--experimental')
        profile = 'build-inputs'
        if args.include?('--profile')
          position = args.index('--profile')
          raise Failure, 'Usage: --profile build-inputs|mobile|android-packaging|ios-release|ios-archive' unless args.count('--profile') == 1 && args[position + 1]
          profile = args.slice!(position, 2).last
        end
        compile_sdk = nil
        unless args.empty?
          raise Failure, 'Usage: rehearse-upstream [--experimental] [--compile-sdk 37] [--profile build-inputs|mobile|android-packaging|ios-release|ios-archive] [--store NAME]' unless args == %w[--compile-sdk 37]
          compile_sdk = 37
        end
        source = Source.new(root)
        adapter = UpstreamRemediationRehearsal.new(root, source: source, experimental: !experimental.nil?, compile_sdk: compile_sdk, profile: profile)
        policy_path = File.join(root, 'maintenance-execution-policy.json')
        result = Executor.new(source: source, adapter: adapter, store: store, policy: JSON.parse(File.read(policy_path)),
                              input_files: [policy_path, __FILE__, File.join(root, 'scripts/maintenance/dependencies.rb')]).run
        [result, Executor::EXIT_CODES.fetch(result['state'])]
      when 'rehearse-compatibility'
        require_relative 'adapters/compatibility'
        raise Failure, 'Experimental flag must appear once' if args.count('--experimental') > 1
        experimental = args.delete('--experimental')
        raise Failure, 'Usage: rehearse-compatibility <bridge-compile|bridge-mobile|bridge-review|direct-facade|direct-roundtrip|direct-resolution|direct-build-inputs|direct-mobile> [--experimental] [--store NAME]' unless args.size == 1
        source = Source.new(root)
        adapter = CompatibilityRehearsal.new(root, source: source, profile: args.first, experimental: !experimental.nil?)
        policy_path = File.join(root, 'maintenance-execution-policy.json')
        result = Executor.new(source: source, adapter: adapter, store: store, policy: JSON.parse(File.read(policy_path)),
                              input_files: [policy_path, __FILE__, File.join(root, 'scripts/maintenance/dependencies.rb')]).run
        [result, Executor::EXIT_CODES.fetch(result['state'])]
      when 'rehearse-plugin-attribution'
        require_relative 'adapters/plugin_attribution'
        raise Failure, 'Usage: rehearse-plugin-attribution BUILD_RUN_ID [--store NAME]' unless args.size == 1
        source = Source.new(root)
        adapter = PluginAttributionRehearsal.new(root, store: store, original_id: args.first)
        policy_path = File.join(root, 'maintenance-execution-policy.json')
        result = Executor.new(source: source, adapter: adapter, store: store, policy: JSON.parse(File.read(policy_path)),
                              input_files: [policy_path, __FILE__, File.join(root, 'scripts/maintenance/dependencies.rb')]).run
        [result, Executor::EXIT_CODES.fetch(result['state'])]
      when 'plugin-report'
        require_relative 'lib/plugin_attribution'
        raise Failure, 'Usage: plugin-report RUN_ID [--store NAME]' unless args.size == 1
        result = store.lock(args.first, create: false) { PluginAttribution.report(store, args.first) }
        [result, 0]
      when 'review-advisories'
        require_relative 'lib/compatibility_report'
        phase = 'candidate'
        if args.include?('--phase')
          raise Failure, 'Usage: review-advisories RUN_ID [--phase baseline|candidate] [--store NAME]' unless args.size == 3 && args[1] == '--phase' && %w[baseline candidate].include?(args[2])
          phase = args.pop; args.pop
        end
        raise Failure, 'Usage: review-advisories RUN_ID [--phase baseline|candidate] [--store NAME]' unless args.size == 1
        require_relative 'lib/plugin_attribution'
        report = if store.load(args.first).dig('binding', 'adapter') == 'plugin-attribution'
                   store.lock(args.first, create: false) { PluginAttribution.report(store, args.first) }
                 else
                   CompatibilityReport.read(store, args.first)
                 end
        summary = nil
        store.lock(args.first, create: false) do
          raise Failure, 'Resolution result changed before advisory collection' unless Maintenance.file_sha(store.path(args.first, '.result.json')) == report['result_sha256']
          path = File.join(store.path(args.first), phase == 'candidate' ? 'advisory-review.json' : 'advisory-review-baseline.json')
          if File.exist?(path)
            raise Failure, 'Symlinked advisory receipt' if File.symlink?(path)
            archive = File.join(store.path(args.first), 'advisory-review-' + phase + '-' + Maintenance.file_sha(path) + '.json')
            raise Failure, 'Symlinked advisory archive' if File.symlink?(archive)
            RunStore.atomic(archive, JSON.parse(File.read(path)))
          end
          receipt = AdvisoryReview.collect(report, phase: phase, checkpoint: ->(packet) { RunStore.atomic(path, packet) })
          summary = AdvisoryReview.verify!(receipt, report)
        end
        [summary, summary['state'] == 'provider_complete' ? 0 : 2]
      when 'compatibility-report'
        require_relative 'lib/compatibility_report'
        raise Failure, 'Usage: compatibility-report RUN_ID [--store NAME]' unless args.size == 1
        result = CompatibilityReport.read(store, args.first)
        [result, Executor::EXIT_CODES.fetch(result['state'])]
      when 'rehearse-kotlin', 'rehearse-support'
        require_relative 'adapters/kotlin_rehearsal'
        support = command == 'rehearse-support'
        if support
          raise Failure, 'Usage: rehearse-support <inputs|mobile> [--store NAME]' unless args.size == 1
          args.unshift(KotlinWrappers.new(root).pins.fetch('baseline'))
        else
          raise Failure, 'Usage: rehearse-kotlin <reviewed-version> <inputs|mobile> [current|apple-silicon] [--store NAME]' unless (2..3).cover?(args.size)
        end
        source = Source.new(root)
        adapter = KotlinRehearsal.new(root, source: source, candidate: args[0], profile: args[1], target_policy: args[2], support_policy: support)
        policy_path = File.join(root, 'maintenance-execution-policy.json')
        result = Executor.new(source: source, adapter: adapter, store: store, policy: JSON.parse(File.read(policy_path)),
                              input_files: [policy_path, __FILE__, File.join(root, 'scripts/maintenance/dependencies.rb')]).run
        [result, Executor::EXIT_CODES.fetch(result['state'])]
      when 'rehearse-fixture'
        raise Failure, 'Usage: rehearse-fixture <kotlin|elixir> [pass|candidate-failure|baseline-failure|missing|infrastructure|malformed|forged-success|timeout|source-drift|child-survivor]' unless (1..2).cover?(args.size) && %w[kotlin elixir].include?(args[0])
        language, scenario = args
        scenario ||= 'pass'
        raise Failure, 'Barrier is a contract-test-only fixture' if scenario == 'barrier'
        require_relative "fixtures/executor/#{language}"
        klass = language == 'kotlin' ? KotlinFixture : ElixirFixture
        result = nil
        Dir.mktmpdir('mobi-rehearsal-fixture-') do |input|
          env = { 'GIT_CONFIG_GLOBAL' => File::NULL, 'GIT_CONFIG_NOSYSTEM' => '1' }
          _, status = Open3.capture2e(env, '/usr/bin/git', 'init', '--quiet', input, unsetenv_others: true)
          raise Failure, 'Cannot initialize fixture source' unless status.success?
          adapter = klass.new(input, scenario: scenario, timeout: scenario == 'timeout' ? 1 : 10)
          policy_path = File.join(root, 'maintenance-execution-policy.json')
          policy = JSON.parse(File.read(policy_path))
          result = Executor.new(source: Source.new(input), adapter: adapter, store: store, policy: policy,
                                input_files: [policy_path, __FILE__, File.join(root, 'scripts/maintenance/dependencies.rb')]).run
        end
        [result, Executor::EXIT_CODES.fetch(result['state'])]
      when 'recover'
        raise Failure, 'Usage: recover RUN_ID [--stop|--hold|--release-hold]' unless (1..2).cover?(args.size) && (args.size == 1 || %w[--stop --hold --release-hold].include?(args[1]))
        result = Recovery.new(store).recover(args[0], action: args[1] && args[1].delete_prefix('--'))
        [result, result['state'] == 'quiescent' ? 0 : 23]
      when 'cleanup'
        raise Failure, 'Usage: cleanup RUN_ID [--apply] [--discard]' unless (1..3).cover?(args.size) && (args.drop(1) - %w[--apply --discard]).empty? && args.drop(1).uniq == args.drop(1)
        result = Recovery.new(store).cleanup(args[0], apply: args.include?('--apply'), discard: args.include?('--discard'))
        [result, result['state'] == 'cleanup_failed' ? 24 : 0]
      else
        raise Failure, 'Unsupported executor command'
      end
    rescue Failure, JSON::ParserError, SystemCallError => error
      # Detailed local journal/logs remain local; the CLI does not dump them.
      [{ 'schema' => 1, 'operation' => command, 'state' => 'refused', 'reason' => error.message,
         'adoption_authorized' => false }, 23]
    end
  end
end
