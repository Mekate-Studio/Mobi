# frozen_string_literal: true

require_relative '../../lib/core'
require 'rbconfig'

module Maintenance
  module FixtureContract
    CASES = %w[pass baseline-failure candidate-failure missing infrastructure malformed forged-success timeout source-drift child-survivor barrier].freeze
    CHECK = File.expand_path('check.rb', __dir__)
    def self.plan(id, file, content, scenario, timeout)
      raise Failure, 'Unknown fixture scenario' unless CASES.include?(scenario)
      candidate = scenario == 'candidate-failure' ? "dependency=2.0.0\n" : "dependency=1.0.1\n"
      { 'schema' => 1, 'id' => id, 'scope' => 'synthetic_adapter_contract',
        'resource_types' => %w[filesystem process-group], 'missing_capabilities' => %w[native_builds resolved_graphs provider_evidence release_packaging],
        'checks' => [{ 'id' => 'behavior', 'required' => true, 'timeout_seconds' => timeout,
                       'argv' => [File.realpath(RbConfig.ruby), CHECK, file, '{cache}', '{output}', scenario] }],
        'edits' => [{ 'path' => file, 'before_sha256' => Digest::SHA256.hexdigest(content), 'content' => candidate,
                     'after_sha256' => Digest::SHA256.hexdigest(candidate) }] }
    end
  end
end
