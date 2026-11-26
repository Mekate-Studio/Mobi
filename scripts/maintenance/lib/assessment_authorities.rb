# frozen_string_literal: true

require_relative 'release_assessment'
require 'base64'

module Maintenance
  module AssessmentAuthorities
    DOC_REPOSITORY = 'JetBrains/kotlin-web-site'
    DOC_PATH = 'docs/topics/native-swift-export.md'
    SAMPLE_REPOSITORY = 'Kotlin/swift-export-sample'
    ISSUES = %w[KT-64572 KT-80305].freeze
    module_function

    def commit_at(http, repository, at, path: nil)
      Time.iso8601(at)
      query = { 'until' => at, 'per_page' => '1' }
      query['path'] = path if path
      rows = http.get("https://api.github.com/repos/#{repository}/commits?#{URI.encode_www_form(query)}")
      raise Failure, 'authority_history_commit_unavailable' unless rows.is_a?(Array) && rows.size == 1 && rows.first.is_a?(Hash) && rows.first['sha'].to_s.match?(/\A[0-9a-f]{40}\z/)
      rows.first.fetch('sha')
    end

    def document(http, commit)
      url = "https://api.github.com/repos/#{DOC_REPOSITORY}/contents/#{DOC_PATH}?ref=#{commit}"
      data = http.get(url)
      raise Failure, 'unsupported_authority_document' unless data.is_a?(Hash) && data['encoding'] == 'base64' && data['path'] == DOC_PATH && data['content'].is_a?(String)
      body = Base64.strict_decode64(data.fetch('content').delete("\n"))
      sha = Digest::SHA1.hexdigest("blob #{body.bytesize}\0" + body)
      raise Failure, 'authority_document_identity_mismatch' unless sha == data.fetch('sha')
      { 'commit' => commit, 'url' => url, 'blob_sha' => sha, 'body_sha256' => Digest::SHA256.hexdigest(body), 'body' => body }
    end

    def collect(http, baseline_published:, candidate_published:)
      gaps = []; documents = {}; sample = {}; issues = []
      begin
        before = commit_at(http, DOC_REPOSITORY, baseline_published, path: DOC_PATH)
        after = commit_at(http, DOC_REPOSITORY, candidate_published, path: DOC_PATH)
        documents = { 'baseline' => document(http, before), 'candidate' => document(http, after) }
        history = []; complete = false
        4.times do |page|
          query = URI.encode_www_form('path' => DOC_PATH, 'since' => baseline_published, 'until' => candidate_published, 'per_page' => '100', 'page' => (page + 1).to_s)
          rows = http.get("https://api.github.com/repos/#{DOC_REPOSITORY}/commits?#{query}")
          raise Failure, 'authority_history_invalid' unless rows.is_a?(Array) && rows.size <= 100 && rows.all? { |row| row.is_a?(Hash) && row['sha'].to_s.match?(/\A[0-9a-f]{40}\z/) }
          history.concat(rows.map { |row| row.slice('sha', 'html_url') })
          if rows.size < 100
            complete = true; break
          end
        end
        documents['history'] = history
        gaps << 'authority_document_history_limit' unless complete
      rescue Failure, KeyError, ArgumentError, TypeError, NoMethodError => error
        gaps << (error.is_a?(Failure) ? error.message : 'authority_document_interval_unavailable')
      end
      begin
        before = commit_at(http, SAMPLE_REPOSITORY, baseline_published)
        after = commit_at(http, SAMPLE_REPOSITORY, candidate_published)
        data = http.get("https://api.github.com/repos/#{SAMPLE_REPOSITORY}/compare/#{before}...#{after}")
        files = data.fetch('files')
        raise Failure, 'sample_interval_incomplete' unless files.is_a?(Array) && files.size < 300 && files.all? { |file| file.is_a?(Hash) && file['filename'].is_a?(String) && file['patch'].is_a?(String) } && data.dig('base_commit', 'sha') == before && data.dig('merge_base_commit', 'sha') == before && %w[ahead identical].include?(data['status'])
        sample = { 'baseline_commit' => before, 'candidate_commit' => after, 'files' => files,
          'role' => 'supporting_implementation_guidance_not_primary_api_authority' }
      rescue Failure, KeyError, ArgumentError, TypeError, NoMethodError => error
        gaps << (error.is_a?(Failure) ? error.message : 'sample_interval_unavailable')
      end
      ISSUES.each do |id|
        url = "https://youtrack.jetbrains.com/api/issues/#{id}?fields=idReadable,summary,updated,description"
        begin
          data = http.get(url)
          raise Failure, 'issue_identity_mismatch' unless data.is_a?(Hash) && data['idReadable'] == id && data['summary'].is_a?(String) && data['updated'].is_a?(Numeric)
          issues << { 'id' => id, 'url' => url, 'updated' => data['updated'], 'body_sha256' => Maintenance.digest(data),
            'role' => 'issue_snapshot_not_proof_a_release_contains_a_fix' }
        rescue Failure => error
          gaps << id + ':' + error.message
        end
      end
      { 'state' => gaps.empty? ? 'complete' : 'incomplete', 'primary_document' => documents, 'supporting_sample' => sample,
        'issues' => issues, 'gaps' => gaps.uniq, 'retirement_authorized' => false }
    end
  end
end
