#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
module_file="${repo_root}/android-app/module.yaml"
artifact_group="androidx.activity"
artifact_name="activity-compose"
metadata_url="https://dl.google.com/android/maven2/androidx/activity/activity-compose/maven-metadata.xml"

latest_version="${ACTIVITY_COMPOSE_VERSION:-}"

if [[ -z "${latest_version}" ]]; then
  latest_version="$(
    curl --fail --silent --show-error "${metadata_url}" \
      | ruby -r rexml/document -e '
          document = REXML::Document.new($stdin.read)
          version = document.elements["metadata/versioning/release"]&.text
          version ||= document.elements["metadata/versioning/latest"]&.text

          abort("Could not resolve latest version from Maven metadata") if version.nil? || version.empty?

          puts version
        '
  )"
fi

ruby - "${module_file}" "${artifact_group}" "${artifact_name}" "${latest_version}" <<'RUBY'
module_file, group, artifact, latest_version = ARGV
contents = File.read(module_file)
pattern = /^(\s*-\s*#{Regexp.escape(group)}:#{Regexp.escape(artifact)}:)([^\s]+)(\s*)$/

updated = contents.gsub(pattern) do
  prefix = Regexp.last_match(1)
  current_version = Regexp.last_match(2)
  suffix = Regexp.last_match(3)

  if current_version == latest_version
    "#{prefix}#{current_version}#{suffix}"
  else
    "#{prefix}#{latest_version}#{suffix}"
  end
end

if updated == contents
  warn "No #{group}:#{artifact} dependency entry was updated in #{module_file}"
end

File.write(module_file, updated)
RUBY

printf 'Updated %s to %s in %s\n' \
  "${artifact_group}:${artifact_name}" \
  "${latest_version}" \
  "${module_file}"
