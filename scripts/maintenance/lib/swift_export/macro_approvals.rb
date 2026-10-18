# frozen_string_literal: true

require_relative 'descriptor'
require_relative '../run_store'

module Maintenance
  module SwiftExport
    module MacroApprovals
      TARGETS = { 'swift-composable-architecture' => 'ComposableArchitectureMacros',
                  'swift-case-paths' => 'CasePathsMacros', 'swift-dependencies' => 'DependenciesMacrosPlugin',
                  'swift-perception' => 'PerceptionMacros' }.freeze
      PREFERENCES_PROBE = <<~SWIFT.freeze
        import Foundation
        let value: [String: Any] = ["foundation_home": NSHomeDirectory(), "library_directory": FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!.path, "skip_macro_validation": UserDefaults(suiteName: "com.apple.dt.Xcode")!.bool(forKey: "IDESkipMacroFingerprintValidation")]
        let data = try JSONSerialization.data(withJSONObject: value)
        print("MOBI_MACRO_PREFERENCES=" + String(data: data, encoding: .utf8)!)
      SWIFT

      def self.verify_environment(text, home:)
        lines = text.lines.select { |line| line.start_with?('MOBI_MACRO_PREFERENCES=') }
        raise Failure, 'Macro preference probe unavailable' unless lines.size == 1
        value = JSON.parse(lines.first.delete_prefix('MOBI_MACRO_PREFERENCES='))
        raise Failure, 'Foundation home escaped the disposable phase' unless File.realpath(value.fetch('foundation_home')) == File.realpath(home)
        library = value.fetch('library_directory')
        raise Failure, 'Foundation library escaped the disposable phase' unless File.basename(library) == 'Library' && File.realpath(File.dirname(library)) == File.realpath(home)
        raise Failure, 'Macro validation bypass is enabled; qualification refuses inherited Xcode preferences' unless value['skip_macro_validation'] == false
        value
      rescue JSON::ParserError, KeyError, Errno::ENOENT, TypeError
        raise Failure, 'Malformed macro preference probe'
      end

      def self.install(workspace:, home:, pins:, checkout_heads:)
        workspace = File.realpath(workspace)
        home = File.realpath(home)
        raise Failure, 'Macro approvals require the run-owned home' unless home == File.join(workspace, 'home') && !File.symlink?(home)
        entries = TARGETS.map do |identity, target|
          matches = pins.select { |pin| pin['identity'] == identity }
          raise Failure, 'Exactly one locked macro package required' unless matches.size == 1
          revision = matches.first.dig('state', 'revision')
          raise Failure, 'Macro checkout revision differs from lock' unless revision.to_s.match?(/\A[0-9a-f]{40}\z/) && checkout_heads[identity] == revision
          { 'packageIdentity' => identity, 'targetName' => target, 'fingerprint' => revision }
        end
        folder = home
        %w[Library org.swift.swiftpm security].each do |part|
          folder = File.join(folder, part)
          raise Failure, 'Macro approval path is not owned' if File.symlink?(folder) || File.exist?(folder) && !File.directory?(folder)
          Dir.mkdir(folder, 0o700) unless File.directory?(folder)
        end
        path = File.join(folder, 'macros.json')
        raise Failure, 'Macro approval store already exists' if File.exist?(path) || File.symlink?(path)
        RunStore.atomic(path, entries)
        { 'scope' => 'run-owned-exact-locked-macro-revisions', 'validation' => 'enabled', 'path' => path,
          'sha256' => Maintenance.file_sha(path), 'records' => entries }
      end
    end
  end
end
