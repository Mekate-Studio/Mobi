# frozen_string_literal: true

module Maintenance
  module Elixir
    def self.inventory(files)
      manifests = files.keys.select { |path| File.basename(path) == 'mix.exs' }
      { 'adapter' => 'elixir', 'state' => manifests.empty? ? 'not_applicable' : 'incomplete',
        'reason' => manifests.empty? ? 'Dormant profile; no backend configured' : 'Backend activation and effective Mix/OTP/Hex graph capture require separate review',
        'manifests' => manifests, 'required_on_activation' => %w[format compile_warnings_as_errors credo sobelow boundary vulnerability_audit exunit isolated_postgresql dependency_rehearsal] }
    end
  end
end
