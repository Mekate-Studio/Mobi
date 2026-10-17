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
        row = entry.slice('title', 'scope', 'replacement', 'retirement_checks', 'probe_state').merge(
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

      required = %w[id scope title reason replacement]
      valid = required.all? { |key| entry[key].is_a?(String) && !entry[key].empty? && !entry[key].match?(/[\r\n|]/) }
      valid &&= entry['id'].match?(/\AIOS-\d{2}\z/) && %w[default pilot candidate].include?(entry['scope'])
      %w[paths recheck_on retirement_checks].each do |key|
        value = entry[key]
        valid &&= value.is_a?(Array) && !value.empty? && value.all? { |item| item.is_a?(String) && !item.empty? }
      end
      raise Failure, 'Invalid interop workaround entry' unless valid && entry['probe_state'] == 'not_automated'
      entry['paths'].each do |path|
        raise Failure, 'Invalid workaround source path' if Pathname.new(path).absolute? || path.split('/').include?('..')
      end
    end

    def summary(entries)
      return [] if entries.empty?

      lines = ['', '## Interop workaround retirement', '',
               'Release leads request reassessment; no retirement probes ran and no removal is authorized.', '',
               '| ID | Scope | Source | Recheck | Probe |', '| --- | --- | --- | --- | --- |']
      entries.sort.each do |id, row|
        lines << '| ' + [id, row.fetch('scope'), row.fetch('source_state'), row.fetch('recheck_state'), row.fetch('probe_state')].join(' | ') + ' |'
      end
      gaps = entries.values.flat_map { |row| row.fetch('coverage_gaps') }.uniq.sort
      lines << '' << 'Unobserved trigger coverage: ' + (gaps.empty? ? 'none in the configured provider set' : gaps.join(', ')) + '.'
      lines << 'See maintenance-interop-workarounds.json for replacement targets and required removal checks.'
      lines
    end
  end
end
