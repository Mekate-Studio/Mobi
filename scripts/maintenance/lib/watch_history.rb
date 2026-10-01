# frozen_string_literal: true

require_relative 'watch'

module Maintenance
  module WatchHistory
    module_function

    def lookup(repository:, branch:, current_run:, token:, fetcher: WatchHTTP.new)
      raise Failure, 'Invalid Actions history context' unless repository.match?(/\A[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+\z/) && !branch.empty? && current_run.match?(/\A[1-9]\d*\z/)
      query = URI.encode_www_form('branch' => branch, 'status' => 'completed', 'per_page' => 20)
      url = 'https://api.github.com/repos/' + repository + '/actions/workflows/dependency-compatibility.yml/runs?' + query
      response = fetcher.get(url, token: token)
      data = JSON.parse(response.fetch('body'))
      runs = data.fetch('workflow_runs')
      raise Failure, 'Invalid Actions run listing' unless runs.is_a?(Array) && runs.size <= 20
      valid_runs = runs.all? do |run|
        run.is_a?(Hash) && %w[id run_number run_attempt].all? { |key| run[key].is_a?(Integer) && run[key].positive? } &&
          %w[path head_branch status event].all? { |key| run[key].is_a?(String) }
      end
      raise Failure, 'Malformed Actions run' unless valid_runs
      matching = runs.select do |run|
        run['id'].is_a?(Integer) && run['id'].positive? && run['id'].to_s != current_run && run['head_branch'] == branch && run['status'] == 'completed' &&
          run['path'] == '.github/workflows/dependency-compatibility.yml' && %w[schedule workflow_dispatch].include?(run['event'])
      end
      latest = matching.max_by { |run| [Integer(run.fetch('run_number')), Integer(run.fetch('run_attempt', 1))] }
      return { 'state' => 'initial', 'run_id' => '' } unless latest
      { 'state' => 'found', 'run_id' => latest['id'].to_s }
    rescue Failure, JSON::ParserError, KeyError, TypeError, ArgumentError, NoMethodError
      { 'state' => 'incomplete', 'run_id' => '' }
    end

    def from_environment!
      result = lookup(repository: ENV.fetch('GITHUB_REPOSITORY'), branch: ENV.fetch('GITHUB_REF_NAME'),
                      current_run: ENV.fetch('GITHUB_RUN_ID'), token: ENV['GITHUB_TOKEN'])
      File.open(ENV.fetch('GITHUB_OUTPUT'), 'a') { |file| result.each { |key, value| file.puts key + '=' + value } }
      puts JSON.generate(result)
    end
  end
end

Maintenance::WatchHistory.from_environment! if $PROGRAM_NAME == __FILE__
