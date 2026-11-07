# frozen_string_literal: true

require 'digest'
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

# IOS-17: observe the upstream inheritance contract without suppressing it.
# A missing diagnostic can also mean a changed message or opt-in, not a fix.
coroutine_source = modules.find { |mod| mod.fetch('name') == 'KotlinCoroutineSupport' }.fetch('kotlin')
coroutine_text = File.read(coroutine_source)
native_arguments = JSON.parse(File.read(File.join(output, 'native-cache.json'))).fetch('argv')
compiler_opt_ins = native_arguments.each_cons(2).map { |flag, value| value if flag == '-opt-in' }.compact
compiler_opt_ins += native_arguments.grep(/\A-opt-in=/).map { |flag| flag.delete_prefix('-opt-in=') }
inheritance_diagnostics = File.readlines(File.join(output, 'native.log')).select do |line|
  line.match?(/KotlinCoroutineSupport\.kt:\d+:\d+: warning:/) && line.include?('not intended to be inherited from')
end.map { |line| line.sub(root + '/', '') }
File.write(File.join(logs, 'coroutine-inheritance.log'), inheritance_diagnostics.join)
report['coroutine_inheritance'] = {
  'scope' => 'actual_generated_native_compilation',
  'state' => inheritance_diagnostics.empty? ? 'diagnostic_not_reported_review_required' : 'diagnostic_reported',
  'diagnostic_count' => inheritance_diagnostics.size,
  'generated_source_sha256' => Digest::SHA256.hexdigest(coroutine_text),
  'uses_job_delegation' => coroutine_text.match?(/class SwiftJob\b[^\n]*: Job by Job\(\)/),
  'source_mentions_inheritance_marker' => coroutine_text.include?('InternalForInheritanceCoroutinesApi'),
  'compiler_opt_ins' => compiler_opt_ins,
  'diagnostic_control_flags' => native_arguments.grep(/\A(?:-nowarn|-Xsuppress-warning|-Xwarning-level)/),
  'retirement_authorized' => false
}

Dir.mktmpdir('mobi-swift-export-checks-') do |temporary|
  base = ['/usr/bin/xcrun', 'swiftc', '-sdk', sdk, '-target', triple,
          '-I', package, '-module-cache-path', File.join(temporary, 'cache'), '-swift-version', '6']
  compile = lambda do |name, text, sources = [], extra: []|
    path = File.join(temporary, name + '.swift')
    File.write(path, text)
    diagnostic, status = Open3.capture2e(*(base + extra + ['-warnings-as-errors', '-emit-sil', '-whole-module-optimization', '-parse-as-library', '-o', File.join(temporary, name + '.sil'), path] + sources))
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
  abort "Home actor-owned refresh regressed:\n#{diagnostic}" unless good
  report['isolation']['home_actor_refresh'] = 'passed'
  nearby_actor_source = <<~SWIFT
    import MobiCore
    import MobiNearby
    @MainActor final class NearbyOwner {
      private let service: NearbyVehicleMapFeatureService
      init(service: NearbyVehicleMapFeatureService) { self.service = service }
      func refresh() async throws {
        let state = service.riderLocationAvailable(currentState: service.initialState(), location: RiderLocation(latitude: 0, longitude: 0))
        _ = try await service.refreshSnapshot(currentState: state, nowMillis: 0)
      }
    }
  SWIFT
  good, diagnostic = compile.call('nearby-actor-refresh', nearby_actor_source)
  abort "Nearby actor-owned refresh regressed:\n#{diagnostic}" unless good
  report['isolation']['nearby_actor_refresh'] = 'passed'
  puts '[swift-export] IOS-02 partial isolation checks: ' + JSON.generate(report.fetch('isolation'))

  # Check the actual app boundary, not a substitute client or reducer.
  products = File.join(root, 'build/xcode-derived-data-cli-tests/Build/Products', configuration + '-' + platform)
  native_imports = ['-I', products, '-F', File.join(products, 'PackageFrameworks')]
  allowed = <<~SWIFT
    @testable import app
    @MainActor func synchronous(_ client: HomeFeatureClient) {
      _ = client.initialState(); _ = client.loadingState(0); _ = HomeFeature().body
    }
    func asynchronous(_ client: HomeFeatureClient) async -> HomeCounterLoadable {
      await client.refresh(.initial)
    }
  SWIFT
  good, diagnostic = compile.call('home-client-allowed', allowed, extra: native_imports)
  abort "Actor-bound Home client calls failed:\n#{diagnostic}" unless good
  report['home_client_isolation'] = { 'allowed_calls' => 'passed' }
  [
    ['initial_state_off_actor', 'client: HomeFeatureClient', 'client.initialState()', 'call to main actor-isolated function'],
    ['loading_state_off_actor', 'client: HomeFeatureClient', 'client.loadingState(0)', 'call to main actor-isolated function'],
    ['reducer_off_actor', 'reducer: HomeFeature', 'reducer.body', "main actor-isolated property 'body'"]
  ].each do |name, parameter, expression, expected|
    text = "@testable import app\nfunc crossing(_ #{parameter}) { _ = #{expression} }\n"
    good, diagnostic = compile.call('home-' + name, text, extra: native_imports)
    abort "Off-actor Home access was not rejected precisely:\n#{diagnostic}" unless !good && diagnostic.include?(expected)
    report['home_client_isolation'][name] = 'rejected'
  end
  report['home_client_isolation']['caller_isolated_modules'] = commands.select do |command|
    command.fetch('argv').each_cons(2).include?(['-enable-upcoming-feature', 'NonisolatedNonsendingByDefault'])
  end.map { |command| command.fetch('name').delete_prefix('swift-') }.sort
  puts '[swift-export] Home client actor contracts: ' + JSON.generate(report.fetch('home_client_isolation'))

  nearby_allowed = <<~SWIFT
    @testable import app
    import MobiNearby
    @MainActor func synchronous(_ client: NearbyVehicleMapFeatureClient, _ state: NearbyVehicleMapFeatureState) {
      _ = client.initialState()
      _ = client.preciseLocationResolvedState(state, 0, 0)
      _ = client.locationBlockedState(state, .accessDenied)
      _ = client.locationTemporarilyUnavailableState(state)
      _ = client.loadingState(state)
      _ = client.shouldRefresh(state, 0)
      _ = client.stateAfterTimePasses(state, 0)
      _ = NearbyVehicleMapFeature().body
    }
    @MainActor func asynchronous(_ client: NearbyVehicleMapFeatureClient, _ state: NearbyVehicleMapFeatureState) async {
      _ = await client.refresh(state, 0)
    }
  SWIFT
  good, diagnostic = compile.call('nearby-client-allowed', nearby_allowed, extra: native_imports)
  abort "Actor-bound Nearby client calls failed:\n#{diagnostic}" unless good
  report['nearby_client_isolation'] = { 'allowed_calls' => 'passed', 'raw_state_sendability' => 'non_sendable_actor_owned' }
  [
    ['initial_state_off_actor', 'client: NearbyVehicleMapFeatureClient', 'client.initialState()', 'call to main actor-isolated function'],
    ['loading_state_off_actor', 'client: NearbyVehicleMapFeatureClient, _ state: NearbyVehicleMapFeatureState', 'client.loadingState(state)', 'call to main actor-isolated function'],
    ['refresh_query_off_actor', 'client: NearbyVehicleMapFeatureClient, _ state: NearbyVehicleMapFeatureState', 'client.shouldRefresh(state, 0)', 'call to main actor-isolated function'],
    ['reducer_off_actor', 'reducer: NearbyVehicleMapFeature', 'reducer.body', "main actor-isolated property 'body'"]
  ].each do |name, parameter, expression, expected|
    text = "@testable import app\nimport MobiNearby\nfunc crossing(_ #{parameter}) { _ = #{expression} }\n"
    good, diagnostic = compile.call('nearby-' + name, text, extra: native_imports)
    abort "Off-actor Nearby access was not rejected precisely:\n#{diagnostic}" unless !good && diagnostic.include?(expected)
    report['nearby_client_isolation'][name] = 'rejected'
  end
  # State stays in the real Store/client's MainActor region. Do not substitute a
  # globally Sendable state wrapper or accept an unrelated compiler error.
  state_imports = "@testable import app\nimport MobiIOSDependencies\nimport MobiNearby\n"
  actor_state_read = state_imports + <<~SWIFT
    @MainActor func read(_ store: Store<NearbyVehicleMapFeature.State, NearbyVehicleMapFeature.Action>) -> Bool {
      let state = store.state
      _ = state.sharedState
      return state.canRequestRefresh
    }
  SWIFT
  good, diagnostic = compile.call('nearby-state-actor-read', actor_state_read, extra: native_imports)
  abort "Actor-owned Nearby state read failed:\n#{diagnostic}" unless good
  report['nearby_client_isolation']['state_actor_read'] = 'passed'
  [
    ['client_state_transfer', 'func crossing(_ client: NearbyVehicleMapFeatureClient) async { _ = await client.initialState() }',
     ['non-Sendable', 'NearbyVehicleMapFeatureState', 'main actor-isolated function to nonisolated context']],
    ['store_state_transfer', 'func crossing(_ store: Store<NearbyVehicleMapFeature.State, NearbyVehicleMapFeature.Action>) async { let state = await store.state; _ = state.sharedState }',
     ['non-Sendable', 'NearbyVehicleMapFeature.State', 'cannot exit main actor-isolated context']],
    ['unsafe_state_container', 'struct UnsafeStateBox: Sendable { let value: NearbyVehicleMapFeatureState }',
     ["stored property 'value'", 'non-Sendable type', 'NearbyVehicleMapFeatureState']]
  ].each do |name, source, expected|
    good, diagnostic = compile.call('nearby-' + name, state_imports + source + "\n", extra: native_imports)
    unless !good && expected.all? { |message| diagnostic.include?(message) }
      abort "Unsafe Nearby state crossing was not rejected precisely:\n#{diagnostic}"
    end
    report['nearby_client_isolation'][name] = 'rejected'
  end
  report['nearby_client_isolation']['caller_isolated_modules'] = report.fetch('home_client_isolation').fetch('caller_isolated_modules')
  puts '[swift-export] Nearby client actor contracts: ' + JSON.generate(report.fetch('nearby_client_isolation'))

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
  # IOS-15: the native tests now use these constructors; visibility is required.
  abort "Public generated constructors regressed:\n#{diagnostic}" unless good
  report['nested_constructors'] = 'passed'
  puts '[swift-export] IOS-15: ' + report.fetch('nested_constructors')

  report['strict_support'] = %w[KotlinRuntimeSupport KotlinCoroutineSupport].to_h do |name|
    mod = modules.find { |m| m.fetch('name') == name }
    args = base + ['-warnings-as-errors', '-package-name', 'MobiShared', '-emit-module', '-parse-as-library',
                   '-module-name', name, '-emit-module-path', File.join(temporary, name + '.swiftmodule'),
                   '-enable-experimental-feature', 'CheckImplementationOnly', mod.fetch('swift')]
    producer_args = commands.find { |command| command.fetch('name') == 'swift-' + name }.fetch('argv')
    producer_args.each_cons(2) { |flag, value| args += [flag, value] if flag == '-enable-upcoming-feature' }
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
