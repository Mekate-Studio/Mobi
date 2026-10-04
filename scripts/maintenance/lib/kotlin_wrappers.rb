# frozen_string_literal: true

require_relative 'run_store'

module Maintenance
  class KotlinWrappers
    attr_reader :pins, :path, :slot

    def initialize(root)
      @root = File.realpath(root)
      @path = File.join(@root, 'maintenance-kotlin-toolchains.json')
      @pins = JSON.parse(File.read(@path))
      raise Failure, 'Unsupported Kotlin Toolchain pins' unless @pins['schema'] == 1 && @pins['automatic_adoption'] == false && @pins['candidates'].is_a?(Array)
      @identity = Maintenance.digest(@pins)
      @store = File.join(@root, '.maintenance', 'kotlin-wrappers')
      @slot = File.join(@store, @identity)
      @pins.fetch('versions').each do |version, pin|
        raise Failure, 'Invalid reviewed Toolchain version' unless version.match?(/\A\d+\.\d+\.\d+\z/) && pin.fetch('distribution_sha256').match?(/\A[0-9a-f]{64}\z/)
        raise Failure, 'Incomplete wrapper pins' unless pin.fetch('wrappers').keys.sort == %w[kotlin kotlin.bat]
        pin['wrappers'].each do |name, item|
          extension = name == 'kotlin' ? '' : '.bat'
          expected = "https://packages.jetbrains.team/maven/p/amper/amper/org/jetbrains/kotlin/kotlin-cli/#{version}/kotlin-cli-#{version}-wrapper#{extension}"
          raise Failure, 'Invalid reviewed wrapper source' unless item['url'] == expected && item['sha256'].match?(/\A[0-9a-f]{64}\z/)
        end
      end
    end

    def selection(version, now: Time.now.utc, experimental: false)
      raise Failure, 'Experimental mode must be explicit boolean' unless [true, false].include?(experimental)
      raise Failure, 'Unreviewed Kotlin Toolchain candidate' unless @pins['candidates'].include?(version)
      policy = JSON.parse(File.read(File.join(@root, 'maintenance-policy.json')))
      published = Time.iso8601(@pins.fetch('versions').fetch(version).fetch('published_at'))
      raise Failure, 'Candidate publication is in the future' if published > now
      eligible = published + policy.fetch('minimum_release_age_days') * 86_400
      blocked = now < eligible
      raise Failure, 'Candidate has not reached the release-age threshold' if blocked && !experimental
      { 'version' => version, 'mode' => experimental ? 'experimental' : 'normal',
        'age_state' => blocked ? 'age_blocked' : 'age_eligible', 'assessed_at' => now.iso8601,
        'eligible_at' => eligible.iso8601, 'adoption_authorized' => false }
    end

    def candidate!(version, now: Time.now.utc, experimental: false)
      selection(version, now: now, experimental: experimental)
      version
    end

    def wrapper(version, name)
      raise Failure, 'Unknown wrapper' unless @pins.fetch('versions').key?(version) && %w[kotlin kotlin.bat].include?(name)
      File.join(@slot, version, name)
    end

    def safe_store!
      paths = [File.join(@root, '.maintenance'), @store, @slot]
      raise Failure, 'Symlinked wrapper store' if paths.any? { |p| File.symlink?(p) }
      @pins['versions'].each_key { |version| raise Failure, 'Symlinked wrapper version directory' if File.symlink?(File.join(@slot, version)) }
    end

    def verify!
      safe_store!
      marker = File.join(@slot, '.owner.json')
      raise Failure, 'Kotlin wrappers missing; run prepare-kotlin explicitly' unless File.file?(marker)
      raise Failure, 'Unowned wrapper directory' unless !File.symlink?(marker) && JSON.parse(File.read(marker)) == { 'identity' => @identity }
      @pins['versions'].each do |version, pin|
        pin['wrappers'].each do |name, item|
          file = wrapper(version, name)
          raise Failure, 'Prepared wrapper bytes changed; inspect the retained installation' unless File.file?(file) && !File.symlink?(file) && Maintenance.file_sha(file) == item['sha256']
        end
        content = File.read(wrapper(version, 'kotlin'), encoding: 'UTF-8')
        unless content.match?(/^kotlin_cli_version=#{Regexp.escape(version)}$/) && content.match?(/^kotlin_cli_sha256=#{pin['distribution_sha256']}$/)
          raise Failure, 'Consumer wrapper distribution identity disagrees with pin'
        end
      end
      @identity
    end

    def prepare!
      safe_store!
      FileUtils.mkdir_p(@store)
      lock_path = File.join(@store, 'prepare.lock')
      raise Failure, 'Symlinked wrapper preparation lease' if File.symlink?(lock_path)
      File.open(lock_path, File::RDWR | File::CREAT, 0o600) do |lease|
        raise Failure, 'Wrapper preparation is active' unless lease.flock(File::LOCK_EX | File::LOCK_NB)
        return verify! if File.exist?(@slot)
        Dir.mktmpdir('preparing-', @store) do |temp|
          RunStore.atomic(File.join(temp, '.owner.json'), { 'identity' => @identity })
          @pins['versions'].each do |version, pin|
            Dir.mkdir(File.join(temp, version))
            pin['wrappers'].each do |name, item|
              file = File.join(temp, version, name)
              env = { 'PATH' => '/usr/bin:/bin', 'HOME' => temp }
              status = Maintenance.run(['/usr/bin/curl', '-q', '--silent', '--show-error', '--fail', '--location', '--proto', '=https', '--proto-redir', '=https', '--max-time', '60', '--output', file, item['url']],
                                       cwd: temp, env: env, log: File.join(temp, 'download.log'), timeout: 65)
              raise Failure, 'Wrapper download failed' unless status.success?
              raise Failure, 'Wrapper checksum mismatch' unless Maintenance.file_sha(file) == item['sha256']
            end
          end
          File.unlink(File.join(temp, 'download.log'))
          FileUtils.cp_r(temp, @slot)
        end
        verify!
      end
    end
  end
end
