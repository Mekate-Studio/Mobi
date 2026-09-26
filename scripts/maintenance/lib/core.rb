# frozen_string_literal: true

require 'json'
require 'digest'
require 'fileutils'
require 'tmpdir'
require 'open3'
require 'timeout'
require 'time'
require 'pathname'

module Maintenance
  class Failure < StandardError; end

  def self.digest(value)
    Digest::SHA256.hexdigest(JSON.generate(value))
  end

  def self.file_sha(path)
    Digest::SHA256.file(path).hexdigest
  end

  def self.run(argv, cwd:, env:, log:, timeout: 300)
    File.open(log, 'w') do |output|
      pid = Process.spawn(env, *argv, chdir: cwd, unsetenv_others: true, pgroup: true, out: output, err: output)
      Timeout.timeout(timeout) { Process.wait2(pid).last }
    ensure
      if pid
        Process.kill('TERM', -pid) rescue Errno::ESRCH
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 3
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
  rescue Timeout::Error, Interrupt
    raise Failure, 'Command interrupted or timed out; no successful evidence recorded'
  end

  class Source
    attr_reader :root, :files

    def initialize(root)
      @root = File.realpath(root)
      refresh
      @files = manifest
    end

    def refresh
      git_env = { 'PATH' => '/usr/bin:/bin', 'LC_ALL' => 'C', 'GIT_CONFIG_GLOBAL' => File::NULL, 'GIT_CONFIG_NOSYSTEM' => '1', 'GIT_OPTIONAL_LOCKS' => '0' }
      output, status = Open3.capture2e(git_env, '/usr/bin/git', '-C', @root, 'ls-files', '--cached', '--others', '--exclude-standard', '-z', unsetenv_others: true)
      raise Failure, 'Cannot enumerate repository inputs' unless status.success?

      @paths = output.split("\0").uniq.sort
    end

    def manifest
      @paths.each_with_object({}) do |path, result|
        raise Failure, "Invalid source path: #{path.inspect}" if Pathname.new(path).absolute? || path.split('/').include?('..')

        full = File.join(@root, path)
        next unless File.exist?(full) || File.symlink?(full) # Tracked deletion remains absent in both snapshots.
        parts = path.split('/')
        raise Failure, "Source symlink unsupported: #{path.inspect}" if parts.each_index.any? { |i| File.symlink?(File.join(@root, *parts.take(i + 1))) }
        raise Failure, "Non-file source: #{path.inspect}" unless File.file?(full)

        result[path] = { 'sha256' => Maintenance.file_sha(full), 'executable' => (File.stat(full).mode & 0o111) != 0 }
      end
    end

    def verify!
      refresh
      raise Failure, 'Source changed during discovery; rerun' unless manifest == @files
    end

    def copy_to(destination)
      @files.each_key do |path|
        target = File.join(destination, path)
        FileUtils.mkdir_p(File.dirname(target))
        FileUtils.cp(File.join(@root, path), target, preserve: true)
      end
    end

    def verify_copy!(destination, expected: @files)
      paths = Dir.glob(File.join(destination, '**', '*'), File::FNM_DOTMATCH).reject { |path| %w[. ..].include?(File.basename(path)) || File.directory?(path) && !File.symlink?(path) }.map { |path| path.delete_prefix(destination + '/') }.sort
      raise Failure, 'Copied source changed: file set differs' unless paths == expected.keys.sort
      expected.each do |path, identity|
        target = File.join(destination, path)
        unless File.file?(target) && !File.symlink?(target) && Maintenance.file_sha(target) == identity['sha256'] && ((File.stat(target).mode & 0o111) != 0) == identity['executable']
          raise Failure, "Copied source changed: #{path.inspect}"
        end
      end
    end

    def public_identity
      public_files = @files.reject { |path, _| path.include?('/xcuserdata/') }
      { 'sha256' => Maintenance.digest(@files), 'files' => public_files, 'omitted_personal_metadata_paths' => @files.size - public_files.size }
    end
  end

  class NativeExtraction
    RECORD_KEYS = %w[depName packageName currentValue currentDigest lockedVersion datasource versioning depType skipReason registryUrls sharedVariableName].freeze

    def self.parse(log)
      records = File.readlines(log).map do |line|
        next if line.strip.empty?
        JSON.parse(line)
      rescue JSON::ParserError
        raise Failure, 'Malformed or truncated Renovate log'
      end.compact
      raise Failure, 'Renovate reported an error; no successful inventory recorded' if records.any? { |r| r.fetch('level', 0) >= 50 }
      extraction = records.select { |r| r['msg'] == 'Extracted dependencies' }
      config = records.reverse.find { |r| r['msg'] == 'Resolved shallow config, without merging internal presets' }
      unless extraction.size == 1 && extraction.first['packageFiles'].is_a?(Hash) && config && config['config'].is_a?(Hash) && records.any? { |r| r['msg'] == 'Repository finished' }
        raise Failure, 'Incomplete or unsupported Renovate extraction output'
      end
      files = extraction.first['packageFiles'].transform_values do |entries|
        raise Failure, 'Malformed native package files' unless entries.is_a?(Array)

        entries.map do |entry|
          raise Failure, 'Malformed native dependency records' unless entry['packageFile'].is_a?(String) && entry['deps'].is_a?(Array)

          { 'file' => entry['packageFile'], 'lock_files' => entry.fetch('lockFiles', []),
            'dependencies' => entry['deps'].map { |dep| dep.select { |key, _| RECORD_KEYS.include?(key) } } }
        end
      end
      { 'managers' => files, 'shallow_repository_config' => config.fetch('config'), 'visited_presets' => config.fetch('visitedPresets', []),
        'shallow_repository_config_sha256' => Maintenance.digest(config.fetch('config')), 'log_sha256' => Maintenance.file_sha(log),
        'warnings' => records.select { |r| r.fetch('level', 0) == 40 }.map { |r| r.fetch('msg') }.uniq }
    end

    def self.run(source, tools, timeout: 300)
      source.verify!
      result = nil
      Dir.mktmpdir('mobi-inventory-') do |owned|
        copy = File.join(owned, 'source')
        FileUtils.mkdir_p(copy)
        source.copy_to(copy)
        %w[home cache base].each { |name| FileUtils.mkdir_p(File.join(owned, name)) }
        config = { 'platform' => 'local', 'dryRun' => 'extract', 'onboarding' => false, 'requireConfig' => 'required',
                   'allowScripts' => false, 'allowPlugins' => false, 'allowedUnsafeExecutions' => [], 'exposeAllEnv' => false,
                   'baseDir' => File.join(owned, 'base'), 'cacheDir' => File.join(owned, 'cache') }
        repo_config = JSON.parse(File.read(File.join(copy, 'renovate.json')))
        validate_presets = lambda do |value|
          case value
          when Hash
            Array(value['extends']).each do |preset|
              raise Failure, 'External presets need an explicitly captured immutable adapter' unless preset.is_a?(String) && preset.start_with?('config:', ':')
            end
            value.each_value { |child| validate_presets.call(child) }
          when Array then value.each { |child| validate_presets.call(child) }
          end
        end
        validate_presets.call(repo_config)

        config_path = File.join(owned, 'config.json')
        File.write(config_path, JSON.generate(config))
        log = File.join(owned, 'renovate.jsonl')
        env = { 'PATH' => File.dirname(tools.node) + ':/usr/bin:/bin:/usr/sbin:/sbin', 'HOME' => File.join(owned, 'home'),
                'TMPDIR' => File.join(owned, 'base'), 'RENOVATE_CONFIG_FILE' => config_path, 'LOG_LEVEL' => 'debug', 'LOG_FORMAT' => 'json',
                'GIT_CONFIG_GLOBAL' => File::NULL, 'GIT_CONFIG_NOSYSTEM' => '1' }
        begin
          status = Maintenance.run([tools.node, tools.renovate], cwd: copy, env: env, log: log, timeout: timeout)
          raise Failure, "Renovate extraction failed (#{status.exitstatus}); no clean result" unless status.success?

          result = parse(log)
          result['enforced_execution_config'] = config.merge('baseDir' => '<owned>/base', 'cacheDir' => '<owned>/cache')
          result['enforced_execution_config_sha256'] = Maintenance.digest(result['enforced_execution_config'])
          presets_file = File.join(owned, 'presets.json')
          installation = File.dirname(File.dirname(tools.renovate))
          status = Maintenance.run([tools.node, File.join(copy, 'scripts/maintenance/resolve_presets.mjs'), installation,
                                    File.join(copy, 'renovate.json'), presets_file], cwd: copy, env: env, log: File.join(owned, 'presets.log'), timeout: timeout)
          raise Failure, 'Pinned bundled preset resolution failed' unless status.success? && File.file?(presets_file)

          resolved = JSON.parse(File.read(presets_file))
          raise Failure, 'Malformed resolved preset configuration' unless resolved['config'].is_a?(Hash)

          result['resolved_repository_config'] = resolved['config']
          result['resolved_repository_config_sha256'] = Maintenance.digest(resolved['config'])
          result['resolved_presets'] = resolved['visitedPresets']
        ensure
          source.verify_copy!(copy)
          source.verify!
        end
      end
      result
    end
  end
end
