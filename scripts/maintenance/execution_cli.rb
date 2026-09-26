# frozen_string_literal: true

require_relative 'lib/recovery'

module Maintenance
  module ExecutionCLI
    def self.call(root, command, args)
      store_path = File.join(root, '.maintenance', 'runs')
      raise Failure, 'No execution store; run a fixture first' if command != 'rehearse-fixture' && !Dir.exist?(store_path)
      store = RunStore.new(store_path)
      case command
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
