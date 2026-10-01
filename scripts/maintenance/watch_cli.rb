# frozen_string_literal: true

require_relative 'adapters/kotlin_watch'

module Maintenance
  module WatchCLI
    module_function

    def call(root, args)
      options = {}
      until args.empty?
        flag = args.shift
        raise Failure, 'Usage: watch-compatibility [--previous FILE] [--output .maintenance/watch-reports/NAME]' unless %w[--previous --output].include?(flag) && args.first && !options.key?(flag)
        options[flag] = args.shift
      end
      legacy = ENV.keys.grep(/\ASKIE_COMPAT_/)
      raise Failure, 'Legacy SKIE_COMPAT overrides are unsupported; review maintenance-compatibility.json instead' unless legacy.empty?
      history = ENV.fetch('MOBI_WATCH_HISTORY', 'local')
      raise Failure, 'Invalid watch history state' unless %w[local initial found incomplete].include?(history)
      watcher = CompatibilityWatch.new(root, previous: options['--previous'], output: options['--output'], history: history,
                                      scope: ENV.fetch('MOBI_WATCH_SCOPE', 'local'))
      report = watcher.run
      Watch.announce(report, summary_path: ENV['GITHUB_STEP_SUMMARY']) if ENV['GITHUB_ACTIONS'] == 'true'
      puts JSON.pretty_generate(report.merge('report_directory' => watcher.output.delete_prefix(root + '/')))
      report['operation_state'] == 'observation_recorded' ? 0 : 1
    end
  end
end
