# frozen_string_literal: true

require_relative 'core'

module Maintenance
  # Report retirement work; release discovery never proves a workaround removable.
  module InteropWorkarounds
    REGISTRY = 'maintenance-interop-workarounds.json'
    module_function

    def observe(root, releases:, source_files:)
      registry = JSON.parse(File.read(File.join(root, REGISTRY)))
      raise Failure, 'Invalid interop workaround registry' unless registry.is_a?(Hash)

      entries = registry.fetch('entries')
      raise Failure, 'Invalid interop workaround registry' unless registry['schema'] == 1 && entries.is_a?(Array) && !entries.empty?
      entries.each { |entry| validate!(entry) }
      ids = entries.map { |entry| entry.fetch('id') }
      raise Failure, 'Duplicate interop workaround ID' unless ids.uniq == ids

      rows = entries.to_h do |entry|
        present = entry['paths'].select { |path| source_files.key?(path) }
        leads = {}; gaps = []
        (entry['recheck_on'] - ['design']).sort.each do |trigger|
          provider = releases[trigger]
          if !provider
            gaps << trigger + ':not_observed'
          elsif provider['state'] != 'observed'
            gaps << trigger + ':provider_incomplete'
          else
            versions = provider.fetch('newer').select { |release| release['age_state'] == 'eligible_for_review' }.map { |release| release.fetch('version') }
            leads[trigger] = versions.sort unless versions.empty?
          end
        end
        # Absence can mean an unmerged candidate, not successful removal.
        source_state = present.empty? ? 'not_in_checkout' : present.size == entry['paths'].size ? 'present' : 'partially_present'
        # Recorded adoption/removal evidence is independent of this watch's probes.
        row = entry.slice('title', 'scope', 'disposition', 'disposition_note', 'disposition_evidence',
                          'replacement', 'retirement_checks', 'probe_state', 'probe_command', 'probe_report').merge(
          'source_state' => source_state, 'present_paths' => present,
          'source_sha256' => Maintenance.digest(present.sort.to_h { |path| [path, source_files.fetch(path)] }),
          'recheck_state' => leads.empty? ? 'review_required' : 'release_review_due',
          'release_leads' => leads, 'coverage_gaps' => gaps,
          'retirement_state' => 'unverified', 'retirement_authorized' => false,
        )
        [entry['id'], row]
      end
      { 'schema' => 1, 'state' => 'review_required', 'registry_sha256' => Maintenance.file_sha(File.join(root, REGISTRY)),
        'entries' => rows, 'retirement_authorized' => false }
    rescue JSON::ParserError, KeyError, TypeError, Errno::ENOENT => error
      raise Failure, 'Cannot observe interop workarounds: ' + error.class.name
    end

    def validate!(entry)
      raise Failure, 'Invalid interop workaround entry' unless entry.is_a?(Hash)

      required = %w[id scope title reason replacement disposition_note]
      valid = required.all? { |key| entry[key].is_a?(String) && !entry[key].empty? && !entry[key].match?(/[\r\n|]/) }
      valid &&= entry['id'].match?(/\AIOS-\d{2}\z/) && %w[default pilot candidate].include?(entry['scope'])
      valid &&= %w[active removed historical].include?(entry['disposition'])
      valid &&= (entry['disposition'] == 'historical') == (entry['scope'] != 'default')
      evidence = entry['disposition_evidence']
      valid &&= evidence.is_a?(Array) && !evidence.empty? && evidence.all? do |url|
        url.is_a?(String) && url.match?(%r{\Ahttps://github.com/Mekate-Studio/Mobi/pull/[1-9]\d*\z})
      end
      %w[paths recheck_on retirement_checks].each do |key|
        value = entry[key]
        valid &&= value.is_a?(Array) && !value.empty? && value.all? { |item| item.is_a?(String) && !item.empty? }
      end
      valid &&= %w[not_automated available_in_ci].include?(entry['probe_state'])
      if entry['probe_state'] == 'available_in_ci'
        valid &&= entry['probe_command'] == 'ruby scripts/ios/check_swift_export.rb' &&
                  entry['probe_report'] == 'build/logs/swift-export-checks/report.json'
      end
      raise Failure, 'Invalid interop workaround entry' unless valid
      entry['paths'].each do |path|
        raise Failure, 'Invalid workaround source path' if Pathname.new(path).absolute? || path.split('/').include?('..')
      end
    end

    def summary(entries)
      return [] if entries.empty?

      lines = ['', '## Interop workaround retirement', '',
               'Recorded dispositions cite reviewed PRs. Release leads request reassessment. This watch did not run retirement probes; available CI checks are pointers, not fresh removal evidence.',
               'Qualified removals retain their regression checks and release triggers. Historical experiments were not adopted by the maintained app.']
      { 'active' => 'Active app requirements', 'removed' => 'Qualified removals', 'historical' => 'Historical experiments (not adopted)' }.each do |disposition, heading|
        rows = entries.sort.select { |_id, row| row.fetch('disposition') == disposition }
        lines += ['', '### ' + heading + ' (' + rows.size.to_s + ')', '',
                  '| ID | Mechanism and recorded disposition | Evidence | Recheck | Probe |', '| --- | --- | --- | --- | --- |']
        rows.each do |id, row|
          evidence = row.fetch('disposition_evidence').map { |url| '[#' + url.split('/').last + '](' + url + ')' }.join(', ')
          description = row.fetch('title') + ': ' + row.fetch('disposition_note')
          lines << '| ' + [id, description, evidence, row.fetch('recheck_state'), row.fetch('probe_state')].join(' | ') + ' |'
        end
      end
      gaps = entries.values.flat_map { |row| row.fetch('coverage_gaps') }.uniq.sort
      lines << '' << 'Unobserved trigger coverage: ' + (gaps.empty? ? 'none in the configured provider set' : gaps.join(', ')) + '.'
      lines << 'See maintenance-interop-workarounds.json for replacement targets and required removal checks.'
      lines
    end
  end
end
