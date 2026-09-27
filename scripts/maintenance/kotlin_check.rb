# frozen_string_literal: true

require_relative 'lib/kotlin_evidence'
require_relative 'adapters/kotlin_resources'
require_relative 'adapters/kotlin_targets'
require_relative 'adapters/mobile_support'

module Maintenance
  class KotlinCheck
    attr_reader :report

    def initialize(source, output, cache, host_file, profile)
      @source, @output, @cache, @profile = source, output, cache, profile
      @host = JSON.parse(File.read(host_file))
      @control = File.dirname(ENV.fetch('MOBI_RESULT_PATH'))
      @work = File.join(output, 'project')
      @report = { 'schema' => 1, 'profile' => profile, 'phase' => ENV.fetch('MOBI_PHASE'), 'commands' => [], 'missing_capabilities' => [], 'adoption_authorized' => false }
      @report['target_policy'] = @host.fetch('target_policy', 'current')
      @manifest = tree(source)
      FileUtils.cp_r(source, @work)
      @modules = YAML.safe_load(File.read(File.join(@work, 'project.yaml'))).fetch('modules')
      raise Failure, 'Unsupported module declaration' unless @modules.is_a?(Array) && @modules.all? { |name| name.is_a?(String) && name.match?(/\A[A-Za-z0-9_-]+\z/) }
      @version = File.read(File.join(@work, 'kotlin'), encoding: 'UTF-8')[/^kotlin_cli_version=(.+)$/, 1]
      @env = ENV.to_h.merge('PATH' => File.dirname(@host.fetch('ruby')) + ':/usr/bin:/bin:/usr/sbin:/sbin',
                           'LANG' => 'en_US.UTF-8', 'LC_ALL' => 'en_US.UTF-8', 'NO_COLOR' => '1', 'TERM' => 'dumb',
                           'KOTLIN_CLI_BOOTSTRAP_CACHE_DIR' => File.join(cache, 'bootstrap'), 'KOTLIN_CLI_USER_HOME' => ENV.fetch('HOME'),
                           'KOTLIN_CLI_JAVA_OPTIONS' => "-Duser.home=#{ENV.fetch('HOME')} -Djava.io.tmpdir=#{ENV.fetch('TMPDIR')}",
                           'KOTLIN_CLI_NO_WELCOME_BANNER' => '1', 'KOTLIN_MISSING_ARTIFACT_RETRIES' => '1',
                           'GRADLE_USER_HOME' => File.join(cache, 'gradle'), 'KONAN_DATA_DIR' => File.join(cache, 'konan'))
      @native = KotlinResources.new(@control, ENV.fetch('MOBI_RESOURCE_NONCE')) if profile == 'mobile'
    end

    def tree(root)
      Dir.glob(File.join(root, '**', '*'), File::FNM_DOTMATCH).sort.each_with_object({}) do |path, files|
        next if %w[. ..].include?(File.basename(path)) || File.directory?(path) && !File.symlink?(path)
        raise Failure, 'Authored source symlink or special file' unless File.file?(path) && !File.symlink?(path)
        files[path.delete_prefix(root + '/')] = { 'sha256' => Maintenance.file_sha(path), 'executable' => (File.stat(path).mode & 0o111) != 0 }
      end
    end

    def verify_source!
      @manifest.each do |relative, identity|
        file = File.join(@work, relative)
        unless File.file?(file) && !File.symlink?(file) && Maintenance.file_sha(file) == identity['sha256'] && ((File.stat(file).mode & 0o111) != 0) == identity['executable']
          raise Failure, 'Generated workspace changed an authored input'
        end
      end
      roots = @modules.flat_map { |name| Dir.glob(File.join(@work, name, '{src,src@*,test,test@*,tests}/**/*.{kt,kts,swift}')) }
      roots += Dir.glob(File.join(@work, 'ios-app/Dependencies/{Sources,Tests}/**/*.swift'))
      raise Failure, 'Generated workspace added authored source' unless (roots.map { |path| path.delete_prefix(@work + '/') } - @manifest.keys).empty?
    end

    def command(name, argv)
      verify_source!
      log = File.join(@control, name + '.log')
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      File.open(log, 'w') do |stream|
        pid = Process.spawn(@env, [argv.first, argv.first], *argv.drop(1), chdir: @work, unsetenv_others: true,
                            close_others: true, in: File::NULL, out: stream, err: [:child, :out])
        status = nil; observed_at = 0
        until status
          pair = Process.wait2(pid, Process::WNOHANG); status = pair && pair.last
          now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          if @native && now - observed_at >= 1
            @native.observe!; observed_at = now
          end
          sleep 0.1 unless status
        end
        code = status.exitstatus || 128 + status.termsig
        @report['commands'] << { 'check' => name, 'exit' => code, 'seconds' => (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start).round(3), 'log' => name + '.log', 'sha256' => Maintenance.file_sha(log) }
        puts "#{name}: exit #{code}"; $stdout.flush
        verify_source!
        text = File.read(log, encoding: 'UTF-8', invalid: :replace, undef: :replace)
        classified = KotlinEvidence.classify(text, code)
        throw :outcome, classified unless classified == 'passed'
        text
      end
    end

    def cli(name, *args)
      command(name, [File.join(@work, 'kotlin'), '--shared-cache-dir', File.join(@cache, 'toolchain')] + args)
    end

    def write_evidence(name, value)
      file = File.join(@control, name + '.json')
      RunStore.atomic(file, value)
      @report[name] = { 'file' => name + '.json', 'sha256' => Maintenance.file_sha(file) }
    end

    def native_setup
      sdk = @host.fetch('android_sdk'); target = File.join(@output, 'android-sdk')
      # APFS clone keeps the phase writable and independent without duplicating
      # every SDK block. A different filesystem falls back to an ordinary copy.
      _, status = Open3.capture2e('/bin/cp', '-cR', sdk, target)
      unless status.success?
        FileUtils.remove_entry_secure(target) if File.exist?(target)
        FileUtils.cp_r(sdk, target)
      end
      @env.merge!('ANDROID_HOME' => target, 'ANDROID_SDK_ROOT' => target, 'JAVA_HOME' => @host.fetch('java_home'),
                  'DEVELOPER_DIR' => @host.fetch('developer_dir'), 'CI_PROJECT_DIR' => @work,
                  'MOBI_VALIDATION' => '1', 'KOTLIN_IOS_BUILDER' => 'gradle', 'IOS_TEST_PLAN' => 'PullRequest',
                  'SKIP_MACRO_VALIDATION' => 'YES', 'SWIFT_ENABLE_EXPLICIT_MODULES' => 'NO')
      FileUtils.mkdir_p(@env['GRADLE_USER_HOME'])
      File.write(File.join(@env['GRADLE_USER_HOME'], 'gradle.properties'), "org.gradle.daemon=false\norg.gradle.daemon.idletimeout=1000\nkotlin.compiler.execution.strategy=in-process\norg.gradle.jvmargs=-Xmx4g #{@native.tag}\n")
      sdk_files = Dir.glob(File.join(target, '**', '{package.xml,source.properties}')).sort.to_h { |file| [file.delete_prefix(target + '/'), Maintenance.file_sha(file)] }
      write_evidence('sdk-inputs', sdk_files)
      major = @host['candidate_ios_minimum_major'] if @report['phase'] == 'candidate'
      id = @native.create_simulator!(@host.fetch('developer_dir'), major: major)
      @env['IOS_SIMULATOR_DESTINATION'] = 'platform=iOS Simulator,id=' + id
      @report['environment'] = { 'bridge' => 'gradle', 'test_plan' => 'PullRequest', 'macro_validation' => 'skipped_explicitly', 'sdk' => 'private_copy', 'simulator' => 'owned_device', 'java_sha256' => Maintenance.file_sha(File.join(@host['java_home'], 'bin/java')) }
      @report['environment']['simulator_runtime'] = @native.state.fetch('runtime')
      @report['environment']['required_minimum_major'] = major
    end

    def run
      outcome = catch(:outcome) do
        banner = cli('version', '--version')
        raise Failure, 'Executed Toolchain version differs from wrapper' unless banner.include?('Kotlin Toolchain version ' + @version + ' ')
        @report['toolchain_version'] = @version
        write_evidence('support-declarations', MobileSupport.new(@work).declarations) if @host['support_policy']
        settings = KotlinEvidence.settings(cli('settings', 'show', 'settings', '--all-modules'), modules: @modules, version: @version, source: @work)
        if @host['support_policy']
          declared = MobileSupport.new(@work).declarations.fetch('android')
          actual = settings.fetch('android-app').fetch('settings@android').fetch('android')
          raise Failure, 'Effective Android SDKs differ from support declarations' unless declared.all? { |key, value| (actual[key].is_a?(Hash) ? actual[key]['apiLevel'] : actual[key]) == value }
        end
        write_evidence('effective-settings', settings)
        graphs = KotlinEvidence.graphs(cli('dependencies', 'show', 'dependencies', '--all-modules', '--include-tests'), modules: @modules, version: @version)
        if @report['target_policy'] == 'apple-silicon' && @report['phase'] == 'candidate'
          KotlinTargets.verify_graphs!(graphs)
          @report['excluded_targets'] = ['iosX64']
        end
        write_evidence('resolved-graphs', graphs)
        @report['coverage'] = { 'modules' => @modules, 'graph_roots' => graphs['graphs'].size, 'scope' => 'toolchain_module_dependencies_including_tests' }
        if @native
          native_setup
          %w[android-test android-build-debug ios-test ios-build-debug].each do |job|
            command(job, [File.join(@work, 'scripts/ci/run_job.sh'), job])
          end
          products = Dir.glob(File.join(@work, 'build', '**', '*')).select { |file| File.file?(file) && !File.symlink?(file) && file.match?(/\.apk\z|\.app\//) }
          write_evidence('debug-products', products.sort.to_h { |file| [file.delete_prefix(@work + '/'), Maintenance.file_sha(file)] })
          if @host['support_policy']
            apps = products.select { |file| file.end_with?('.app/Info.plist') }
            raise Failure, 'No built iOS app minimum evidence' if apps.empty?
            floors = apps.each_with_index.to_h do |file, index|
              minimum = command('ios-product-minimum-' + index.to_s, ['/usr/bin/plutil', '-extract', 'MinimumOSVersion', 'raw', '-o', '-', file]).strip
              if @report['phase'] == 'candidate'
                expected = MobileSupport.new(@work).declarations.fetch('swift_package_minimum')
                raise Failure, 'Built iOS product minimum differs from candidate' unless Gem::Version.new(minimum) == Gem::Version.new(expected)
              end
              [file.delete_prefix(@work + '/'), minimum]
            end
            write_evidence('ios-product-minimums', floors)
          end
        else
          @report['missing_capabilities'] += %w[native_tests native_builds compiler_artifacts]
        end
        'passed'
      end
      outcome
    rescue Failure => error
      @report['failure'] = error.message
      error.message.start_with?('Generated workspace') ? 'refused' : 'missing'
    rescue StandardError => error
      @report['failure'] = 'Adapter exception: ' + error.class.name
      file = File.join(@control, 'adapter-error.log')
      File.write(file, error.full_message)
      @report['exception_log_sha256'] = Maintenance.file_sha(file)
      'infrastructure'
    ensure
      begin
        artifacts = { 'cache' => KotlinEvidence.artifacts(@cache), 'home' => KotlinEvidence.artifacts(ENV.fetch('HOME')) }
        write_evidence('downloaded-artifacts', artifacts)
        @report['missing_capabilities'] += %w[complete_bridge_target_graph authenticated_provider_evidence signed_release_packaging direct_toolchain_parity]
        RunStore.atomic(File.join(@control, 'evidence.json'), @report)
      rescue StandardError
        @report['evidence_failure'] = true
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  source, output, cache, host_file, profile = ARGV
  check = Maintenance::KotlinCheck.new(source, output, cache, host_file, profile)
  status = check.run
  status = 'infrastructure' if check.report['evidence_failure']
  evidence = File.join(File.dirname(ENV.fetch('MOBI_RESULT_PATH')), 'evidence.json')
  Maintenance::RunStore.atomic(ENV.fetch('MOBI_RESULT_PATH'), { 'schema' => 1, 'check' => 'toolchain-' + profile, 'phase' => ENV.fetch('MOBI_PHASE'),
                                                               'status' => status, 'evidence_sha256' => File.file?(evidence) ? Maintenance.file_sha(evidence) : nil })
  exit(status == 'passed' ? 0 : 1)
end
