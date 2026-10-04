# frozen_string_literal: true

require_relative 'kotlin_check'
require_relative 'adapters/compatibility'
require_relative 'adapters/interop_experiment'
require_relative 'adapters/direct_roundtrip'
require_relative 'lib/upgrade_graph'
require_relative 'lib/direct_resolution'
require_relative 'lib/build_inputs'

module Maintenance
  class CompatibilityCheck < KotlinCheck
    def self.declared_inputs(work, modules)
      paths = [Compatibility::CONFIG, Compatibility::CATALOG, 'kotlin', 'kotlin.bat'] + modules.map { |name| name + '/module.yaml' }
      paths.to_h do |path|
        content = File.read(File.join(work, path), encoding: 'UTF-8')
        raise Failure, 'Declared compatibility input is not UTF-8' unless content.valid_encoding?
        [path, content]
      end
    end

    def initialize(source, output, cache, host_file, profile)
      super(source, output, cache, host_file, 'mobile')
      @profile = profile
      @report['profile'] = profile
      @resolution_only = profile == 'direct-resolution'
      @build_inputs = %w[direct-build-inputs upstream-build-inputs].include?(profile)
      @collect_resolution = @resolution_only || @build_inputs
      @report['cells'] = {}
      @report['missing_capabilities'] = Compatibility::UNPROVEN.dup
      @report['missing_capabilities'] += DirectResolution::GAPS if @collect_resolution
      @report['missing_capabilities'] += BuildInputs::GAPS if @build_inputs
      @report['bridge_retirement'] = 'defer'
      @direct = profile.start_with?('direct-') && @report['phase'] == 'candidate'
      if profile.start_with?('upstream-')
        wrappers = KotlinWrappers.new(source)
        @report['candidate_selection'] = @host.fetch('upstream_selection')
        expected = @report['phase'] == 'baseline' ? wrappers.pins.fetch('baseline') : @report['candidate_selection'].fetch('version')
        raise Failure, 'Upstream phase differs from pinned Toolchain' unless @version == expected && BuildInputs::COMPILERS.key?(@version)
      else
        assessment = Compatibility.new(source, experimental: @host.fetch('experimental', false))
        @report['candidate_selection'] = assessment.selection
      end
      @report['missing_capabilities'] << 'release_age' if @report['candidate_selection']['age_state'] == 'age_blocked'
      @report['configuration_sha256'] = Maintenance.file_sha(File.join(source, Compatibility::CONFIG))
      @report['di_reachability_scope'] = 'toolchain_module_graph_not_flattened_bridge'
    end

    def verify_source!
      super
      @experiment.verify_absence! if @experiment
      raise Failure, 'Generated workspace enabled IDE build skipping' if @env['OVERRIDE_KOTLIN_BUILD_IDE_SUPPORTED'] == 'YES'
    end

    def measured(name)
      @report['cells'][name] = { 'status' => 'running', 'evidence_kind' => 'local_execution' }
      result = catch(:outcome) do
        yield
        'passed'
      end
      @report['cells'][name]['status'] = result
      @report['cells'][name]['commands'] = @report['commands'].select { |command| command['capability'] == name }.map { |command| command['check'] }
      throw :outcome, result unless result == 'passed'
    end

    def command(name, argv)
      before = @report['commands'].size
      super
    ensure
      cell = @report['cells'].find { |_key, value| value['status'] == 'running' }
      @report['commands'].drop(before || 0).each { |entry| entry['capability'] = cell.first } if cell
    end

    def bridge_compile
      %w[compileKotlinIosSimulatorArm64 linkDebugFrameworkIosSimulatorArm64].each do |task|
        cell = task.start_with?('compile') ? 'native_library_compile' : 'framework_link'
        measured(cell) do
          command(cell, [File.join(@work, 'gradle-bridge/gradlew'), '--no-daemon', '--console=plain', '-p', File.join(@work, 'gradle-bridge'), ':shared-kit:' + task])
          if cell == 'framework_link'
            binaries = Dir.glob(File.join(@work, 'gradle-bridge/shared-kit/build/bin/**/KotlinModules.framework/KotlinModules'))
            throw :outcome, 'missing' if binaries.empty? || binaries.any? { |p| !File.file?(p) || File.size(p).zero? }
            write_evidence('linked-frameworks', binaries.to_h { |p| [p.delete_prefix(@work + '/'), Maintenance.file_sha(p)] })
          end
        end
      end
    end

    def native_cases(log, name, probe: false)
      tests = log.scan(/^Test case '([^']+)' passed on /).flatten.uniq.sort
      write_evidence(name, tests)
      original = tests.select { |test| test.start_with?('HomeFeatureTests/', 'NearbyVehicleMapFeatureTests/') }
      throw :outcome, 'missing' unless original.size >= 12 && original.any? { |test| test.start_with?('HomeFeatureTests/') } && original.any? { |test| test.start_with?('NearbyVehicleMapFeatureTests/') }
      throw :outcome, 'missing' if probe && !tests.include?('MobiIncrementalProbeTests/kotlinChangeReachesSwift()')
    end

    def frameworks
      files = Dir.glob(File.join(@work, 'build', '**', 'KotlinModules.framework', 'KotlinModules')).select { |p| File.file?(p) && !File.symlink?(p) && File.size(p) > 0 }
      raise Failure, 'No roundtrip framework identity' if files.empty?
      files.sort.to_h { |p| [p.delete_prefix(@work + '/'), Maintenance.file_sha(p)] }
    end

    def roundtrip
      before = frameworks
      write_evidence('direct-frameworks-before', before)
      write_evidence('incremental-mutation', @experiment.mutate!)
      @manifest = @experiment.manifest
      write_evidence('incremental-source-manifest', @manifest)
      measured('incremental_ios_test') do
        log = command('incremental_ios_test', [File.join(@work, 'scripts/ci/run_job.sh'), 'ios-test'])
        native_cases(log, 'incremental-native-test-cases', probe: true)
      end
      measured('incremental_ios_build') { command('incremental_ios_build', [File.join(@work, 'scripts/ci/run_job.sh'), 'ios-build-debug']) }
      measured('incremental_framework_change') do
        after = frameworks
        write_evidence('direct-frameworks-after', after)
        changed = (before.keys & after.keys).select { |path| before[path] != after[path] }.sort
        write_evidence('incremental-framework-change', { 'changed' => changed })
        throw :outcome, 'missing' if changed.empty?
      end
      measured('bridge_restore') do
        restoration = @experiment.restore!
        @manifest = @experiment.manifest
        @direct = false
        @env['KOTLIN_IOS_BUILDER'] = 'gradle'
        @report['environment']['final_bridge'] = 'gradle'
        write_evidence('roundtrip-restoration', restoration)
        write_evidence('restored-source-manifest', @manifest)
        verify_source!
      end
      @report['cells']['bridge_restore']['evidence_kind'] = 'isolated_source_transformation'
      measured('rollback_ios_test') do
        log = command('rollback_ios_test', [File.join(@work, 'scripts/ci/run_job.sh'), 'ios-test'])
        native_cases(log, 'rollback-native-test-cases')
      end
      measured('rollback_ios_build') { command('rollback_ios_build', [File.join(@work, 'scripts/ci/run_job.sh'), 'ios-build-debug']) }
      write_evidence('rollback-frameworks', frameworks)
    end

    def run
      outcome = catch(:outcome) do
        write_evidence('source-manifest', @manifest)
        write_evidence('declared-inputs', self.class.declared_inputs(@work, @modules))
        if @direct
          experiment_class = @profile == 'direct-roundtrip' ? DirectRoundtrip : InteropExperiment
          @experiment = experiment_class.new(@work, File.join(@work, 'scripts/maintenance/fixtures/interop'))
          changes = @experiment.prepare!
          write_evidence('experiment-transformations', changes)
          @manifest = @profile == 'direct-roundtrip' ? @experiment.manifest : tree(@work)
          @report['bridge_unavailable'] = true
          @report['bridge_absence_scope'] = 'direct_checks_before_restoration' if @profile == 'direct-roundtrip'
          @report['authored_experiment_sha256'] = Maintenance.digest(@manifest)
          write_evidence('direct-source-manifest', @manifest) if @profile == 'direct-roundtrip' || @collect_resolution
        end
        if @collect_resolution
          declarations = self.class.declared_inputs(@work, @modules).merge('project.yaml' => File.read(File.join(@work, 'project.yaml'), encoding: 'UTF-8'))
          write_evidence('resolution-declarations', declarations)
        end
        write_evidence('reachable-modules', InteropExperiment.reachable_modules(@work))
        @report['di_reachable'] = InteropExperiment.reachable_modules(@work).include?('shared-di')
        raise Failure, 'Direct experiment does not reach shared DI' if @direct && !@report['di_reachable']
        if @build_inputs
          native_setup(simulator: false)
          init = File.join(@env.fetch('GRADLE_USER_HOME'), 'init.d')
          FileUtils.mkdir_p(init)
          FileUtils.cp(File.join(@work, 'scripts/maintenance/adapters/delegated_resolution.gradle'), File.join(init, 'mobi-evidence.gradle'))
        elsif @resolution_only
          @env.merge!('JAVA_HOME' => @host.fetch('java_home'), 'DEVELOPER_DIR' => @host.fetch('developer_dir'))
          @report['environment'] = { 'scope' => 'resolution_only', 'simulator' => 'not_created', 'native_execution' => 'not_attempted' }
        elsif %w[upstream-android-packaging upstream-ios-release upstream-ios-archive].include?(@profile)
          native_setup(simulator: false)
        else
          native_setup
        end
        @env['OVERRIDE_KOTLIN_BUILD_IDE_SUPPORTED'] = 'NO'
        @env['KOTLIN_IOS_BUILDER'] = @direct ? 'kotlin' : 'gradle'
        @report['environment']['bridge'] = @env['KOTLIN_IOS_BUILDER']
        measured('effective_toolchain') do
          banner = cli('version', '--version')
          raise Failure, 'Executed Toolchain version differs' unless banner.include?('Kotlin Toolchain version ' + @version + ' ')
          write_evidence('effective-settings', KotlinEvidence.settings(cli('settings', 'show', 'settings', '--all-modules'), modules: @modules, version: @version, source: @work))
        end
        if @profile == 'bridge-review' || @collect_resolution
          measured('toolchain_resolution') do
            graphs = KotlinEvidence.graphs(cli('dependencies', 'show', 'dependencies', '--all-modules', '--include-tests'), modules: @modules, version: @version)
            DirectResolution.coverage!(graphs, declarations) if @collect_resolution
            write_evidence('resolved-graphs', graphs)
          end
        end
        if @profile == 'bridge-review'
          measured('bridge_resolution') do
            begin
              text = command('bridge-resolution', [File.join(@work, 'gradle-bridge/gradlew'), '--no-daemon', '--console=plain', '-p', File.join(@work, 'gradle-bridge'),
              '-I', File.join(@work, 'scripts/maintenance/adapters/bridge_resolution.gradle'), 'mobiResolutionEvidence'])
              write_evidence('bridge-resolution', UpgradeGraph.parse(text))
            ensure
              log = File.join(@control, 'bridge-resolution.log')
              if File.file?(log)
                lines = File.readlines(log).grep(/^MOBI_RESOLUTION_JSON=/)
                write_evidence('bridge-resolution-partial', JSON.parse(lines.first.delete_prefix(UpgradeGraph::PREFIX))) if lines.size == 1
              end
            end
          end
        end
        packaging = %w[upstream-android-packaging upstream-ios-release upstream-ios-archive].include?(@profile)
        bridge_compile unless @direct || @collect_resolution || packaging
        unless @profile == 'bridge-compile' || @collect_resolution || packaging
          %w[android-test android-build-debug ios-test ios-build-debug].each do |job|
            measured(job) do
              log = command(job, [File.join(@work, 'scripts/ci/run_job.sh'), job])
              if job == 'ios-test'
                native_cases(log, 'native-test-cases', probe: @direct && @profile == 'direct-roundtrip')
              end
            end
          end
        end
        if @profile == 'upstream-android-packaging'
          measured('android-build-debug') { command('android-build-debug', [File.join(@work, 'scripts/ci/run_job.sh'), 'android-build-debug']) }
          measured('android_release') { cli('android-release', 'build', '-m', 'android-app', '-p', 'android', '-v', 'release') }
          measured('android_aab') { command('android-aab', [File.join(@work, 'scripts/ci/build_android_aab.sh')]) }
          @report['release_scope'] = 'synthetic_android_signing_no_delivery'
        end
        if @profile == 'upstream-ios-release'
          measured('ios_release_simulator') { command('ios-release-simulator', [File.join(@work, 'scripts/ci/run_job.sh'), 'ios-build-release']) }
          @report['release_scope'] = 'unsigned_ios_release_simulator_build'
        end
        if @profile == 'upstream-ios-archive'
          measured('ios_unsigned_archive') do
            command('ios-unsigned-archive', ['/usr/bin/xcodebuild', '-project', File.join(@work, 'ios-app/module.xcodeproj'), '-scheme', 'app', '-configuration', 'Release', '-destination', 'generic/platform=iOS', '-derivedDataPath', File.join(@work, 'build/archive-derived'), '-archivePath', File.join(@work, 'build/releases/Mobi.xcarchive'), 'CODE_SIGNING_ALLOWED=NO', 'CODE_SIGNING_REQUIRED=NO', 'SWIFT_ENABLE_EXPLICIT_MODULES=NO', 'archive'])
          end
          @report['release_scope'] = 'unsigned_ios_device_archive_no_export_or_delivery'
        end
        if @build_inputs
          %w[android-test android-build-debug].each do |job|
            measured(job) { command(job, [File.join(@work, 'scripts/ci/run_job.sh'), job]) }
          end
          %w[iosArm64 iosSimulatorArm64].each do |platform|
            measured('native_klib_' + platform.downcase) do
              args = @modules.reject { |name| %w[android-app ios-app].include?(name) }.flat_map { |name| ['-m', name] }
              cli('klib-' + platform.downcase, 'build', *args, '-p', platform)
            end
          end
          measured('build_input_evidence') do
            BuildInputs.capture(@work, @cache, @env.fetch('HOME'), @control, compiler_version: BuildInputs::COMPILERS.fetch(@version))
            %w[compiler-traces selected-plugin-artifacts delegated-graphs].each do |name|
              write_evidence(name, JSON.parse(File.read(File.join(@control, name + '.json'))))
            end
            write_evidence('build-inputs', BuildInputs.read(@control, compiler_version: BuildInputs::COMPILERS.fetch(@version)))
          end
        end
        roundtrip if @direct && @profile == 'direct-roundtrip'
        'passed'
      end
      outcome
    rescue Failure => error
      @report['failure'] = error.message
      'refused'
    rescue StandardError => error
      @report['failure'] = 'Adapter exception: ' + error.class.name
      @report['exception_class'] = error.class.name
      origin = error.backtrace_locations&.find { |entry| entry.absolute_path&.start_with?(File.expand_path(__dir__) + '/') }
      @report['failure_origin'] = File.basename(origin.absolute_path) + ':' + origin.lineno.to_s if origin
      File.write(File.join(@control, 'adapter-error.log'), error.full_message)
      'infrastructure'
    ensure
      begin
        @report['cells'].each_value { |cell| cell['status'] = 'infrastructure' if cell['status'] == 'running' }
        %w[native_library_compile framework_link android-test android-build-debug ios-test ios-build-debug].each do |cell|
          @report['cells'][cell] ||= { 'status' => 'not_attempted', 'evidence_kind' => 'none' }
        end
        if @profile == 'direct-roundtrip' && @report['phase'] == 'candidate'
          %w[incremental_ios_test incremental_ios_build incremental_framework_change bridge_restore rollback_ios_test rollback_ios_build].each do |cell|
            @report['cells'][cell] ||= { 'status' => 'not_attempted', 'evidence_kind' => 'none' }
          end
        end
        products = %w[build gradle-bridge/shared-kit/build].flat_map { |dir| Dir.glob(File.join(@work, dir, '**', '*')) }.select { |p| File.file?(p) && !File.symlink?(p) && p.match?(/\.(?:apk|aab)\z|\.app\/|\.framework\/|\.xcarchive\//) }
        write_evidence('products', products.sort.to_h { |p| [p.delete_prefix(@work + '/'), Maintenance.file_sha(p)] })
        if @report['sdk_provisioning']
          sdk = @env.fetch('ANDROID_HOME')
          write_evidence('sdk-final-inputs', Dir.glob(File.join(sdk, '**', '{package.xml,source.properties}')).sort.to_h { |p| [p.delete_prefix(sdk + '/'), Maintenance.file_sha(p)] })
          @report['sdk_provisioning']['final_api_37_present'] = File.file?(File.join(sdk, 'platforms/android-37.0/android.jar'))
        end
        write_evidence('downloaded-artifacts', { 'cache' => KotlinEvidence.artifacts(@cache), 'home' => KotlinEvidence.artifacts(ENV.fetch('HOME')) })
        @report['source_preservation'] = 'verified'
        verify_source!
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

if $PROGRAM_NAME == __FILE__
  check = Maintenance::CompatibilityCheck.new(*ARGV)
  status = check.run
  status = 'refused' if check.report['evidence_failure']
  evidence = File.join(File.dirname(ENV.fetch('MOBI_RESULT_PATH')), 'evidence.json')
  Maintenance::RunStore.atomic(ENV.fetch('MOBI_RESULT_PATH'), { 'schema' => 1, 'check' => ARGV.last, 'phase' => ENV.fetch('MOBI_PHASE'),
                                                               'status' => status, 'evidence_sha256' => Maintenance.file_sha(evidence) })
  exit(status == 'passed' ? 0 : 1)
end
