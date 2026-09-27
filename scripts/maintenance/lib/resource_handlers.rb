# frozen_string_literal: true

require_relative 'run_store'

module Maintenance
  # Language-specific lifecycle code stays behind this small shared dispatch.
  module ResourceHandlers
    TYPES = %w[filesystem process-group kotlin-native].freeze

    def self.prepare(types, control:, workspace:, nonce:)
      return [] unless types.include?('kotlin-native')
      require_relative '../adapters/kotlin_resources'
      KotlinResources.prepare(control: control, workspace: workspace, nonce: nonce)
      [{ 'type' => 'kotlin-native', 'control' => control, 'nonce' => nonce }]
    end

    def self.handlers(records)
      (records || []).map do |record|
        raise Failure, 'Unknown managed resource handler' unless record['type'] == 'kotlin-native'
        require_relative '../adapters/kotlin_resources'
        KotlinResources.new(record.fetch('control'), record.fetch('nonce'))
      end
    end

    def self.stop(records)
      handlers(records).each(&:stop!)
    end

    def self.quiescent?(records)
      handlers(records).all?(&:quiescent?)
    end
  end
end
