# frozen_string_literal: true

# Manual operational assessment. This is not an automatic compatibility profile.
mode = ARGV.first == 'run' ? ARGV.shift : 'worker'
root = File.realpath(ARGV.fetch(0))
require File.join(root, 'scripts/maintenance/compatibility_check')
require File.join(root, 'scripts/maintenance/lib/executor')

module Maintenance
  class DirectReleaseProbe < CompatibilityCheck
    PROFILE = 'manual-ios-operations'
    CELLS = %w[effective_toolchain nightly_test ios_release_simulator simulator_product ios_unsigned_archive archive_product].freeze
    LIMITS = %w[physical_device_execution exact_floor_runtime signed_export_delivery complete_compose_resource_parity empty_host_onboarding architecture_approval retirement_approval].freeze

    def initialize(*args)
      super(*args, 'direct-facade')
      @profile = PROFILE
      @report.merge!('profile' => PROFILE, 'missing_capabilities' => LIMITS, 'manual_assessment' => true)
    end

    def product(kind, app)
      raise Failure, 'Expected one real product app' unless File.directory?(app) && !File.symlink?(app)
      plist = File.join(app, 'Info.plist')
      info = JSON.parse(command(kind + '-plist', ['/usr/bin/plutil', '-convert', 'json', '-o', '-', plist]))
      raise Failure, 'Product identity or minimum differs' unless info['CFBundleIdentifier'] == 'studio.mekate.mobi' && info['MinimumOSVersion'] == '26.0'
      binary = File.join(app, info.fetch('CFBundleExecutable'))
      arch = command(kind + '-arch', ['/usr/bin/lipo', '-archs', binary]).strip
      raise Failure, 'Product architecture differs' unless arch == 'arm64'
      load = command(kind + '-load', ['/usr/bin/otool', '-l', binary])
      builds = load.scan(/cmd LC_BUILD_VERSION\s+cmdsize \d+\s+platform (\d+)\s+minos ([\d.]+)\s+sdk ([\d.]+)/)
      expected_platform = kind == 'simulator' ? '7' : '2'
      raise Failure, 'Product platform or binary minimum differs' unless builds.size == 1 && builds[0][0] == expected_platform && Gem::Version.new(builds[0][1]) == Gem::Version.new('26.0')
      assets = File.join(app, 'Assets.car')
      raise Failure, 'Compiled assets are missing' unless File.file?(assets) && File.size(assets).positive?
      assets_info = JSON.parse(command(kind + '-assets', ['/usr/bin/xcrun', '--sdk', kind == 'simulator' ? 'iphonesimulator' : 'iphoneos', 'assetutil', '--info', assets]))
      icons = assets_info.select { |entry| entry['Name'].to_s.include?('AppIcon') }
      raise Failure, 'Compiled app icon entries are missing' if icons.empty?
      files = Dir.glob(File.join(app, '**', '*')).select { |file| File.file?(file) && !File.symlink?(file) }
      raise Failure, 'Unsigned product unexpectedly contains a signature' if files.any? { |file| file.include?('/_CodeSignature/') || file.end_with?('/embedded.mobileprovision') }
      write_evidence(kind + '-product', { 'path' => app.delete_prefix(@work + '/'), 'identifier' => info['CFBundleIdentifier'],
        'minimum' => info['MinimumOSVersion'], 'architecture' => arch, 'build_version' => builds.first,
        'assets_sha256' => Maintenance.file_sha(assets), 'app_icon_entries' => icons.size,
        'files' => files.sort.to_h { |file| [file.delete_prefix(app + '/'), Maintenance.file_sha(file)] },
        'resources_scope' => 'compiled_native_asset_catalog_and_product_inventory', 'signing_scope' => 'unsigned_no_export_or_delivery' })
    end

    def run
      outcome = catch(:outcome) do
        write_evidence('source-manifest', @manifest)
        write_evidence('declared-inputs', self.class.declared_inputs(@work, @modules))
        if @direct
          @experiment = InteropExperiment.new(@work, File.join(@work, 'scripts/maintenance/fixtures/interop'))
          write_evidence('experiment-transformations', @experiment.prepare!)
          @manifest = tree(@work)
          @report['bridge_unavailable'] = true
          write_evidence('direct-source-manifest', @manifest)
        end
        @report['di_reachable'] = InteropExperiment.reachable_modules(@work).include?('shared-di')
        raise Failure, 'Direct DI is unreachable' if @direct && !@report['di_reachable']
        native_setup
        @env.merge!('OVERRIDE_KOTLIN_BUILD_IDE_SUPPORTED' => 'NO', 'KOTLIN_IOS_BUILDER' => @direct ? 'kotlin' : 'gradle', 'IOS_TEST_PLAN' => 'Nightly')
        @report['environment'].merge!('bridge' => @env['KOTLIN_IOS_BUILDER'], 'test_plan' => 'Nightly', 'licenses' => 'copied_host_acceptance', 'empty_host_proven' => false)
        command('host-xcode', ['/usr/bin/xcodebuild', '-version'])
        command('host-os', ['/usr/bin/sw_vers'])
        measured('effective_toolchain') do
          banner = cli('version', '--version')
          raise Failure, 'Executed Toolchain differs' unless banner.include?('Kotlin Toolchain version ' + @version + ' ')
          write_evidence('effective-settings', KotlinEvidence.settings(cli('settings', 'show', 'settings', '--all-modules'), modules: @modules, version: @version, source: @work))
        end
        measured('nightly_test') do
          text = command('nightly-test', [File.join(@work, 'scripts/ci/run_job.sh'), 'ios-test'])
          native_cases(text, 'nightly-native-test-cases')
        end
        measured('ios_release_simulator') { command('ios-release-simulator', [File.join(@work, 'scripts/ci/run_job.sh'), 'ios-build-release']) }
        measured('simulator_product') do
          apps = Dir.glob(File.join(@work, 'build/xcode-derived-data-cli-release/Build/Products/Release-iphonesimulator/*.app'))
          raise Failure, 'Expected one simulator Release app' unless apps.size == 1
          product('simulator', apps.first)
        end
        measured('ios_unsigned_archive') do
          command('ios-unsigned-archive', ['/usr/bin/xcodebuild', '-project', File.join(@work, 'ios-app/module.xcodeproj'), '-scheme', 'app', '-configuration', 'Release', '-destination', 'generic/platform=iOS', '-derivedDataPath', File.join(@work, 'build/archive-derived'), '-archivePath', File.join(@work, 'build/releases/Mobi.xcarchive'), '-skipMacroValidation', 'CODE_SIGNING_ALLOWED=NO', 'CODE_SIGNING_REQUIRED=NO', 'SWIFT_ENABLE_EXPLICIT_MODULES=NO', 'ARCHS=arm64', 'archive'])
        end
        measured('archive_product') do
          apps = Dir.glob(File.join(@work, 'build/releases/Mobi.xcarchive/Products/Applications/*.app'))
          raise Failure, 'Expected one archived app' unless apps.size == 1
          product('archive', apps.first)
        end
        'passed'
      end
      outcome
    rescue Failure => error
      @report['failure'] = error.message
      'refused'
    rescue StandardError => error
      @report['failure'] = error.class.name
      File.write(File.join(@control, 'adapter-error.log'), error.full_message)
      'infrastructure'
    ensure
      begin
        @report['cells'].each_value { |cell| cell['status'] = 'infrastructure' if cell['status'] == 'running' }
        CELLS.each { |cell| @report['cells'][cell] ||= { 'status' => 'not_attempted', 'evidence_kind' => 'none' } }
        verify_source!
        @report['source_preservation'] = 'verified'
      rescue StandardError => error
        @report['evidence_failure'] = true
        @report['source_preservation'] = 'unverified'
        @report['evidence_error'] = error.class.name
      ensure
        RunStore.atomic(File.join(@control, 'evidence.json'), @report)
      end
    end
  end
end

if mode == 'run'
  source = Maintenance::Source.new(root)
  original = Maintenance::CompatibilityRehearsal.new(root, source: source, profile: 'direct-facade')
  adapter = Object.new
  probe = File.realpath(__FILE__)
  plan = { 'schema' => 1, 'id' => 'manual-ios-operations', 'scope' => 'paired_unsigned_ios_operations',
    'resource_types' => %w[filesystem process-group kotlin-native], 'edits' => [],
    'missing_capabilities' => Maintenance::DirectReleaseProbe::LIMITS,
    'checks' => [{ 'id' => Maintenance::DirectReleaseProbe::PROFILE, 'required' => true, 'timeout_seconds' => 1300,
      'argv' => [File.realpath(RbConfig.ruby), probe, '{source}', '{output}', '{cache}', original.host_file] }] }
  adapter.define_singleton_method(:plan) { plan }
  adapter.define_singleton_method(:code_files) { original.code_files + [probe] }
  store = Maintenance::RunStore.new(File.join(root, '.maintenance/runs-ios-operations'))
  policy_file = File.join(root, 'maintenance-execution-policy.json')
  result = Maintenance::Executor.new(source: source, adapter: adapter, store: store, policy: JSON.parse(File.read(policy_file)), input_files: [policy_file]).run
  puts JSON.pretty_generate(result)
  exit(Maintenance::Executor::EXIT_CODES.fetch(result['state']))
else
  check = Maintenance::DirectReleaseProbe.new(*ARGV)
  status = check.run
  status = 'refused' if check.report['evidence_failure']
  evidence = File.join(File.dirname(ENV.fetch('MOBI_RESULT_PATH')), 'evidence.json')
  Maintenance::RunStore.atomic(ENV.fetch('MOBI_RESULT_PATH'), { 'schema' => 1, 'check' => Maintenance::DirectReleaseProbe::PROFILE,
    'phase' => ENV.fetch('MOBI_PHASE'), 'status' => status, 'evidence_sha256' => Maintenance.file_sha(evidence) })
  exit(status == 'passed' ? 0 : 1)
end
