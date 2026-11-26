# frozen_string_literal: true

require_relative 'core'
require 'uri'

module Maintenance
  module AssessmentPacket
    SHA = /\A[0-9a-f]{64}\z/
    module_function

    def reference!(path, sha)
      raise Failure, 'Invalid assessment evidence digest' unless sha.is_a?(String) && sha.match?(SHA)
      raise Failure, 'Assessment evidence missing, symlinked or changed' unless File.file?(path) && !File.symlink?(path) && Maintenance.file_sha(path) == sha
    end

    def verify(root, path, now: Time.now.utc)
      root = File.realpath(root)
      path = File.expand_path(path, root)
      parent = File.join(root, '.maintenance', 'release-assessments')
      relative = path.delete_prefix(parent + '/')
      raise Failure, 'Assessment packet must be an owned local report' unless path.start_with?(parent + '/') && relative.match?(%r{\A[0-9a-f]{32}/report\.json\z})
      raise Failure, 'Symlinked assessment packet directory' unless File.realpath(File.dirname(path)) == File.dirname(path)
      raise Failure, 'Invalid assessment packet file' unless File.file?(path) && !File.symlink?(path) && File.size(path) <= 32 * 1024 * 1024
      report = JSON.parse(File.read(path))
      expected = Maintenance.digest(report.reject { |key, _| key == 'packet_sha256' })
      raise Failure, 'Assessment packet digest changed' unless report['schema'] == 1 && report['kind'] == 'local_release_assessment' && report['packet_sha256'] == expected
      raise Failure, 'Assessment packet cannot authorize adoption or publication' unless %w[adoption_authorized retirement_authorized pr_creation_authorized].all? { |key| report[key] == false }
      source = Source.new(root)
      raise Failure, 'Assessment source changed; reassess before approval' unless report['source_sha256'] == Maintenance.digest(source.files)
      binding = report['git'] || report.fetch('assessments').filter_map { |row| row.dig('stages', 'qualification', 'binding', 'git') }.first
      raise Failure, 'Assessment source Git identity changed or is missing' unless binding && source.git_identity == binding
      policy = JSON.parse(File.read(File.join(root, 'maintenance-policy.json')))
      raise Failure, 'Assessment policy changed' unless report['policy_sha256'] == Maintenance.file_sha(File.join(root, 'maintenance-policy.json'))
      directory = File.dirname(path)
      reasons = []
      report.fetch('provider_evidence').each do |receipt|
        reference!(File.join(directory, 'evidence', receipt.fetch('sha256') + '.body'), receipt['sha256'])
        uri = URI(receipt.fetch('url'))
        raise Failure, 'Invalid assessment provider URL' unless uri.scheme == 'https' && !uri.userinfo
        age = now - Time.iso8601(receipt.fetch('retrieved_at'))
        raise Failure, 'Assessment evidence timestamp is in the future' if age.negative?
        max_age = uri.host == 'api.osv.dev' ? policy.fetch('advisory_max_age_hours') : policy.fetch('release_evidence_max_age_hours')
        reasons << 'provider_evidence_stale' if age > max_age * 3600
      end
      report.fetch('assessments').each do |row|
        row.dig('stages', 'evidence', 'files').to_h.each do |file, sha|
          raise Failure, 'Unsafe bundled evidence reference' unless file.match?(%r{\Anative/[0-9a-f]{32}/(?:steps/(?:baseline|candidate)-toolchain-mobile/[a-zA-Z0-9_.-]+|result\.json|assessment-advisories-(?:baseline|candidate)\.json)\z})
          full = File.join(directory, file)
          raise Failure, 'Symlinked bundled evidence directory' unless File.realpath(File.dirname(full)) == File.dirname(full)
          reference!(full, sha)
        end
        %w[interval_reference authorities_reference].each do |name|
          ref = row.dig('stages', 'upstream', name)
          next unless ref
          file = ref.fetch('file')
          raise Failure, 'Unsafe upstream assessment reference' unless file.is_a?(String) && file.match?(/\A[a-zA-Z0-9_.-]+\.json\z/)
          reference!(File.join(directory, file), ref.fetch('sha256'))
        end
        next unless row['patch_sha256']
        patch_file = row.fetch('patch_file', 'candidate-patch.json')
        raise Failure, 'Unsafe assessment patch reference' unless patch_file.is_a?(String) && patch_file.match?(/\Acandidate-patch(?:-[A-Za-z0-9_.-]+)?\.json\z/)
        patch_path = File.join(directory, patch_file)
        raise Failure, 'Invalid assessment patch file' unless File.file?(patch_path) && !File.symlink?(patch_path) && File.size(patch_path) <= 8 * 1024 * 1024
        patch = JSON.parse(File.read(patch_path))
        raise Failure, 'Assessment candidate patch changed' unless Maintenance.digest(patch) == row['patch_sha256']
        patch.each do |edit|
          original = source.files[edit.fetch('path')]
          raise Failure, 'Assessment patch preimage changed' unless original && original['sha256'] == edit['before_sha256']
          raise Failure, 'Assessment patch content changed' unless Digest::SHA256.hexdigest(edit.fetch('content')) == edit['after_sha256']
        end
      end
      report.fetch('assessments').each do |row|
        qualification = row.dig('stages', 'qualification')
        next unless qualification && qualification['run_id']
        id = qualification['run_id']
        raise Failure, 'Invalid qualification run ID' unless id.match?(/\A[0-9a-f]{32}\z/)
        result = File.join(root, '.maintenance', 'runs-release-assessment', id + '.result.json')
        reference!(result, qualification.fetch('result_sha256'))
        qualification.fetch('evidence_refs').each do |ref|
          relative = ref.fetch('file')
          raise Failure, 'Unsafe qualification evidence reference' unless relative.match?(%r{\A\.maintenance/runs-release-assessment/#{id}/steps/(?:baseline|candidate)-toolchain-mobile/evidence\.json\z})
          file = File.join(root, relative)
          reference!(file, ref.fetch('sha256'))
          evidence = JSON.parse(File.read(file))
          evidence.values.grep(Hash).select { |value| value.key?('file') && value.key?('sha256') }.each do |value|
            name = value.fetch('file')
            raise Failure, 'Unsafe native evidence reference' unless name.match?(/\A[a-z][a-z0-9-]*\.json\z/)
            reference!(File.join(File.dirname(file), name), value.fetch('sha256'))
          end
          evidence.fetch('commands', []).each do |command|
            name = command.fetch('log')
            raise Failure, 'Unsafe native command log reference' unless name.match?(/\A[a-z][a-z0-9-]*\.log\z/)
            reference!(File.join(File.dirname(file), name), command.fetch('sha256'))
          end
        end
      end
      source.verify!
      raise Failure, 'Assessment source Git identity changed during verification' unless source.git_identity == binding
      { 'schema' => 1, 'state' => reasons.empty? ? 'packet_verified' : 'incomplete', 'packet_sha256' => expected,
        'assessment_state' => report['state'], 'reasons' => reasons.uniq, 'adoption_authorized' => false, 'pr_creation_authorized' => false }
    rescue KeyError, TypeError, JSON::ParserError, URI::InvalidURIError, ArgumentError, Errno::ENOENT
      raise Failure, 'Malformed or missing assessment packet/evidence'
    end
  end
end
