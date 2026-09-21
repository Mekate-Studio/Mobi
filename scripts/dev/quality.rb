# frozen_string_literal: true

# Shared static inputs and commit guard. Uses Ruby's standard library only.
require 'digest'
require 'json'
require 'open3'
require 'yaml'
require_relative '../quality_tools'

module Quality
  class Failure < StandardError; end

  def self.git(*args)
    output, error, status = Open3.capture3({ 'GIT_OPTIONAL_LOCKS' => '0' }, 'git', *args)
    raise Failure, "git #{args.first} failed: #{error.strip}" unless status.success?

    output.force_encoding(Encoding::UTF_8)
    raise Failure, 'Unsupported non-UTF-8 Git filename/output' unless output.valid_encoding?

    output
  rescue SystemCallError => error
    raise Failure, "Cannot execute Git from PATH: #{error.message}. Select a Git executable compatible with this Ruby runtime; see docs/reference/local-development.md"
  end

  def self.safe_path!(path)
    resolved = File.realpath(path)
    root = Dir.pwd
    unless resolved.start_with?(root + '/')
      raise Failure, "Path escapes repository: #{path.inspect}"
    end
    resolved
  rescue Errno::ENOENT, Errno::ELOOP
    raise Failure, "Missing or unresolved path: #{path.inspect}"
  end

  def self.source_path!(path)
    safe_path!(path)
    parts = path.split('/')
    if parts.each_index.any? { |index| File.symlink?(parts.take(index + 1).join('/')) }
      raise Failure, "Unsupported source symlink: #{path.inspect}"
    end
  end

  class Inventory
    attr_reader :groups, :modules, :excluded

    def initialize
      @groups = { 'kotlin' => [], 'detekt' => [], 'swift' => [], 'shell' => [] }
      @excluded = []
      @modules = read_modules
      tracked = Quality.git('ls-files', '--cached', '-z').split("\0")
      fresh = Quality.git('ls-files', '--others', '--exclude-standard', '-z').split("\0")
      (tracked + fresh).uniq.sort.each do |path|
        # Ignored tracked files remain inputs, including files under output roots.
        if !tracked.include?(path) && generated?(path)
          @excluded << path
          next
        end
        # Git lists a directory symlink itself, not the sources below it.
        if File.symlink?(path) && File.directory?(path)
          raise Failure, "Unsupported directory symlink: #{path.inspect}"
        end
        kind = kind_of(path)
        next unless kind

        Quality.source_path!(path)
        raise Failure, "Unsupported non-file source: #{path.inspect}" unless File.file?(path)
        # ktlint treats arguments as globs; detekt uses comma-separated inputs.
        if %w[kotlin swift].include?(kind) && path.match?(/[,*?\[\]{}\\]/)
          raise Failure, "Unsupported #{kind} analyzer path syntax: #{path.inspect}"
        end
        @groups[kind] << path
        next unless File.extname(path) == '.kt'

        mod = @modules.find { |name| path.start_with?(name + '/') }
        source_root = mod && path.delete_prefix(mod + '/').split('/').first
        unless source_root && source_root.match?(/\A(?:src|test)(?:@[A-Za-z0-9][A-Za-z0-9_-]*)?\z/)
          raise Failure, "Unsupported Kotlin source layout: #{path.inspect}; declare its module and use src/test or src@platform/test@platform"
        end
        @groups['detekt'] << path
      end
    end

    def manifest
      {
        'schema' => 1, 'modules' => @modules, 'inputs' => @groups,
        'sha256' => @groups.values.flatten.uniq.to_h { |path| [path, Digest::SHA256.file(path).hexdigest] },
        'excluded_generated' => @excluded
      }
    end

    private

    def yaml(path)
      Quality.source_path!(path)
      source = File.read(path)
      stream = Psych.parse_stream(source)
      raise Failure, "Expected a single YAML document in #{path}" unless stream.children.length == 1
      reject_duplicate_keys(stream, path)
      data = YAML.safe_load(source, permitted_classes: [], permitted_symbols: [], aliases: false)
      raise Failure, "Expected YAML mapping: #{path.inspect}" unless data.is_a?(Hash)

      data
    rescue Psych::Exception => error
      raise Failure, "Unsupported YAML in #{path.inspect}: #{error.message}"
    end

    def reject_duplicate_keys(node, path)
      if node.is_a?(Psych::Nodes::Mapping)
        keys = node.children.each_slice(2).map do |key, _value|
          raise Failure, "Unsupported complex YAML key in #{path}" unless key.is_a?(Psych::Nodes::Scalar)

          key.value
        end
        raise Failure, "Duplicate YAML keys in #{path}" unless keys.uniq == keys
      end
      Array(node.children).each { |child| reject_duplicate_keys(child, path) }
    end

    def read_modules
      project = yaml('project.yaml')
      unless project.keys == ['modules'] && project['modules'].is_a?(Array) && !project['modules'].empty?
        raise Failure, 'Unsupported project.yaml layout; expected only an explicit nonempty modules list'
      end
      names = project['modules']
      names.each do |name|
        unless name.is_a?(String) && name.match?(/\A[A-Za-z0-9_-]+(?:\/[A-Za-z0-9_-]+)*\z/)
          raise Failure, "Unsupported module path/template: #{name.inspect}"
        end
        config = yaml("#{name}/module.yaml")
        config.each_key do |key|
          unless key.is_a?(String) && key.match?(/\A(?:product|dependencies|test-dependencies|settings|test-settings)(?:@[A-Za-z0-9_-]+)?\z/)
            raise Failure, "Unsupported module layout/configuration #{key.inspect} in #{name}/module.yaml"
          end
        end
        reject_layout_keys(config, "#{name}/module.yaml")
      end
      if names.uniq.length != names.length || names.any? { |a| names.any? { |b| a != b && a.start_with?(b + '/') } }
        raise Failure, 'Unsupported duplicate or overlapping module paths'
      end
      names.sort
    end

    def reject_layout_keys(value, path)
      case value
      when Hash
        value.each do |key, child|
          if key.to_s.match?(/\A(?:apply|templates?|layout|sources?|source[-_]?roots?|source[-_]?sets?)\z/i)
            raise Failure, "Unsupported source configuration #{key.inspect} in #{path}"
          end
          reject_layout_keys(child, path)
        end
      when Array
        value.each { |child| reject_layout_keys(child, path) }
      end
    end

    def generated?(path)
      roots = ['build', '.gradle', '.kotlin-cache', '.kotlin-user-home',
               '.gradle-user-home', '.amper', '.amper-cache', '.amper-user-home',
               'gradle-bridge/.gradle', 'gradle-bridge/build', 'gradle-bridge/shared-kit/build',
               'ios-app/Dependencies/.build'] + @modules.map { |name| "#{name}/build" }
      roots.any? { |root| path.start_with?(root + '/') }
    end

    def kind_of(path)
      return 'kotlin' if %w[.kt .kts].include?(File.extname(path))
      return 'swift' if File.extname(path) == '.swift'
      return 'shell' if path.start_with?('scripts/') && path.end_with?('.sh')
      return 'shell' if path.start_with?('.githooks/')

      nil
    end
  end

  class CommitGuard
    def snapshot
      flags = Quality.git('ls-files', '-v', '-z').split("\0")
      unsafe = flags.reject { |entry| entry.start_with?('H ') }
      raise Failure, "Unsupported index flags/unmerged state: #{unsafe.map(&:inspect).join(', ')}" unless unsafe.empty?

      diff_args = ['diff', '--cached', '--raw', '-z', '--no-renames', '--no-ext-diff', '--no-textconv']
      visible = Quality.git(*diff_args, '--ita-visible-in-index')
      invisible = Quality.git(*diff_args, '--ita-invisible-in-index')
      # Compare records, not just names: a recreated HEAD path can appear in both.
      raise Failure, 'Intent-to-add entries must be fully staged; inspect git status and git add the intended files' unless visible == invisible

      fresh = Quality.git('ls-files', '--others', '--exclude-standard', '-z').split("\0")
      raise Failure, "Nonignored untracked files must be staged or explicitly ignored: #{fresh.map(&:inspect).join(', ')}" unless fresh.empty?

      format = Quality.git('rev-parse', '--show-object-format').strip
      digest = { 'sha1' => Digest::SHA1, 'sha256' => Digest::SHA256 }.fetch(format) do
        raise Failure, "Unsupported Git object format: #{format}"
      end
      entries = Quality.git('ls-files', '--stage', '-z')
      entries.split("\0").each do |entry|
        metadata, path = entry.split("\t", 2)
        mode, oid, stage = metadata.split(' ')
        raise Failure, "Unmerged index entry: #{path.inspect}" unless stage == '0'
        unless %w[100644 100755 120000].include?(mode)
          raise Failure, "Unsupported index mode #{mode}: #{path.inspect}"
        end
        Quality.safe_path!(path)
        stat = File.lstat(path)
        if stat.symlink?
          actual_mode = '120000'
          bytes = File.readlink(path).b
        elsif stat.file?
          actual_mode = (stat.mode & 0o111).zero? ? '100644' : '100755'
          bytes = File.binread(path)
        else
          raise Failure, "Unsupported checkout file: #{path.inspect}"
        end
        actual_oid = digest.hexdigest("blob #{bytes.bytesize}\0".b + bytes)
        unless actual_mode == mode && actual_oid == oid
          raise Failure, "Index/checkout mismatch: #{path.inspect}; stage the full intended content/mode, then rerun (use just lint for unstaged work)"
        end
      end
      Digest::SHA256.hexdigest(entries + flags.join("\0"))
    end
  end

  class Runner
    def initialize(mode)
      @mode = mode
      @timings = {}
      @versions = {}
    end

    def run(manifest_only: false)
      started = clock
      guard = CommitGuard.new if @mode == 'commit'
      initial = guard.snapshot if guard
      inventory = Inventory.new
      manifest = inventory.manifest
      if manifest_only
        puts JSON.pretty_generate(manifest)
        return
      end
      require_tools!(inventory)
      puts "[quality] runtime=#{JSON.generate('ruby' => RUBY_VERSION, 'platform' => RUBY_PLATFORM, 'git' => Quality.git('--version').strip)}"
      puts "[quality] mode=#{@mode} inputs=#{inventory.groups.transform_values(&:length).to_json}"
      puts "[quality] index_sha256=#{initial}" if guard
      puts "[quality] manifest=#{JSON.generate(manifest)}"
      puts "[quality] versions=#{@versions.to_json}"
      puts "[quality] lock_sha256=#{@toolchain.lock_sha}"
      begin
        analyze(inventory.groups)
      ensure
        begin
          if guard
            final = guard.snapshot
            raise Failure, 'Index changed during analysis; rerun the commit check' unless initial == final
          end
        ensure
          puts "[quality] timing=#{JSON.generate(@timings.merge('total_seconds' => (clock - started).round(3)))}"
        end
      end
    end

    private

    def require_tools!(inventory)
      @toolchain = PinnedQuality::Toolchain.new(Dir.pwd)
      expected = @toolchain.lock.fetch('ruby').fetch('version')
      raise Failure, "Quality Ruby version mismatch: expected #{expected}, got #{RUBY_VERSION}; use the repository shell entry point" unless RUBY_VERSION == expected

      @versions = @toolchain.verify!(inventory.groups.values.flatten.uniq)
    end

    def clock
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def invoke(tool, args, env = {})
      start = clock
      success = system(PinnedQuality::Toolchain::CLEAN_ENV.merge(env), *@toolchain.command(tool), *args)
      @timings[tool] = (clock - start).round(3)
      raise Failure, "#{tool} failed; fix the reported issues and rerun" unless success
    end

    def analyze(inputs)
      paths = inputs.transform_values { |files| files.map { |file| "./#{file}" } }
      unless paths['kotlin'].empty?
        args = @mode == 'format' ? ['--format'] : []
        invoke('ktlint', args + ['--'] + paths['kotlin'])
      end
      if @mode != 'format' && !paths['detekt'].empty?
        invoke('detekt', ['--build-upon-default-config', '--config', 'detekt.yml', '--input', paths['detekt'].join(',')])
      end
      unless paths['swift'].empty?
        args = ['--cache', 'ignore', '--config', '.swiftformat']
        args << '--lint' unless @mode == 'format'
        invoke('swiftformat', args + paths['swift'])
        if @mode != 'format'
          env = { 'SCRIPT_INPUT_FILE_COUNT' => paths['swift'].length.to_s }
          paths['swift'].each_with_index { |path, index| env["SCRIPT_INPUT_FILE_#{index}"] = path }
          invoke('swiftlint', ['lint', '--strict', '--no-cache', '--config', '.swiftlint.yml', '--use-script-input-files'], env)
        end
      end
      if @mode != 'format' && !paths['shell'].empty?
        invoke('shellcheck', ['--norc', '--external-sources', '--source-path=SCRIPTDIR', '--'] + paths['shell'])
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    mode = ARGV.shift
    unless %w[static commit format].include?(mode) && (ARGV.empty? || ARGV == ['--manifest'])
      raise Quality::Failure, 'Usage: quality.rb <static|commit|format> [--manifest]'
    end
    Dir.chdir(File.expand_path('../..', __dir__))
    Quality::Runner.new(mode).run(manifest_only: ARGV == ['--manifest'])
  rescue Quality::Failure, PinnedQuality::Failure, SystemCallError => error
    warn "[quality] FAIL: #{error.message}"
    exit 1
  end
end
