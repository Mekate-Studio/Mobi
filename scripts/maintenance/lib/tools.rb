# frozen_string_literal: true

require_relative 'core'
require 'rubygems/package'
require 'zlib'

module Maintenance
  class Tools
    attr_reader :root, :pins, :slot, :identity

    def initialize(root, platform: nil)
      @root = File.realpath(root)
      @pins = JSON.parse(File.read(File.join(root, 'maintenance-tools.json')))
      raise Failure, 'Unsupported maintenance tool schema/recipe' unless @pins['schema'] == 1 && @pins['recipe'] == 1
      @platform = platform || "#{RUBY_PLATFORM.include?('darwin') ? 'darwin' : 'linux'}-#{Open3.capture2('uname', '-m').first.match?(/arm64|aarch64/) ? 'arm64' : 'x64'}"
      raise Failure, 'Unsupported maintenance-tool host' unless RUBY_PLATFORM.match?(/darwin|linux/) && @pins.fetch('platforms').key?(@platform)

      @archive = @pins.fetch('platforms').fetch(@platform)
      %w[package package-lock].each do |name|
        key = name == 'package' ? 'package_sha256' : 'lock_sha256'
        raise Failure, "Maintenance #{name} identity changed; review the tool lock" unless Maintenance.file_sha(File.join(root, 'scripts/maintenance/tools', name + '.json')) == @pins.fetch(key)
      end
      lock = JSON.parse(File.read(File.join(root, 'scripts/maintenance/tools/package-lock.json')))
      raise Failure, 'Renovate lock differs from reviewed version' unless lock.fetch('packages').fetch('node_modules/renovate').fetch('version') == @pins.fetch('renovate_version')
      lock.fetch('packages').each do |path, item|
        next if path.empty?
        unless item.fetch('resolved', '').start_with?('https://registry.npmjs.org/') && item.fetch('integrity', '').match?(/\Asha(?:256|512)-[A-Za-z0-9+\/=]+\z/)
          raise Failure, "Unverified maintenance package: #{path}"
        end
      end
      @identity = Maintenance.digest([@pins, @platform])
      @store = File.join(@root, '.maintenance', 'tools')
      @slot = File.join(@store, @identity)
    end

    def node
      File.join(@slot, 'node', 'bin', 'node')
    end

    def renovate
      File.join(@slot, 'npm', 'node_modules', 'renovate', 'dist', 'renovate.js')
    end

    def tree
      Dir.glob(File.join(@slot, '**', '*'), File::FNM_DOTMATCH).sort.each_with_object({}) do |path, result|
        relative = path.delete_prefix(@slot + '/')
        next if %w[. ..].include?(File.basename(path)) || relative == 'receipt.json' || File.directory?(path) && !File.symlink?(path)
        if File.symlink?(path)
          raise Failure, 'Tool symlink escaped owned installation' unless File.realpath(path).start_with?(File.realpath(@slot) + '/')
          result[relative] = { 'link' => File.readlink(path) }
        elsif File.file?(path)
          result[relative] = { 'sha256' => Maintenance.file_sha(path), 'executable' => (File.stat(path).mode & 0o111) != 0 }
        else
          raise Failure, 'Unexpected tool installation entry'
        end
      end
    end

    def verify!
      raise Failure, 'Maintenance tools missing; run scripts/maintenance/install_tools.sh explicitly' unless File.file?(File.join(@slot, 'receipt.json'))
      raise Failure, 'Maintenance tool store must not be a symlink' if [File.join(@root, '.maintenance'), @store, @slot].any? { |p| File.symlink?(p) }

      receipt = JSON.parse(File.read(File.join(@slot, 'receipt.json')))
      marker = File.join(@slot, '.mobi-maintenance-owned')
      required = [node, renovate, File.join(@slot, 'npm/package-lock.json')]
      unless File.file?(marker) && !File.symlink?(marker) && File.read(marker) == @identity &&
             required.all? { |path| File.file?(path) && !File.symlink?(path) } && File.executable?(node) &&
             receipt['identity'] == @identity && receipt['files'].is_a?(Hash) && !receipt['files'].empty? && receipt['files'] == tree
        raise Failure, 'Maintenance tools changed; inspect then run install_tools.sh --repair'
      end
      @identity
    end

    def extract(archive, destination)
      expected = @archive.fetch('root')
      Zlib::GzipReader.open(archive) do |gzip|
        Gem::Package::TarReader.new(gzip) do |tar|
          tar.each do |entry|
            parts = entry.full_name.sub(%r{/\z}, '').split('/')
            raise Failure, 'Invalid Node archive path' unless parts.first == expected && !parts.include?('..') && !entry.full_name.start_with?('/')
            relative = parts.drop(1).join('/')
            next if relative.empty?
            target = File.join(destination, relative)
            FileUtils.mkdir_p(File.dirname(target))
            parent = File.realpath(File.dirname(target))
            raise Failure, 'Node archive escaped installation' unless parent == File.realpath(destination) || parent.start_with?(File.realpath(destination) + '/')
            if entry.directory?
              FileUtils.mkdir_p(target)
            elsif entry.file?
              raise Failure, 'Duplicate Node archive symlink' if File.symlink?(target)
              File.open(target, 'wb') { |file| IO.copy_stream(entry, file) }
              File.chmod(0o644 | (entry.header.mode & 0o111), target)
            elsif entry.header.typeflag == '2'
              link = entry.header.linkname
              resolved = File.expand_path(link, File.dirname(target))
              raise Failure, 'Node archive symlink escaped installation' unless !Pathname.new(link).absolute? && resolved.start_with?(File.expand_path(destination) + '/')
              File.symlink(link, target)
            else
              raise Failure, 'Unsupported Node archive entry'
            end
          end
        end
      end
    end

    def install!(repair: false)
      raise Failure, 'Maintenance store must not be a symlink' if [File.join(@root, '.maintenance'), @store].any? { |p| File.symlink?(p) }
      FileUtils.mkdir_p(@store)
      raise Failure, 'Install lock must not be a symlink' if File.symlink?(File.join(@store, 'install.lock'))
      File.open(File.join(@store, 'install.lock'), File::RDWR | File::CREAT, 0o600) do |lock|
        raise Failure, 'Another maintenance install is active' unless lock.flock(File::LOCK_EX | File::LOCK_NB)
        if File.exist?(@slot) || File.symlink?(@slot)
          return verify! unless repair
          marker = File.join(@slot, '.mobi-maintenance-owned')
          raise Failure, 'Refusing repair of unowned tool directory' unless !File.symlink?(@slot) && !File.symlink?(marker) && File.file?(marker) && File.read(marker) == @identity
          FileUtils.remove_entry_secure(@slot)
        end
        FileUtils.mkdir_p(@slot)
        File.write(File.join(@slot, '.mobi-maintenance-owned'), @identity)
        completed = false
        begin
          Dir.mktmpdir('mobi-maintenance-install-') do |work|
            %w[home cache].each { |p| FileUtils.mkdir_p(File.join(work, p)) }
            %w[user global].each { |p| File.write(File.join(work, p + '.conf'), '') }
            archive = File.join(work, 'node.tar.gz')
            env = { 'PATH' => '/usr/bin:/bin:/usr/sbin:/sbin', 'HOME' => File.join(work, 'home') }
            log = File.join(work, 'install.log')
            raise Failure, 'Invalid Node download source' unless @archive['url'].start_with?('https://nodejs.org/dist/') && @archive['sha256'].match?(/\A[0-9a-f]{64}\z/)
            status = Maintenance.run(['curl', '-q', '--fail', '--location', '--proto', '=https', '--proto-redir', '=https', '--max-time', '180', '--retry', '2', '--output', archive, @archive['url']], cwd: work, env: env, log: log)
            raise Failure, 'Node download failed' unless status.success?
            raise Failure, 'Node checksum mismatch' unless Maintenance.file_sha(archive) == @archive['sha256']
            FileUtils.mkdir_p(File.join(@slot, 'node'))
            extract(archive, File.join(@slot, 'node'))
            npm = File.join(@slot, 'npm')
            FileUtils.mkdir_p(npm)
            %w[package.json package-lock.json].each { |p| FileUtils.cp(File.join(@root, 'scripts/maintenance/tools', p), npm) }
            env.merge!('PATH' => File.dirname(node) + ':' + env['PATH'], 'npm_config_cache' => File.join(work, 'cache'),
                       'npm_config_userconfig' => File.join(work, 'user.conf'), 'npm_config_globalconfig' => File.join(work, 'global.conf'))
            cli = File.join(@slot, 'node/lib/node_modules/npm/bin/npm-cli.js')
            status = Maintenance.run([node, cli, 'ci', '--ignore-scripts', '--no-audit', '--no-fund'], cwd: npm, env: env, log: log, timeout: 600)
            raise Failure, 'Locked npm installation failed; rerun explicit setup' unless status.success?
            [[node, '--version', "v#{@pins['node_version']}"], [node, cli, '--version', @pins['npm_version']], [node, renovate, '--version', @pins['renovate_version']]].each do |check|
              expected = check.pop
              status = Maintenance.run(check, cwd: work, env: env, log: log)
              raise Failure, 'Installed maintenance tool version mismatch' unless status.success? && File.read(log).strip == expected
            end
          end
          raise Failure, 'Tool pins changed during installation; rerun setup' unless self.class.new(@root, platform: @platform).identity == @identity
          File.write(File.join(@slot, 'receipt.json'), JSON.pretty_generate('identity' => @identity, 'files' => tree) + "\n")
          verify!
          completed = true
        ensure
          FileUtils.remove_entry_secure(@slot) if !completed && Dir.exist?(@slot)
        end
      end
      @identity
    end
  end
end
