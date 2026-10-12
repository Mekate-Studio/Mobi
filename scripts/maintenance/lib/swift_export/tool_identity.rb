# frozen_string_literal: true

require_relative 'descriptor'

module Maintenance
  module SwiftExport
    module ToolIdentity
      def self.command(argv)
        text, status = Open3.capture2e({ 'LC_ALL' => 'C', 'PATH' => '/usr/bin:/bin:/usr/sbin:/sbin' }, *argv)
        raise Failure, 'Apple tool identity unavailable' unless status.success?
        text.strip
      end

      def self.capture(java)
        swift = command(['/usr/bin/xcrun', '--find', 'swiftc'])
        clang = command(['/usr/bin/xcrun', '--find', 'clang'])
        sdk = command(['/usr/bin/xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'])
        version = command(['/usr/bin/xcrun', 'swiftc', '--version'])
        xcode = command(['/usr/bin/xcodebuild', '-version'])
        sdk_version = command(['/usr/bin/xcrun', '--sdk', 'iphonesimulator', '--show-sdk-version'])
        raise Failure, 'Unqualified Apple compiler/SDK tuple' unless version.include?('Apple Swift version 6.4 ') && xcode.start_with?('Xcode 27.0') && sdk_version == '27.0'
        files = [java, File.join(File.dirname(File.dirname(java)), 'release'), File.join(File.dirname(File.dirname(java)), 'lib/modules'),
                 swift, clang, '/usr/bin/xcodebuild', File.join(sdk, 'SDKSettings.json'), File.join(sdk, 'SDKSettings.plist')].select { |p| File.file?(p) }.map { |p| File.realpath(p) }.uniq
        file_hashes = files.to_h { |p| [p, Maintenance.file_sha(p)] }
        contract = { 'swift_version' => version, 'xcode_version' => xcode, 'sdk_version' => sdk_version,
                     'files' => file_hashes.map { |p, sha| { 'name' => File.basename(p), 'sha256' => sha } } }
        { 'identity' => Maintenance.digest(contract), 'contract' => contract, 'locations' => file_hashes }
      end
    end
  end
end
