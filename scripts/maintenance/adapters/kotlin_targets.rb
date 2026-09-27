# frozen_string_literal: true

require_relative '../lib/core'
require 'yaml'

module Maintenance
  module KotlinTargets
    POLICIES = %w[current apple-silicon].freeze
    MODULES = %w[shared-core shared-di shared-feature-home shared-feature-nearby-vehicle-map shared-ui-home].freeze
    BRIDGE = 'gradle-bridge/shared-kit/build.gradle.kts'
    PLATFORMS = '  platforms: [android, iosArm64, iosSimulatorArm64, iosX64]'
    X64_SOURCE_SET = <<~BLOCK.freeze
            val iosX64Main by getting {
                kotlin.srcDirs(
                    "../../shared-core/src@ios",
                    "../../shared-ui-home/src@ios",
                )
            }

    BLOCK

    def self.edits(source, policy)
      raise Failure, 'Unknown Kotlin target policy' unless POLICIES.include?(policy)
      return [] if policy == 'current'

      declared = YAML.safe_load(File.read(File.join(source.root, 'project.yaml'))).fetch('modules')
      libraries = declared.select do |name|
        product = YAML.safe_load(File.read(File.join(source.root, name, 'module.yaml'))).fetch('product')
        (product.is_a?(Hash) ? product['type'] : product) == 'kmp/lib'
      end
      raise Failure, 'Apple Silicon candidate module coverage changed; review the target policy' unless libraries.sort == MODULES.sort

      replacements = MODULES.to_h { |name| [name + '/module.yaml', [[PLATFORMS, PLATFORMS.sub(', iosX64', '')]]] }
      # Keep exact, reviewed blocks: a new source mapping needs a fresh review.
      block = X64_SOURCE_SET.lines.map { |line| line.strip.empty? ? line : '        ' + line }.join
      replacements[BRIDGE] = [["    iosX64()\n", ''], [block, '']]
      replacements.map do |path, changes|
        content = File.read(File.join(source.root, path), encoding: 'UTF-8')
        before = source.files.fetch(path).fetch('sha256')
        raise Failure, 'Target input changed after capture' unless Digest::SHA256.hexdigest(content) == before
        unless content.include?('iosX64')
          if path == BRIDGE
            raise Failure, 'Missing adopted ARM bridge targets' unless %w[iosArm64 iosSimulatorArm64].all? { |target| content.include?(target + '()') && content.include?('val ' + target + 'Main by getting') }
          else
            raise Failure, 'Adopted ARM target declaration changed; review the candidate' unless content.include?(PLATFORMS.sub(', iosX64', ''))
          end
          next
        end
        changes.each do |old, replacement|
          raise Failure, 'Apple Silicon target declaration changed; review the candidate' unless content.scan(Regexp.new(Regexp.escape(old))).size == 1
          content = content.sub(old, replacement)
        end
        raise Failure, 'Unexpected Intel target reference remains' if content.include?('iosX64')
        { 'path' => path, 'before_sha256' => before, 'content' => content, 'after_sha256' => Digest::SHA256.hexdigest(content) }
      end.compact
    end

    def self.verify_graphs!(graphs)
      roots = graphs.fetch('graphs')
      raise Failure, 'Intel iOS target remains in candidate graph' if roots.any? { |root| root.fetch('platforms').include?('iosX64') }
      (MODULES + ['ios-app']).each do |name|
        %w[iosArm64 iosSimulatorArm64].product(%w[main test], %w[compile runtime]).each do |platform, usage, scope|
          unless roots.any? { |root| root['module'] == name && root['usage'] == usage && root['scope'] == scope && root['platforms'].include?(platform) }
            raise Failure, 'Apple Silicon candidate graph is missing a required ARM target or test scope'
          end
        end
      end
      true
    end
  end
end
