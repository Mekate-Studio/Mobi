# frozen_string_literal: true

require 'digest'
require 'json'
require 'open3'
require 'pathname'

# Read-only verification. Deliberately does not apply/reverse source or remove
# products, commit, alter risk decisions, or treat a receipt as authorization.
module DirectDefaultPatch
  def self.verify(root, receipt_path, patch_path, direction)
    raise 'Expected before or after' unless %w[before after].include?(direction)
    root = File.realpath(root)
    receipt = JSON.parse(File.read(receipt_path))
    raise 'Unsupported review receipt' unless receipt['schema'] == 1 && receipt['scope'] == 'unapplied_direct_ios_development_default_review'
    raise 'Patch bytes differ' unless Digest::SHA256.file(patch_path).hexdigest == receipt.fetch('patch_sha256')
    paths = receipt.fetch('changes').keys
    raise 'Duplicate or empty changes' unless !paths.empty? && paths.uniq == paths
    output, error, status = Open3.capture3('/usr/bin/git', '-C', root, 'apply', '--numstat', '-z', File.expand_path(patch_path))
    raise "Cannot inspect patch: #{error.strip}" unless status.success?
    parsed = output.split("\0").map { |record| record.split("\t", 3).fetch(2) }
    raise 'Patch paths differ from allowlist' unless parsed.sort == paths.sort
    output, status = Open3.capture2('/usr/bin/git', '-C', root, 'rev-parse', 'HEAD')
    raise 'Unexpected source base' unless status.success? && output.strip == receipt.fetch('base_revision')
    expected = receipt.fetch('preserved_files').merge(receipt.fetch('changes').transform_values { |row| row.fetch(direction) })
    expected.each do |path, identity|
      raise 'Unsafe source path' if Pathname.new(path).absolute? || path.split('/').any? { |part| %w[. ..].include?(part) } || path.include?("\0")
      parts = path.split('/')
      raise "Symlinked input: #{path}" if parts.each_index.any? { |index| File.symlink?(File.join(root, *parts.take(index + 1))) }
      file = File.join(root, path)
      if identity.nil?
        raise "Unexpected added-file preimage: #{path}" if File.exist?(file)
      else
        raise "Missing source: #{path}" unless File.file?(file)
        actual = { 'sha256' => Digest::SHA256.file(file).hexdigest, 'executable' => (File.stat(file).mode & 0o111) != 0 }
        raise "Source bytes/mode differ: #{path}" unless actual == identity
      end
    end
    reverse = direction == 'after' ? ['--reverse'] : []
    _, error, status = Open3.capture3('/usr/bin/git', '-C', root, 'apply', '--check', *reverse, File.expand_path(patch_path))
    raise "Patch does not apply cleanly: #{error.strip}" unless status.success?
    { 'state' => 'verified', 'direction' => direction, 'base_revision' => receipt['base_revision'],
      'patch_sha256' => receipt['patch_sha256'], 'change_paths' => paths.size,
      'preserved_paths' => receipt['preserved_files'].size, 'source_mutated' => false,
      'adoption_authorized' => false }
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    raise 'Usage: verify_direct_default_patch.rb <source-root> <receipt-json> <patch-file> <before|after>' unless ARGV.size == 4
    puts JSON.pretty_generate(DirectDefaultPatch.verify(*ARGV))
  rescue StandardError => error
    warn "[direct-default-review] FAIL: #{error.message}"
    exit 1
  end
end
