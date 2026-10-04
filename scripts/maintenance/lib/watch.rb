# frozen_string_literal: true

require_relative 'run_store'
require 'uri'

module Maintenance
  # HTTP evidence acquisition is separate from semantic comparison and notification.
  class WatchHTTP
    LIMIT = 8 * 1024 * 1024

    def initialize(runner: Open3.method(:capture3))
      @runner = runner
    end

    def get(url, token: nil)
      uri = URI(url)
      raise Failure, 'Unsupported watch provider URL' unless uri.scheme == 'https' && uri.host == 'api.github.com' && !uri.userinfo
      headers = ['Accept: application/vnd.github+json', 'User-Agent: Mobi-Compatibility-Watch', 'X-GitHub-Api-Version: 2022-11-28']
      if token && !token.empty?
        raise Failure, 'Invalid provider credential format' unless token.match?(/\A[!-~]+\z/)
        headers << 'Authorization: Bearer ' + token
      end
      # The pinned Ruby runtime intentionally has no OpenSSL extension. Use the
      # host's certificate-verified HTTPS client, without reading curlrc/proxy or
      # placing credentials in argv. Never follow redirects with credentials.
      output, _error, status = @runner.call({ 'PATH' => '/usr/bin:/bin', 'LC_ALL' => 'C' }, '/usr/bin/curl', '--disable',
                                             '--proto', '=https', '--tlsv1.2', '--silent', '--show-error', '--connect-timeout', '10', '--max-time', '45',
                                             '--max-filesize', LIMIT.to_s, '--header', '@-', '--write-out', "\n%{http_code}", url,
                                             stdin_data: headers.join("\n") + "\n", unsetenv_others: true)
      raise Failure, 'provider_response_too_large' if status.exitstatus == 63 || output.bytesize > LIMIT + 4
      raise Failure, 'provider_network_unavailable' unless status.success?
      body, _separator, code = output.rpartition("\n")
      raise Failure, 'provider_http_' + code if code.match?(/\A\d{3}\z/) && code != '200'
      raise Failure, 'provider_invalid_transport_response' unless code == '200'
      { 'url' => url, 'retrieved_at' => Time.now.utc.iso8601, 'sha256' => Digest::SHA256.hexdigest(body),
        'transport_sha256' => Maintenance.file_sha('/usr/bin/curl'), 'body' => body }
    rescue IOError, SystemCallError
      raise Failure, 'provider_network_unavailable'
    end
  end

  module Watch
    MAX_AGE = 31 * 86_400
    module_function

    def canonical(value)
      case value
      when Hash then value.keys.sort.to_h { |key| [key, canonical(value.fetch(key))] }
      when Array then value.map { |entry| canonical(entry) }
      else value
      end
    end

    def snapshot(scope, observation, now: Time.now.utc)
      data = { 'schema' => 1, 'kind' => 'watch_observation', 'scope' => canonical(scope), 'observation' => canonical(observation),
               'recorded_at' => now.iso8601, 'adoption_authorized' => false }
      data.merge('sha256' => Maintenance.digest(data))
    end

    def previous(path, scope, now: Time.now.utc)
      return [nil, 'initial'] unless path
      return [nil, 'missing'] unless File.file?(path)
      raise Failure, 'Invalid previous watch file' if File.symlink?(path) || File.size(path) > 2 * 1024 * 1024
      data = JSON.parse(File.read(path))
      keys = %w[schema kind scope observation recorded_at adoption_authorized sha256]
      valid = data.is_a?(Hash) && data.keys.sort == keys.sort && data['schema'] == 1 && data['kind'] == 'watch_observation' &&
              data['scope'].is_a?(Hash) && data['observation'].is_a?(Hash) && data['recorded_at'].is_a?(String) && data['adoption_authorized'] == false &&
              data['sha256'] == Maintenance.digest(data.reject { |key, _| key == 'sha256' })
      return [nil, 'invalid'] unless valid
      age = now - Time.iso8601(data['recorded_at'])
      return [nil, 'invalid_time'] if age < 0
      return [nil, 'expired'] if age > MAX_AGE
      return [nil, 'scope_changed'] unless data['scope'] == canonical(scope)
      [data, 'restored']
    rescue JSON::ParserError, ArgumentError, TypeError, Failure
      [nil, 'invalid']
    end

    def fields(value, prefix = '')
      return { prefix => value } unless value.is_a?(Hash) && !value.empty?
      value.each_with_object({}) do |(key, entry), result|
        result.merge!(fields(entry, prefix.empty? ? key : prefix + '.' + key))
      end
    end

    def compare(current, previous, continuity:)
      unless previous && continuity == 'restored'
        return { 'notify' => true, 'continuity' => continuity, 'changes' => [{ 'kind' => 'comparison_unavailable', 'field' => 'history' }] }
      end
      before = fields(previous.fetch('observation')); after = fields(current.fetch('observation'))
      changes = (before.keys | after.keys).sort.filter_map do |field|
        next if before[field] == after[field]
        kind = if field.start_with?('matrix.') && after[field] == 'passed'
                 'capability_improved'
               elsif field.start_with?('matrix.candidate/') && before[field] == 'passed' && after[field] == 'failed' && current.dig('observation', 'native_state') == 'incompatible'
                 'capability_regressed'
               elsif field.start_with?('matrix.')
                 'capability_evidence_changed'
               elsif field.start_with?('releases.')
                 'release_evidence_changed'
               else
                 'blocker_or_assessment_changed'
               end
        { 'kind' => kind, 'field' => field, 'before' => before[field], 'after' => after[field] }
      end
      { 'notify' => !changes.empty?, 'continuity' => continuity, 'changes' => changes }
    end

    def summary(report)
      observation = report.fetch('snapshot').fetch('observation')
      lines = ['## Dependency compatibility observation', '',
               'Watch operation: `' + report.fetch('operation_state') + '`. Compatibility assessment: `' + observation.fetch('assessment_state') + '`.',
               'History: `' + report.dig('notification', 'continuity') + '`. Meaningful change: `' + report.dig('notification', 'notify').to_s + '`.',
               '', 'This is a bounded observation; adoption is not authorized and bridge retirement remains deferred.', '',
               '| Capability | Result |', '| --- | --- |']
      observation.fetch('matrix').sort.each { |key, value| lines << '| `' + key + '` | `' + value + '` |' }
      lines += ['', '| Release provider | Status | Newer stable releases observed |', '| --- | --- | --- |']
      observation.fetch('releases').sort.each do |name, provider|
        versions = provider.fetch('newer', []).map { |r| r['version'] + ' (' + r['age_state'] + ')' }.join(', ')
        finding = provider['state'] == 'observed' ? (versions.empty? ? 'None observed in this bounded response' : versions) : 'Unknown: provider evidence is incomplete'
        lines << '| ' + name + ' | `' + provider['state'] + '` | ' + finding + ' |'
      end
      observations = observation.fetch('capability_observations', [])
      unless observations.empty?
        lines += ['', '| Upstream capability observation | Scope | Evidence state |', '| --- | --- | --- |']
        observations.each { |entry| lines << '| `' + entry.fetch('id') + '` | `' + entry.fetch('scope') + '` | `' + entry.fetch('state') + '` |' }
      end
      lines += ['', 'Missing capabilities: ' + observation.fetch('missing_capabilities').map { |s| '`' + s + '`' }.join(', ') + '.', '']
      lines.join("\n")
    end

    def announce(report, io: $stdout, summary_path: nil)
      text = summary(report)
      File.open(summary_path, 'a') { |file| file.write(text) } if summary_path
      return unless report.dig('notification', 'notify')
      level = report.dig('snapshot', 'observation', 'assessment_state') == 'checks_passed' ? 'notice' : 'warning'
      # Only controlled enums/counts reach workflow commands; upstream prose never does.
      io.puts '::' + level + ' title=Dependency compatibility changed::Review the compatibility observation and its explicit gaps; adoption remains manual.'
    end
  end
end
