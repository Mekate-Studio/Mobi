# frozen_string_literal: true

require_relative 'kotlin_check'
require_relative 'adapters/compatibility'
require_relative 'adapters/interop_experiment'

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
      @report['cells'] = {}
      @report['missing_capabilities'] = Compatibility::UNPROVEN.dup
      @report['bridge_retirement'] = 'defer'
      @direct = profile == 'direct-facade' && @report['phase'] == 'candidate'
      @config = Compatibility.new(source).config
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

    def run
      outcome = catch(:outcome) do
        write_evidence('source-manifest', @manifest)
        write_evidence('declared-inputs', self.class.declared_inputs(@work, @modules))
        if @direct
          @experiment = InteropExperiment.new(@work, File.join(@work, 'scripts/maintenance/fixtures/interop'))
          changes = @experiment.prepare!
          write_evidence('experiment-transformations', changes)
          @manifest = tree(@work)
          @report['bridge_unavailable'] = true
          @report['authored_experiment_sha256'] = Maintenance.digest(@manifest)
        end
        write_evidence('reachable-modules', InteropExperiment.reachable_modules(@work))
        @report['di_reachable'] = InteropExperiment.reachable_modules(@work).include?('shared-di')
        raise Failure, 'Direct experiment does not reach shared DI' if @direct && !@report['di_reachable']
        native_setup
        @env['OVERRIDE_KOTLIN_BUILD_IDE_SUPPORTED'] = 'NO'
        @env['KOTLIN_IOS_BUILDER'] = @direct ? 'kotlin' : 'gradle'
        @report['environment']['bridge'] = @env['KOTLIN_IOS_BUILDER']
        measured('effective_toolchain') do
          banner = cli('version', '--version')
          raise Failure, 'Executed Toolchain version differs' unless banner.include?('Kotlin Toolchain version ' + @version + ' ')
          write_evidence('effective-settings', KotlinEvidence.settings(cli('settings', 'show', 'settings', '--all-modules'), modules: @modules, version: @version, source: @work))
        end
        bridge_compile unless @direct
        unless @profile == 'bridge-compile'
          %w[android-test android-build-debug ios-test ios-build-debug].each do |job|
            measured(job) do
              log = command(job, [File.join(@work, 'scripts/ci/run_job.sh'), job])
              if job == 'ios-test'
                tests = log.scan(/^Test case '([^']+)' passed on /).flatten.uniq.sort
                write_evidence('native-test-cases', tests)
                # Current Mobi has 3 Home and 9 Nearby Swift Testing cases.
                throw :outcome, 'missing' unless tests.size >= 12 && tests.any? { |t| t.start_with?('HomeFeatureTests/') } && tests.any? { |t| t.start_with?('NearbyVehicleMapFeatureTests/') }
              end
            end
          end
        end
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
        products = %w[build gradle-bridge/shared-kit/build].flat_map { |dir| Dir.glob(File.join(@work, dir, '**', '*')) }.select { |p| File.file?(p) && !File.symlink?(p) && p.match?(/\.apk\z|\.app\/|\.framework\//) }
        write_evidence('products', products.sort.to_h { |p| [p.delete_prefix(@work + '/'), Maintenance.file_sha(p)] })
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
