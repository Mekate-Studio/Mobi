# frozen_string_literal: true

require_relative 'quality'
require_relative '../ci/test_modules'
require 'tempfile'

module Precommit
  def self.head
    output, status = Open3.capture2({ 'GIT_OPTIONAL_LOCKS' => '0' }, 'git', 'rev-parse', '--verify', '--quiet', 'HEAD')
    return nil if status.exitstatus == 1 && output.empty? # A new repository has no HEAD yet.
    raise Quality::Failure, 'Cannot resolve validation base commit' unless status.success?

    output.strip
  end

  class Plan
    attr_reader :data

    def initialize
      guard = Quality::CommitGuard.new
      index = guard.snapshot
      base = Precommit.head
      paths = Quality.git('diff', '--cached', '--name-only', '--no-renames', '--no-ext-diff', '--no-textconv', '-z').split("\0")
      Tempfile.create('mobi-paths-') do |file|
        file.binmode
        file.write(paths.join("\0") + (paths.empty? ? '' : "\0"))
        file.flush
        output, status = Open3.capture2({ 'GITHUB_OUTPUT' => nil }, './scripts/ci/classify_changes.sh', '--paths0-file', file.path)
        raise Quality::Failure, 'Changed-path classification failed' unless status.success?

        flags = output.lines.to_h { |line| line.strip.split('=', 2) }
        names = %w[docs_only shared_tests android_tests ios_tests android_build ios_build full_validation]
        raise Quality::Failure, 'Incomplete classification result' unless names.all? { |name| %w[true false].include?(flags[name]) }

        jobs = []
        jobs << 'android-test' if flags['android_tests'] == 'true' || flags['shared_tests'] == 'true'
        jobs << 'ios-test' if flags['ios_tests'] == 'true'
        jobs << 'android-build-debug' if flags['android_build'] == 'true'
        jobs << 'ios-build-debug' if flags['ios_build'] == 'true'
        @data = { 'schema' => 1, 'base_commit' => base, 'index_sha256' => index, 'paths' => paths, 'selection' => flags,
                  'jobs' => jobs, 'host_test_modules' => jobs.include?('android-test') ? HostTests.modules(paths: Quality.git('ls-files', '--cached', '-z').split("\0")) : [] }
      end
      raise Quality::Failure, 'Index changed while planning' unless guard.snapshot == index
      raise Quality::Failure, 'Base commit changed while planning' unless Precommit.head == base
    end
  end

  class Runner
    # Native tool locations/settings only. No signing/provider credentials or CI identity.
    ENV_KEYS = %w[PATH HOME USER LOGNAME LANG LC_ALL TMPDIR JAVA_HOME ANDROID_HOME ANDROID_SDK_ROOT DEVELOPER_DIR IOS_SIMULATOR_DESTINATION].freeze

    def initialize(plan, job_timeout: 2700, cleanup_timeout: 5, shutdown_timeout: 30)
      @plan = plan.data
      @root = Dir.pwd
      @guard = Quality::CommitGuard.new
      @job_timeout = job_timeout
      @cleanup_timeout = cleanup_timeout
      @shutdown_timeout = shutdown_timeout
    end

    def verify_caller!
      raise Quality::Failure, 'Caller index changed during validation; rerun' unless @guard.snapshot == @plan.fetch('index_sha256')
      raise Quality::Failure, 'Caller base commit changed during validation; rerun' unless Precommit.head == @plan.fetch('base_commit')
    end

    def tracked_manifest(root, paths)
      paths.to_h do |path|
        file = File.join(root, path)
        parts = path.split('/')
        if parts.each_index.any? { |i| File.symlink?(File.join(root, *parts.take(i + 1))) }
          raise Quality::Failure, "Snapshot symlinks are unsupported: #{path.inspect}"
        end
        stat = File.stat(file)
        raise Quality::Failure, "Snapshot input is not a regular file: #{path.inspect}" unless stat.file?

        [path, { 'sha256' => Digest::SHA256.file(file).hexdigest, 'executable' => (stat.mode & 0o111) != 0 }]
      end
    rescue Errno::ENOENT => error
      raise Quality::Failure, "Snapshot input missing: #{error.message}"
    end

    def verify_copy!(copy, expected)
      actual = tracked_manifest(copy, expected.keys)
      changed = expected.keys.select { |path| actual[path] != expected[path] }
      raise Quality::Failure, "Snapshot inputs changed: #{changed.map(&:inspect).join(', ')}; fix preparation outside the gate and rerun" unless changed.empty?

      modules = expected.keys.grep(/\/module\.yaml\z/).map { |path| File.dirname(path) }
      sources = modules.flat_map do |name|
        Dir.glob(File.join(copy, name, '{src,src@*,test,test@*,tests}/**/*.{kt,kts,swift}'))
      end
      sources += Dir.glob(File.join(copy, 'ios-app/Dependencies/{Sources,Tests}/**/*.swift'))
      added = sources.map { |path| path.delete_prefix(copy + '/') }.uniq - expected.keys
      raise Quality::Failure, "Unexpected authored source in snapshot: #{added.map(&:inspect).join(', ')}" unless added.empty?
    end

    def verify_index_copy!(copy, entries, flags, format)
      unless Digest::SHA256.hexdigest(entries + flags.split("\0").join("\0")) == @plan.fetch('index_sha256')
        raise Quality::Failure, 'Captured index differs from the validation plan'
      end
      digest = { 'sha1' => Digest::SHA1, 'sha256' => Digest::SHA256 }.fetch(format)
      entries.split("\0").each do |entry|
        metadata, path = entry.split("\t", 2)
        mode, oid, stage = metadata.split(' ')
        file = File.join(copy, path)
        bytes = File.binread(file)
        actual_mode = (File.stat(file).mode & 0o111).zero? ? '100644' : '100755'
        actual_oid = digest.hexdigest("blob #{bytes.bytesize}\0".b + bytes)
        unless stage == '0' && actual_mode == mode && actual_oid == oid
          raise Quality::Failure, "Copied input differs from staged Git object: #{path.inspect}"
        end
      end
    end

    def run
      verify_caller!
      puts "[validation] plan=#{JSON.generate(@plan)}"
      Quality::Runner.new('commit').run
      verify_caller!
      paths = Quality.git('ls-files', '--cached', '-z').split("\0").sort
      entries = Quality.git('ls-files', '--stage', '-z')
      flags = Quality.git('ls-files', '-v', '-z')
      format = Quality.git('rev-parse', '--show-object-format').strip
      expected = tracked_manifest(@root, paths)
      completed = []
      unless @plan.fetch('jobs').empty?
        copy = Dir.mktmpdir('mobi-validation-')
        begin
          puts "[validation] workspace=#{copy}"
          paths.each do |path|
            target = File.join(copy, path)
            FileUtils.mkdir_p(File.dirname(target))
            FileUtils.cp(File.join(@root, path), target, preserve: true)
          end
          verify_copy!(copy, expected)
          verify_index_copy!(copy, entries, flags, format)
          verify_caller!
          env = ENV_KEYS.to_h { |key| [key, ENV[key]] }.reject { |_key, value| value.nil? }
          env.merge!('MOBI_VALIDATION' => '1', 'CI_PROJECT_DIR' => copy,
                     'KOTLIN_IOS_BUILDER' => 'gradle', 'IOS_TEST_PLAN' => 'PullRequest',
                     'KOTLIN_CLI_BOOTSTRAP_CACHE_DIR' => File.join(copy, '.kotlin-cache'),
                     'GRADLE_USER_HOME' => File.join(copy, '.gradle-user-home'))
          FileUtils.mkdir_p(env.fetch('GRADLE_USER_HOME'))
          File.write(File.join(env.fetch('GRADLE_USER_HOME'), 'gradle.properties'), "org.gradle.daemon=false\nkotlin.compiler.execution.strategy=in-process\n")
          @plan.fetch('jobs').each do |job|
            verify_caller!
            verify_copy!(copy, expected)
            started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            begin
              run_job(copy, env, job)
            ensure
              verify_copy!(copy, expected)
              verify_caller!
            end
            completed << { 'job' => job, 'seconds' => (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(3) }
          end
        ensure
          stop_gradle_daemons(copy, env) if env
          cleanup_copy(copy)
        end
      end
      verify_caller!
      puts "[validation] passed=#{JSON.generate('index_sha256' => @plan['index_sha256'], 'inputs_sha256' => Digest::SHA256.hexdigest(JSON.generate(expected)), 'completed' => completed)}"
    ensure
      verify_caller!
    end

    def cleanup_copy(copy)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + @cleanup_timeout
      begin
        FileUtils.remove_entry_secure(copy)
      rescue Errno::ENOTEMPTY
        # Exiting native daemons can briefly recreate registry metadata during removal.
        if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
          raise Quality::Failure, "Cleanup incomplete: #{copy}; inspect residual owned processes before removing this directory; no pass recorded"
        end
        sleep 0.1
        retry
      end
    end

    def stop_gradle_daemons(copy, env)
      home = File.join(copy, '.gradle-user-home')
      registry = File.join(home, 'daemon')
      return unless Dir.exist?(registry)

      unless File.realpath(home) == File.join(File.realpath(copy), '.gradle-user-home') && File.realpath(registry) == File.join(File.realpath(home), 'daemon')
        raise Quality::Failure, "Gradle registry escaped owned workspace; snapshot retained at #{copy}"
      end
      versions = Dir.children(registry).select { |version| File.directory?(File.join(registry, version)) }.sort
      versions.each do |version|
        unless version.match?(/\A[0-9][A-Za-z0-9.+-]*\z/) && !File.symlink?(File.join(registry, version))
          raise Quality::Failure, "Unrecognized owned Gradle registry: #{registry}; snapshot retained for recovery"
        end
        launcher = Dir.glob(File.join(home, 'wrapper/dists/gradle-*/*', "gradle-#{version}/bin/gradle")).find do |path|
          File.executable?(path) && File.realpath(path).start_with?(File.realpath(home) + '/')
        end
        raise Quality::Failure, "Cannot stop owned Gradle #{version}: installed launcher missing; snapshot retained at #{copy}" unless launcher

        # Tooling API builds always use daemons, even with org.gradle.daemon=false.
        # Use only the installed distribution and this snapshot's private registry.
        java = PinnedQuality::Toolchain.new(@root).command('java').first
        shutdown_env = env.merge('JAVA_HOME' => File.dirname(File.dirname(java)))
        puts "[validation] stopping-gradle=#{version}"
        status = run_process(copy, shutdown_env, [launcher, '--gradle-user-home', home, '--offline', '--stop'], timeout: @shutdown_timeout)
        raise Quality::Failure, "Gradle shutdown failed: #{version}; snapshot retained at #{copy}" unless status.success?
      end
    rescue Interrupt, Timeout::Error
      raise Quality::Failure, "Gradle shutdown interrupted or timed out; snapshot retained at #{copy}; inspect owned processes before removal"
    end

    def run_job(copy, env, job)
      puts "[validation] running=#{job}"
      status = run_process(copy, env, ['./scripts/ci/run_job.sh', job], timeout: @job_timeout)
      raise Quality::Failure, "Validation job failed: #{job}; inspect the output, fix or prepare prerequisites, and rerun" unless status.success?
    rescue Interrupt, Timeout::Error
      raise Quality::Failure, "Validation interrupted or timed out: #{job}; no pass recorded"
    end

    def run_process(copy, env, command, timeout:)
      pid = Process.spawn(env, *command, chdir: copy, unsetenv_others: true, pgroup: true)
      Timeout.timeout(timeout) { Process.wait2(pid).last }
    ensure
      if pid
        Process.kill('TERM', -pid) rescue Errno::ESRCH
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
        loop do
          Process.waitpid(pid, Process::WNOHANG) rescue Errno::ECHILD
          begin
            Process.kill(0, -pid)
          rescue Errno::ESRCH
            break
          end
          if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
            Process.kill('KILL', -pid) rescue Errno::ESRCH
            break
          end
          sleep 0.05
        end
        Process.wait(pid) rescue Errno::ECHILD
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    Dir.chdir(File.expand_path('../..', __dir__))
    raise Quality::Failure, 'Usage: check.sh [--plan|--manifest|--static]' unless ARGV.empty? || ARGV == ['--plan']

    trap('TERM') { raise Interrupt }
    plan = Precommit::Plan.new
    ARGV == ['--plan'] ? puts(JSON.pretty_generate(plan.data)) : Precommit::Runner.new(plan).run
  rescue Quality::Failure, PinnedQuality::Failure, SystemCallError, Interrupt => error
    warn "[validation] FAIL: #{error.message}"
    exit 1
  end
end
