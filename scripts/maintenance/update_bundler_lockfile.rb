#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "lib/maintenance"

Maintenance.chdir_repo_root do
  Maintenance.run!("bundle", "update", "fastlane")
end
