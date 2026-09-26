# frozen_string_literal: true

require_relative 'common'

module Maintenance
  class ElixirFixture
    FILE = 'backend/mix.lock.fixture'
    def initialize(root, scenario: 'pass', timeout: 5)
      content = scenario == 'baseline-failure' ? "dependency=2.0.0\n" : "dependency=1.0.0\n"
      FileUtils.mkdir_p(File.join(root, 'backend')); File.write(File.join(root, FILE), content)
      @plan = FixtureContract.plan('fixture-elixir', FILE, content, scenario, timeout)
    end
    def plan
      @plan
    end
    def code_files
      [__FILE__, File.expand_path('common.rb', __dir__), FixtureContract::CHECK]
    end
  end
end
