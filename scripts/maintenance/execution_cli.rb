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

    def self.call(root, command, args)
      args = args.dup
      if command == 'prepare-kotlin'
        raise Failure, 'Usage: prepare-kotlin (downloads only reviewed wrappers)' unless args.empty?
        require_relative 'lib/kotlin_wrappers'
        identity = KotlinWrappers.new(root).prepare!
        return [{ 'schema' => 1, 'operation' => command, 'state' => 'prepared', 'identity' => identity, 'adoption_authorized' => false }, 0]
      end
      store_path = self.store_path(root, args)
      raise Failure, 'No execution store; run a rehearsal first' if !%w[rehearse-fixture rehearse-kotlin rehearse-support].include?(command) && !Dir.exist?(store_path)
      store = RunStore.new(store_path)
      case command
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
