# frozen_string_literal: true

require_relative 'descriptor'

module Maintenance
  module SwiftExport
    module ToolIdentity
      def self.command(argv, developer: nil)
        env = { 'LC_ALL' => 'C', 'PATH' => '/usr/bin:/bin:/usr/sbin:/sbin' }
        env['DEVELOPER_DIR'] = developer if developer
        text, status = Open3.capture2e(env, *argv)
        raise Failure, 'Apple tool identity unavailable' unless status.success?
        text.strip
      end

      def self.developer_dir(value = ENV['DEVELOPER_DIR'])
        value ||= command(['/usr/bin/xcode-select', '--print-path'])
        raise Failure, 'Absolute Xcode Developer directory required' unless Pathname.new(value).absolute?
        selected = File.realpath(value)
        raise Failure, 'Selected Xcode Developer directory unavailable' unless File.directory?(selected) && File.executable?(File.join(selected, 'usr/bin/xcodebuild'))
        selected
      rescue Errno::ENOENT
        raise Failure, 'Selected Xcode Developer directory unavailable'
      end

      def self.capture(java)
        developer = developer_dir
        selected_command = ->(argv) { command(argv, developer: developer) }
        swift = selected_command.call(['/usr/bin/xcrun', '--find', 'swiftc'])
        clang = selected_command.call(['/usr/bin/xcrun', '--find', 'clang'])
        sdk = selected_command.call(['/usr/bin/xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'])
        version = selected_command.call(['/usr/bin/xcrun', 'swiftc', '--version'])
        xcode = selected_command.call(['/usr/bin/xcodebuild', '-version'])
        sdk_version = selected_command.call(['/usr/bin/xcrun', '--sdk', 'iphonesimulator', '--show-sdk-version'])
        raise Failure, "Unqualified Apple compiler/SDK tuple: #{version}; #{xcode}; Simulator SDK #{sdk_version}; #{developer}" unless version.include?('Apple Swift version 6.4 ') && xcode.start_with?('Xcode 27.0') && sdk_version == '27.0'
        files = [java, File.join(File.dirname(File.dirname(java)), 'release'), File.join(File.dirname(File.dirname(java)), 'lib/modules'),
                 swift, clang, '/usr/bin/xcodebuild', File.join(developer, 'usr/bin/xcodebuild'), File.join(sdk, 'SDKSettings.json'), File.join(sdk, 'SDKSettings.plist')].select { |p| File.file?(p) }.map { |p| File.realpath(p) }.uniq
        file_hashes = files.to_h { |p| [p, Maintenance.file_sha(p)] }
        contract = { 'swift_version' => version, 'xcode_version' => xcode, 'sdk_version' => sdk_version,
                     'files' => file_hashes.map { |p, sha| { 'name' => File.basename(p), 'sha256' => sha } } }
        { 'identity' => Maintenance.digest(contract), 'contract' => contract, 'locations' => file_hashes, 'developer_dir' => developer }
      end
    end
  end
end
