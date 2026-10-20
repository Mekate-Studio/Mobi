# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'open3'
require 'tmpdir'

# Read the selected Native runtime's i32 mode constant from the linked image.
# Layouts are mach_header_64 and segment_command_64 in the Apple SDK loader.h.
def kotlin_export_mode(image, symbols)
  address = symbols[/^([0-9a-fA-F]+)\s+\S\s+_Kotlin_swiftExport$/, 1]
  abort 'Missing Kotlin Swift-export mode symbol' unless address
  address = address.to_i(16)
  File.open(image, 'rb') do |file|
    header = file.read(32)
    abort 'Expected a thin little-endian Mach-O 64 image' unless header.unpack1('V') == 0xfeedfacf
    offset = 32
    header.byteslice(16, 4).unpack1('V').times do
      file.seek(offset)
      command, size = file.read(8).unpack('V2')
      abort 'Invalid Mach-O load command' if size < 8
      if command == 0x19 # LC_SEGMENT_64
        file.seek(offset + 24)
        vmaddr, _vmsize, fileoff, filesize = file.read(32).unpack('Q<4')
        if address >= vmaddr && address + 4 <= vmaddr + filesize
          file.seek(fileoff + address - vmaddr)
          return file.read(4).unpack1('V')
        end
      end
      offset += size
    end
  end
  abort 'Kotlin Swift-export mode is outside file-backed segments'
end

# Compile contracts over the actual delivery. These are not another app or a
# second representation of product state. They exercise compiler diagnostics.
root = File.expand_path('../..', __dir__)
platform = ENV.fetch('PLATFORM_NAME', 'iphonesimulator')
configuration = ENV.fetch('CONFIGURATION', 'Debug')
output = File.join(root, 'build/swift-export', configuration + '-' + platform)
package = File.join(output, 'Package')
logs = File.join(root, 'build/logs/swift-export-checks')
FileUtils.mkdir_p(logs)
modules = JSON.parse(File.read(File.join(output, 'modules.json')))
commands = JSON.parse(File.read(File.join(output, 'commands.json')))
app_compile = commands.find { |c| c.fetch('name') == 'swift-MobiHome' }.fetch('argv')
triple = app_compile.fetch(app_compile.index('-target') + 1)
sdk = app_compile.fetch(app_compile.index('-sdk') + 1)
report = { 'schema' => 1, 'scope' => 'actual_delivery_compile_contracts', 'target' => triple,
           'sdk' => sdk, 'retirement_authorized' => false, 'checks' => [] }

Dir.mktmpdir('mobi-swift-export-checks-') do |temporary|
  base = ['/usr/bin/xcrun', 'swiftc', '-sdk', sdk, '-target', triple,
          '-I', package, '-module-cache-path', File.join(temporary, 'cache'), '-swift-version', '6']
  compile = lambda do |name, text, sources = []|
    path = File.join(temporary, name + '.swift')
    File.write(path, text)
    diagnostic, status = Open3.capture2e(*(base + ['-warnings-as-errors', '-emit-sil', '-whole-module-optimization', '-parse-as-library', '-o', File.join(temporary, name + '.sil'), path] + sources))
    File.write(File.join(logs, name + '.log'), diagnostic)
    [status.success?, diagnostic]
  end
  cases = [
    ['counter', 'any CounterLoadable', 'value.sealedType()', %w[initial loading loaded error]],
    ['counterFailure', 'any CounterLoadFailureReason', 'value.sealedType()', %w[repositoryUnavailable unexpected]],
    ['rider', 'any RiderLocationState', 'value.sealedType()', %w[resolving available denied blocked temporarilyUnavailable unavailable]],
    ['snapshot', 'any NearbyVehicleSnapshotState', 'value.sealedType()', %w[initial loading loaded refreshing failedWithSnapshot failedWithoutSnapshot]],
    ['overlay', 'any NearbyVehicleMapOverlayState', 'value.sealedType()', %w[none refreshingIndicator staleIndicator blockingFailure]],
    ['blockedReason', 'RiderLocationBlockedReason', 'value', %w[AccessDenied AccessRestricted ServicesDisabled ApproximateOnly TemporarilyUnavailable]]
  ]
  source = lambda do |name, type, expression, values|
    "import MobiHome\nimport MobiNearby\nfunc #{name}(_ value: #{type}) {\n switch #{expression} {\n" +
      values.map { |value| " case .#{value}: break\n" }.join + " }\n}\n"
  end
  cases.each do |name, type, expression, values|
    good, diagnostic = compile.call(name + '-complete', source.call(name, type, expression, values))
    abort "Complete generated #{name} switch failed:\n#{diagnostic}" unless good
    omitted = values.last
    good, diagnostic = compile.call(name + '-omitted', source.call(name, type, expression, values[0...-1]))
    unless !good && diagnostic.include?('switch must be exhaustive') && diagnostic.include?(omitted)
      abort "Missing generated #{name} case was not diagnosed precisely:\n#{diagnostic}"
    end
    report['checks'] << { 'name' => name, 'complete' => 'passed', 'omitted_case' => omitted, 'omission' => 'rejected' }
  end

  # IOS-02: ownership diagnostics also run during SIL generation. Type checking
  # alone can accept the actor wrapper while missing its async service transfer.
  native_value = "func nativeValue(_ value: HomeCounterLoadable) -> @Sendable () -> Void { { _ = value } }\n"
  good, diagnostic = compile.call('native-home-value', native_value, [File.join(root, 'ios-app/src/Features/Home/HomeCounterLoadable.swift')])
  abort "Native Home value crossing failed:\n#{diagnostic}" unless good
  report['isolation'] = { 'scope' => 'partial_compile_contracts', 'native_home_value' => 'passed' }
  [
    ['home_service_capture', 'MobiHome', 'HomeFeatureService'],
    ['nearby_service_capture', 'MobiNearby', 'NearbyVehicleMapFeatureService'],
    ['nearby_state_capture', 'MobiNearby', 'NearbyVehicleMapFeatureState']
  ].each do |name, mod, type|
    text = "import #{mod}\nfunc crossing(_ value: #{type}) -> @Sendable () -> Void { { _ = value } }\n"
    good, diagnostic = compile.call(name, text)
    unless good || (diagnostic.include?("capture of 'value' with non-Sendable type") && diagnostic.include?(type))
      abort "Unexpected #{name} probe failure:\n#{diagnostic}"
    end
    report['isolation'][name] = good ? 'retirement_candidate' : 'blocked_by_non_sendable_capture'
  end
  actor_source = <<~SWIFT
    import MobiHome
    @MainActor final class HomeOwner {
      private let service: HomeFeatureService
      init(service: HomeFeatureService) { self.service = service }
      func refresh() async throws { _ = try await service.refresh(counterValue: 0) }
    }
  SWIFT
  good, diagnostic = compile.call('home-actor-refresh', actor_source)
  unless good || diagnostic.include?("sending 'self.service' risks causing data races")
    abort "Unexpected Home actor ownership probe failure:\n#{diagnostic}"
  end
  report['isolation']['home_actor_refresh'] = good ? 'retirement_candidate' : 'blocked_by_async_service_transfer'
  puts '[swift-export] IOS-02 partial isolation checks: ' + JSON.generate(report.fetch('isolation'))

  constructor_source = <<~SWIFT
    import MobiCore
    import MobiNearby
    func constructors(location: RiderLocation, snapshot: FleetSnapshot) {
      let _ = RiderLocationState.Resolving.shared
      let _ = RiderLocationState.Available(location: location)
      let _ = RiderLocationState.Denied.shared
      let _ = RiderLocationState.Blocked(reason: .AccessDenied)
      let _ = RiderLocationState.TemporarilyUnavailable(location: location)
      let _ = NearbyVehicleSnapshotState.Initial.shared
      let _ = NearbyVehicleSnapshotState.Loading.shared
      let _ = NearbyVehicleSnapshotState.Loaded(snapshot: snapshot)
      let _ = NearbyVehicleSnapshotState.Refreshing(snapshot: snapshot)
      let _ = NearbyVehicleSnapshotState.FailedWithoutSnapshot(reason: .RiderLocationUnavailable)
      let _ = NearbyVehicleMapOverlayState.None.shared
      let _ = NearbyVehicleMapOverlayState.RefreshingIndicator.shared
      let _ = NearbyVehicleMapOverlayState.BlockingFailure.shared
    }
  SWIFT
  good, diagnostic = compile.call('nested-constructors', constructor_source)
  unless good || diagnostic.include?("inaccessible due to 'internal' protection level")
    abort "Unexpected constructor probe failure:\n#{diagnostic}"
  end
  report['nested_constructors'] = good ? 'retirement_candidate' : 'blocked_by_internal_aliases'
  puts '[swift-export] IOS-15: ' + report.fetch('nested_constructors')

  report['strict_support'] = %w[KotlinRuntimeSupport KotlinCoroutineSupport].to_h do |name|
    mod = modules.find { |m| m.fetch('name') == name }
    args = base + ['-warnings-as-errors', '-package-name', 'MobiShared', '-emit-module', '-parse-as-library',
                   '-module-name', name, '-emit-module-path', File.join(temporary, name + '.swiftmodule'),
                   '-enable-experimental-feature', 'CheckImplementationOnly', mod.fetch('swift')]
    diagnostic, status = Open3.capture2e(*args)
    File.write(File.join(logs, name + '-strict.log'), diagnostic)
    [name, status.success? ? 'retirement_candidate' : 'blocked']
  end
  puts '[swift-export] IOS-08 strict support: ' + JSON.generate(report.fetch('strict_support'))

  app = File.join(root, 'build/xcode-derived-data-cli-tests/Build/Products', configuration + '-' + platform, 'ios-app.app')
  abort 'Missing tested application bundle' unless File.directory?(app)
  images = []
  Dir.glob(File.join(app, '**', '*')).select { |path| File.file?(path) }.each_with_index do |path, index|
    next if File.size(path) < 4
    magic = File.binread(path, 4).unpack1('H*')
    next unless %w[cffaedfe cafebabe bebafeca cafebabf bfbafeca].include?(magic)
    image = path
    if magic != 'cffaedfe'
      image = File.join(temporary, "image#{index}")
      text, status = Open3.capture2e('/usr/bin/lipo', path, '-thin', 'arm64', '-output', image)
      abort "Cannot inspect packaged ARM64 image: #{text}" unless status.success?
    end
    symbols, status = Open3.capture2e('/usr/bin/nm', '-U', image)
    abort 'Cannot inspect packaged Mach-O symbols' unless status.success?
    next unless symbols.match?(/\b[tT]\s+_Kotlin_initRuntimeIfNeeded$/)
    mode = kotlin_export_mode(image, symbols)
    abort 'A packaged Kotlin runtime does not enable Swift export' unless mode == 1
    images << path.delete_prefix(app + '/')
  end
  abort "Expected one packaged Kotlin runtime, found #{images.length}" unless images.length == 1
  abort 'Legacy KotlinModules framework remains packaged' unless Dir.glob(File.join(app, '**/KotlinModules.framework')).empty?
  report['kotlin_runtime_images'] = images
  report['swift_export_mode'] = true
  puts '[swift-export] One packaged Kotlin runtime; linked Swift-export mode verified'

end

File.write(File.join(logs, 'report.json'), JSON.pretty_generate(report) + "\n")
puts '[swift-export] Six complete switches compile; all six omission controls reject'
puts '[swift-export] Retirement candidates require review; no workaround was removed automatically'
