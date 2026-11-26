# frozen_string_literal: true

require_relative 'core'
require 'rbconfig'

module Maintenance
  # GitHub's compare response caps files and omits large patches. Fetch exact
  # public commit objects without checkout, hooks, global config or credentials.
  # The temporary object store is bounded and removed before native execution.
  module AssessmentGit
    MAX_STORAGE = 512 * 1024 * 1024
    MAX_PATCHES = 16 * 1024 * 1024
    MAX_FILES = 2000
    ASSET = /\.(?:png|jpe?g|gif|webp|ico|woff2?|zip|tgz|jar|klib|a|dylib|pdf)\z/i
    class TransportFailure < Failure
      attr_reader :diagnostic
      def initialize(message, diagnostic)
        @diagnostic = diagnostic
        super(message)
      end
    end
    module_function

    def command(repo, argv, deadline, input_path: nil)
      remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
      raise Failure, 'source_git_deadline' unless remaining.positive?
      log = File.join(repo, 'command.log')
      env = { 'PATH' => '/usr/bin:/bin', 'HOME' => repo, 'LC_ALL' => 'C', 'GIT_CONFIG_GLOBAL' => File::NULL,
        'GIT_CONFIG_NOSYSTEM' => '1', 'GIT_TERMINAL_PROMPT' => '0', 'GIT_ASKPASS' => '/usr/bin/false', 'GIT_LITERAL_PATHSPECS' => '1', 'GIT_NO_LAZY_FETCH' => '1' }
      # Bound each output/pack file as well as the aggregate object store.
      launcher = [File.realpath(RbConfig.ruby), '-e', 'Process.setrlimit(:FSIZE, 268435456); exec(*ARGV)', '/usr/bin/git']
      # One-shot stores have no background maintenance lifecycle. All Git work
      # must stay within this command's process group and deadline.
      status = Maintenance.run(launcher + ['-c', 'maintenance.auto=false', '-c', 'gc.auto=0'] + argv, cwd: repo, env: env, log: log, timeout: remaining, stderr_log: File.join(repo, 'command.stderr.log'), input_path: input_path)
      unless status.success?
        diagnostic = File.binread(File.join(repo, 'command.stderr.log'), 8192).force_encoding(Encoding::UTF_8).scrub
        raise TransportFailure.new('source_git_transport_or_command_failed', diagnostic)
      end
      raise Failure, 'source_git_output_limit' if File.size(log) > MAX_PATCHES
      objects = File.join(repo, '.git', 'objects')
      size = Dir.glob(File.join(objects, '**', '*')).sum do |path|
        raise Failure, 'symlinked_source_git_object' if File.symlink?(path)
        File.file?(path) ? File.size(path) : 0
      end
      raise Failure, 'source_git_storage_limit' if size > MAX_STORAGE
      File.binread(log)
    end

    def read_repository(repo, before, after, deadline:)
      raw = command(repo, ['diff', '--no-ext-diff', '--no-textconv', '--no-renames', '--raw', '--no-abbrev', '-z', before, after, '--'], deadline).split("\0")
      raise Failure, 'source_git_diff_record_mismatch' unless raw.size.even?
      raise Failure, 'source_git_file_limit' if raw.size / 2 > MAX_FILES
      # Fetch missing changed text blobs in one pack. Per-file lazy fetch would
      # multiply provider requests and makes large release intervals impractical.
      local = command(repo, ['cat-file', '--batch-all-objects', '--batch-check=%(objectname)'], deadline).lines.map(&:strip).to_h { |sha| [sha, true] }
      wanted = raw.each_slice(2).flat_map do |metadata, path|
        modes = metadata.split
        next [] if path.match?(ASSET) || modes.take(2).any? { |mode| mode.delete_prefix(':') == '160000' }
        modes[2, 2].reject { |sha| sha == '0' * 40 || local[sha] }
      end.uniq
      unless wanted.empty?
        raise Failure, 'source_git_object_identity_invalid' unless wanted.all? { |sha| sha.match?(/\A[0-9a-f]{40}\z/) }
        input = File.join(repo, 'wanted-objects')
        File.write(input, wanted.join("\n") + "\n")
        command(repo, ['fetch', '--quiet', '--no-tags', '--stdin', 'origin'], deadline, input_path: input)
      end
      bytes = 0
      raw.each_slice(2).map do |metadata, path|
        mode_before, mode_after, sha_before, sha_after, status = metadata.split
        raise Failure, 'source_git_path_unreadable' unless path.force_encoding(Encoding::UTF_8).valid_encoding? && !path.start_with?('/') && !(path.split('/') & %w[. ..]).any?
        binary = path.match?(ASSET) || [mode_before, mode_after].any? { |mode| mode.delete_prefix(':') == '160000' }
        patch = binary ? '' : command(repo, ['diff', '--no-ext-diff', '--no-textconv', '--no-renames', '--no-color', '--unified=3', before, after, '--', path], deadline)
        binary ||= patch.start_with?('Binary files ') || patch.include?("\nBinary files ")
        raise Failure, 'source_git_patch_encoding_unsupported' unless binary || patch.force_encoding(Encoding::UTF_8).valid_encoding?
        bytes += patch.bytesize
        raise Failure, 'source_git_patch_limit' if bytes > MAX_PATCHES
        { 'filename' => path, 'status' => status, 'baseline_blob' => sha_before, 'candidate_blob' => sha_after,
          'binary' => binary, 'patch' => patch, 'patch_sha256' => Digest::SHA256.hexdigest(patch) }
      end
    end

    def collect(repository, before, after, seconds: 120)
      raise Failure, 'unsupported_source_repository' unless repository.match?(%r{\A[A-Za-z0-9_-][A-Za-z0-9_.-]*/[A-Za-z0-9_-][A-Za-z0-9_.-]*\z})
      raise Failure, 'source_git_commit_identity_invalid' unless [before, after].all? { |sha| sha.match?(/\A[0-9a-f]{40}\z/) }
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
      files = nil; temp = nil
      Dir.mktmpdir('mobi-official-source-') do |repo|
        temp = repo
        command(repo, ['init', '--quiet'], deadline)
        command(repo, ['remote', 'add', 'origin', "https://github.com/#{repository}.git"], deadline)
        command(repo, ['config', 'remote.origin.promisor', 'true'], deadline)
        command(repo, ['config', 'remote.origin.partialclonefilter', 'blob:none'], deadline)
        [before, after].uniq.each do |sha|
          command(repo, ['-c', 'protocol.file.allow=never', 'fetch', '--quiet', '--filter=blob:none', '--depth=1', '--no-tags', 'origin', sha], deadline)
        end
        files = read_repository(repo, before, after, deadline: deadline)
      end
      raise Failure, 'source_git_cleanup_incomplete' if File.exist?(temp)
      { 'state' => 'collected', 'baseline_commit' => before, 'candidate_commit' => after, 'files' => files, 'gaps' => [],
        'source_method' => 'git_endpoint_diff', 'source_downloads_cleaned' => !File.exist?(temp),
        'git_sha256' => Maintenance.file_sha('/usr/bin/git'), 'deriver_sha256' => Maintenance.file_sha(__FILE__) }
    rescue Failure, SystemCallError => error
      { 'state' => 'incomplete', 'baseline_commit' => before, 'candidate_commit' => after, 'files' => files || [],
        'gaps' => [error.is_a?(Failure) ? error.message : 'source_git_unavailable'],
        'source_method' => 'git_endpoint_diff', 'source_downloads_cleaned' => temp.nil? || !File.exist?(temp),
        'diagnostic' => error.is_a?(TransportFailure) ? error.diagnostic : nil }
    end
  end
end
