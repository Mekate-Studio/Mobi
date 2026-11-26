# frozen_string_literal: true

require_relative 'run_store'

module Maintenance
  # Retain only evidence, never disposable source trees, SDKs or dependency
  # caches. The same digest manifest travels with local and hosted packets.
  module AssessmentBundle
    MAX_BYTES = 256 * 1024 * 1024
    module_function

    def export(root, directory, qualification, security: {})
      id = qualification['run_id']
      return { 'state' => 'complete', 'files' => {}, 'bytes' => 0 } unless id
      raise Failure, 'Invalid qualification bundle run ID' unless id.match?(/\A[0-9a-f]{32}\z/)
      raise Failure, 'Unsafe qualification bundle directory' unless File.realpath(directory) == directory
      store = File.join(root, '.maintenance', 'runs-release-assessment')
      expected = { File.join(store, id + '.result.json') => qualification.fetch('result_sha256') }
      qualification.fetch('evidence_refs', []).each do |ref|
        path = ref.fetch('file')
        raise Failure, 'Unsafe bound qualification reference' unless path.match?(%r{\A\.maintenance/runs-release-assessment/#{id}/steps/(?:baseline|candidate)-toolchain-mobile/evidence\.json\z})
        expected[File.join(root, path)] = ref.fetch('sha256')
      end
      security.fetch('advisories', {}).each do |phase, receipt|
        raise Failure, 'Unsafe advisory phase' unless %w[baseline candidate].include?(phase)
        expected[File.join(store, id, 'assessment-advisories-' + phase + '.json')] = receipt.fetch('receipt_sha256')
      end
      expected.each do |path, sha|
        raise Failure, 'Bound qualification evidence drift' unless sha.is_a?(String) && File.file?(path) && !File.symlink?(path) && Maintenance.file_sha(path) == sha
      end
      sources = [File.join(store, id + '.result.json')] +
        Dir.glob(File.join(store, id, 'steps', '*', '*')) +
        Dir.glob(File.join(store, id, 'assessment-advisories-*.json'))
      files = {}; bytes = 0
      sources.sort.each do |source|
        raise Failure, 'Unsafe qualification bundle source' unless File.file?(source) && !File.symlink?(source) && File.realpath(source) == source
        relative = source.delete_prefix(store + '/').delete_prefix(id + '/')
        relative = 'result.json' if relative == id + '.result.json'
        raise Failure, 'Unsafe qualification bundle path' unless relative.match?(%r{\A(?:steps/(?:baseline|candidate)-toolchain-mobile/[a-zA-Z0-9_.-]+|result\.json|assessment-advisories-(?:baseline|candidate)\.json)\z})
        bytes += File.size(source)
        raise Failure, 'qualification_evidence_bundle_size_limit' if bytes > MAX_BYTES
        relative = 'native/' + id + '/' + relative
        target = File.join(directory, relative)
        FileUtils.mkdir_p(File.dirname(target))
        raise Failure, 'Unsafe qualification bundle target' if File.symlink?(target) || File.realpath(File.dirname(target)) != File.dirname(target)
        FileUtils.cp(source, target)
        files[relative] = Maintenance.file_sha(target)
        raise Failure, 'Bound qualification evidence drift during export' if expected[source] && files[relative] != expected[source]
      end
      { 'state' => 'complete', 'files' => files, 'bytes' => bytes, 'run_id' => id }
    rescue Failure, SystemCallError, KeyError => error
      { 'state' => 'incomplete', 'files' => files || {}, 'bytes' => bytes || 0,
        'gaps' => [error.is_a?(Failure) ? error.message : 'qualification_evidence_export_failed'] }
    end
  end
end
