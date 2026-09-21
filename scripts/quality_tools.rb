# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'find'
require 'json'
require 'open3'
require 'rbconfig'
require 'tmpdir'
require 'timeout'

module PinnedQuality
  class Failure < StandardError; end

  class Toolchain
    TOOLS = %w[ktlint detekt swiftformat swiftlint shellcheck].freeze
    CONFIG_NAMES = %w[.editorconfig .swiftformat .swiftlint.yml .swift-version .shellcheckrc].freeze
    CLEAN_ENV = %w[RUBYOPT RUBYLIB GEM_HOME GEM_PATH JAVA_TOOL_OPTIONS JDK_JAVA_OPTIONS _JAVA_OPTIONS CLASSPATH].to_h { |name| [name, nil] }.freeze
    attr_reader :root, :lock, :platform, :slot, :install_id, :lock_sha

    def initialize(root)
      @root = File.realpath(root)
      raw = File.binread(File.join(@root, 'quality-tools.json'))
      @lock = JSON.parse(raw)
      raise Failure, 'Unsupported quality lock schema/recipe' unless @lock['schema'] == 1 && @lock['recipe'] == 2

      cpu = RbConfig::CONFIG.fetch('host_cpu').sub('aarch64', 'arm64')
      @platform = "darwin-#{cpu}"
      unless RUBY_PLATFORM.include?('darwin') && @lock.fetch('platforms').key?(@platform)
        raise Failure, "Unsupported quality platform: #{RUBY_PLATFORM}"
      end
      @selected = @lock.fetch('platforms').fetch(@platform)
      raise Failure, 'Quality lock must declare all five analyzers' unless @selected.fetch('tools').keys.sort == TOOLS.sort

      @lock_sha = Digest::SHA256.hexdigest(raw)
      @install_id = Digest::SHA256.hexdigest(JSON.generate([@lock['recipe'], @lock.fetch('ruby'), @selected]))
      @store = File.join(@root, '.quality')
      @slot = File.join(@store, @platform, @install_id)
      validate_paths!
    rescue KeyError, JSON::ParserError => error
      raise Failure, "Invalid quality-tools.json: #{error.message}"
    end

    def command(name)
      item = name == 'ruby' ? @lock.fetch('ruby') : name == 'java' ? @selected.fetch('java') : @selected.fetch('tools').fetch(name)
      file = File.join(@slot, item.fetch('entry'))
      item['kind'] == 'jar' ? command('java') + ['-jar', file] : [file]
    end

    def check_rules!(sources = [])
      @lock.fetch('rules').each do |path, expected|
        file = File.join(@root, path)
        unless File.file?(file) && !File.symlink?(file) && Digest::SHA256.file(file).hexdigest == expected
          raise Failure, "Rule profile mismatch: #{path}; review the rule change and update quality-tools.json explicitly"
        end
      end
      sources.each do |source|
        parent = File.dirname(File.join(@root, source))
        loop do
          CONFIG_NAMES.each do |name|
            file = File.join(parent, name)
            relative = file.delete_prefix(@root + '/')
            if File.exist?(file) && !@lock.fetch('rules').key?(relative)
              raise Failure, "Unpinned analyzer configuration: #{relative}"
            end
          end
          break if parent == @root

          parent = File.dirname(parent)
        end
      end
    end

    def tree(path = @slot)
      files = {}
      Find.find(path) do |file|
        next if file == path
        relative = file.delete_prefix(path + '/')
        next if relative == 'receipt.json'
        if File.symlink?(file)
          resolved = File.realpath(file)
          raise Failure, "Escaping installed symlink: #{relative}" unless resolved.start_with?(File.realpath(path) + '/')

          files[relative] = { 'link' => File.readlink(file) }
        elsif File.file?(file)
          files[relative] = { 'sha256' => Digest::SHA256.file(file).hexdigest, 'executable' => File.executable?(file) }
        elsif !File.directory?(file)
          raise Failure, "Unsupported installed file: #{relative}"
        end
      end
      files.sort.to_h
    end

    def verify_files!
      validate_paths!
      receipt_path = File.join(@slot, 'receipt.json')
      unless File.file?(receipt_path) && !File.symlink?(receipt_path)
        raise Failure, 'Missing complete quality installation; run ./scripts/ci/install_quality_tools.sh explicitly'
      end
      receipt = JSON.parse(File.read(receipt_path))
      unless receipt['install_id'] == @install_id && receipt['files'] == tree
        raise Failure, 'Quality installation checksum/identity mismatch; run ./scripts/ci/install_quality_tools.sh --repair explicitly'
      end
      (TOOLS + %w[ruby java]).each do |name|
        entry = command(name).last
        # JARs are data passed to the verified Java executable.
        jar = @selected.fetch('tools').fetch(name, {})['kind'] == 'jar'
        unless File.file?(entry) && (jar || File.executable?(entry))
          raise Failure, "Missing quality binary: #{name}; rerun explicit setup with --repair"
        end
      end
      receipt
    rescue JSON::ParserError => error
      raise Failure, "Invalid installation receipt: #{error.message}; use explicit --repair"
    end

    def versions!
      versions = {}
      (['ruby', 'java'] + TOOLS).each do |name|
        args = name == 'ruby' ? ['-e', 'print RUBY_VERSION'] : name == 'java' ? ['-XshowSettings:properties', '-version'] : ['--version']
        output, status = Open3.capture2e(CLEAN_ENV, *command(name), *args)
        raise Failure, "Cannot execute pinned #{name}: #{output.strip}" unless status.success?

        actual = case name
                 when 'ktlint' then output[/\bktlint version (\S+)/, 1]
                 when 'shellcheck' then output[/^version: (\S+)/, 1]
                 when 'java' then output[/java.runtime.version = (\S+)/, 1]
                 else output.strip
                 end
        expected = name == 'ruby' ? @lock.fetch('ruby').fetch('version') : name == 'java' ? @selected.fetch('java').fetch('version') : @selected.fetch('tools').fetch(name).fetch('version')
        raise Failure, "Pinned #{name} version mismatch: expected #{expected}, got #{actual.inspect}; use explicit --repair" unless actual == expected
        if name == 'java' && output[/java.vendor = (.+)/, 1]&.strip != @selected.fetch('java').fetch('vendor')
          raise Failure, 'Pinned Java vendor mismatch'
        end
        versions[name] = actual
      end
      versions
    end

    def verify!(sources = [])
      check_rules!(sources)
      verify_files!
      versions!
    end

    def install!(repair: false)
      validate_paths!
      FileUtils.mkdir_p(@store)
      File.open(File.join(@store, 'install.lock'), File::RDWR | File::CREAT, 0o600) do |guard|
        raise Failure, 'Another quality installer is running; wait for it to finish' unless guard.flock(File::LOCK_EX | File::LOCK_NB)

        check_rules!
        if Dir.exist?(@slot)
          if repair
            unless File.file?(File.join(@slot, '.mobi-quality-owned')) && File.read(File.join(@slot, '.mobi-quality-owned')) == @install_id
              raise Failure, 'Refusing to repair an unowned quality directory'
            end
            FileUtils.rm_rf(@slot)
          else
            verify!
            puts '[quality-setup] Verified existing installation; no network used'
            return
          end
        end
        build_install!
      end
    end

    private

    def validate_paths!
      [@store, File.dirname(@slot), @slot].each do |path|
        raise Failure, "Symlinked quality store is unsupported: #{path}" if File.symlink?(path)
      end
      (@selected.fetch('tools').values + [@selected.fetch('java'), @lock.fetch('ruby')]).each do |item|
        relative!(item.fetch('entry'))
        relative!(item['member']) if item['member']
      end
      @lock.fetch('rules').each_key { |path| relative!(path) }
      relative!(@lock.fetch('ruby').fetch('source').fetch('root'))
      relative!(@lock.fetch('ruby').fetch('libyaml').fetch('root'))
    end

    def relative!(path)
      unless path.is_a?(String) && !path.empty? && !path.start_with?('/') && !path.split('/').include?('..') && !path.include?("\0")
        raise Failure, "Unsafe quality path: #{path.inspect}"
      end
    end

    def run!(*args, directory: @root, log: File::NULL)
      pid = Process.spawn(CLEAN_ENV.merge('PATH' => '/usr/bin:/bin:/usr/sbin:/sbin'), *args, chdir: directory, out: [log, 'a'], err: [:child, :out], pgroup: true)
      status = Timeout.timeout(1800) { Process.wait2(pid).last }
      raise Failure, "Setup command failed: #{args.first}; see #{log}" unless status.success?
    rescue Interrupt, Timeout::Error
      Process.kill('TERM', -pid) rescue Errno::ESRCH
      begin
        Timeout.timeout(5) { Process.wait(pid) }
      rescue Timeout::Error
        Process.kill('KILL', -pid) rescue Errno::ESRCH
        Process.wait(pid) rescue Errno::ECHILD
      rescue Errno::ECHILD
        nil
      end
      raise Failure, "Setup interrupted or timed out: #{args.first}; no completed installation was published"
    end

    def download(item, directory)
      url, sha = item.fetch('url'), item.fetch('sha256')
      raise Failure, 'Artifact must have an HTTPS URL and SHA-256' unless url.start_with?('https://') && sha.match?(/\A[0-9a-f]{64}\z/)

      target = File.join(directory, sha)
      run!('/usr/bin/curl', '-q', '--fail', '--location', '--silent', '--show-error', '--proto', '=https', '--proto-redir', '=https',
           '--connect-timeout', '30', '--max-time', '300', '--retry', '2', '--output', target, url, log: @build_log)
      raise Failure, "Downloaded checksum mismatch: #{url}" unless Digest::SHA256.file(target).hexdigest == sha

      target
    end

    def extract(archive, directory)
      FileUtils.mkdir_p(directory)
      listing, status = Open3.capture2e('/usr/bin/tar', '-tf', archive)
      raise Failure, 'Cannot list verified archive' unless status.success?
      listing.lines.each { |line| relative!(line.chomp) }
      run!('/usr/bin/tar', '-xf', archive, '-C', directory, '--no-same-owner', log: @build_log)
    end

    def build_install!
      FileUtils.mkdir_p(File.dirname(@slot))
      @build_log = File.join(@store, "setup-#{@platform}.log")
      File.write(@build_log, "Quality setup #{@install_id}\n")
      published = false
      Dir.mktmpdir('build-', @store) do |scratch|
        staged = File.join(scratch, 'install')
        FileUtils.mkdir_p(staged)
        File.write(File.join(staged, '.mobi-quality-owned'), @install_id)
        begin
          puts '[quality-setup] Downloading and verifying locked artifacts'
          java = download(@selected.fetch('java'), scratch)
          extract(java, File.join(staged, 'java'))
          @selected.fetch('tools').each do |name, item|
            artifact = download(item, scratch)
            destination = File.join(staged, item.fetch('entry'))
            FileUtils.mkdir_p(File.dirname(destination))
            case item.fetch('kind')
            when 'jar'
              FileUtils.cp(artifact, destination)
            when 'zip', 'tar'
              args = item['kind'] == 'zip' ? ['/usr/bin/unzip', '-p', artifact, item.fetch('member')] : ['/usr/bin/tar', '-xOf', artifact, item.fetch('member')]
              output, status = Open3.capture2e(*args)
              raise Failure, "Cannot extract #{name}" unless status.success?
              File.binwrite(destination, output)
            else
              raise Failure, "Unsupported artifact kind: #{item['kind']}"
            end
            File.chmod(0o755, destination)
          end
          build_ruby(scratch, staged)
          tree(staged) # Reject escaping links before publishing the slot.
          File.rename(staged, @slot)
          published = true
          versions = versions!
          receipt = { 'schema' => 1, 'install_id' => @install_id, 'platform' => @platform, 'versions' => versions, 'files' => tree }
          File.write(File.join(@slot, 'receipt.json'), JSON.pretty_generate(receipt) + "\n")
          verify!
          puts "[quality-setup] Complete #{JSON.generate(versions)}"
        rescue Exception # Cleanup also covers interruption; re-raise without hiding the cause.
          FileUtils.rm_rf(@slot) if published
          raise
        end
      end
    end

    def build_ruby(scratch, staged)
      ruby = @lock.fetch('ruby')
      source = download(ruby.fetch('source'), scratch)
      yaml = download(ruby.fetch('libyaml'), scratch)
      sources = File.join(scratch, 'sources')
      extract(source, sources)
      extract(yaml, sources)
      yaml_dir = File.join(sources, ruby.fetch('libyaml').fetch('root'))
      yaml_prefix = File.join(scratch, 'yaml')
      puts '[quality-setup] Building pinned libyaml and Ruby; details are in the setup log'
      run!('./configure', "--prefix=#{yaml_prefix}", '--disable-shared', directory: yaml_dir, log: @build_log)
      run!('/usr/bin/make', '-j4', directory: yaml_dir, log: @build_log)
      run!('/usr/bin/make', 'install', directory: yaml_dir, log: @build_log)
      source_dir = File.join(sources, ruby.fetch('source').fetch('root'))
      run!('./configure', '--prefix=/', '--enable-load-relative', '--disable-install-doc', '--disable-shared', '--disable-yjit', '--disable-zjit',
           '--disable-dtrace', '--without-gmp', '--with-out-ext=openssl,readline', "--with-libyaml-dir=#{yaml_prefix}", directory: source_dir, log: @build_log)
      run!('/usr/bin/make', '-j4', directory: source_dir, log: @build_log)
      dest = File.join(scratch, 'dest')
      run!('/usr/bin/make', 'install', "DESTDIR=#{dest}", directory: source_dir, log: @build_log)
      raise Failure, 'Ruby installation did not produce bin/ruby' unless File.file?(File.join(dest, 'bin/ruby'))

      FileUtils.mv(dest, File.join(staged, 'ruby'))
    end
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    root = File.expand_path('..', __dir__)
    toolchain = PinnedQuality::Toolchain.new(root)
    case ARGV.shift
    when 'install'
      raise PinnedQuality::Failure, 'Usage: install [--repair]' unless ARGV.empty? || ARGV == ['--repair']
      trap('TERM') { raise Interrupt }
      toolchain.install!(repair: ARGV == ['--repair'])
    when 'run'
      if ARGV.length == 2 && %w[static commit format].include?(ARGV.first) && ARGV.last == '--manifest'
        exec(PinnedQuality::Toolchain::CLEAN_ENV, RbConfig.ruby, File.join(root, 'scripts/dev/quality.rb'), *ARGV)
      end
      toolchain.verify_files!
      exec(PinnedQuality::Toolchain::CLEAN_ENV, *toolchain.command('ruby'), File.join(root, 'scripts/dev/quality.rb'), *ARGV)
    when 'verify'
      puts JSON.pretty_generate('lock_sha256' => toolchain.lock_sha, 'platform' => toolchain.platform, 'versions' => toolchain.verify!)
    else
      raise PinnedQuality::Failure, 'Usage: quality_tools.rb <install [--repair]|verify|run <static|commit|format>>'
    end
  rescue PinnedQuality::Failure, SystemCallError, KeyError, Interrupt => error
    warn "[quality-tools] FAIL: #{error.message}"
    exit 1
  end
end
