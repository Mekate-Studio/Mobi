#!/usr/bin/env ruby
# frozen_string_literal: true

require "rexml/document"
require_relative "lib/maintenance"

module_file = Maintenance.project_path("android-app/module.yaml")
artifact_group = "androidx.activity"
artifact_name = "activity-compose"
metadata_url = "https://dl.google.com/android/maven2/androidx/activity/activity-compose/maven-metadata.xml"

def fetch_latest_version(metadata_url)
  response = Maintenance.get(metadata_url)
  document = REXML::Document.new(response.body)
  version = document.elements["metadata/versioning/release"]&.text
  version ||= document.elements["metadata/versioning/latest"]&.text

  abort("Could not resolve latest version from Maven metadata") if version.nil? || version.empty?

  version
end

latest_version = ENV["ACTIVITY_COMPOSE_VERSION"]
latest_version = fetch_latest_version(metadata_url) if latest_version.nil? || latest_version.empty?

contents = File.read(module_file)
pattern = /^(\s*-\s*#{Regexp.escape(artifact_group)}:#{Regexp.escape(artifact_name)}:)([^\s]+)(\s*)$/

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

warn("No #{artifact_group}:#{artifact_name} dependency entry was updated in #{module_file}") if updated == contents

File.write(module_file, updated)

printf(
  "Updated %s to %s in %s\n",
  "#{artifact_group}:#{artifact_name}",
  latest_version,
  module_file
)
