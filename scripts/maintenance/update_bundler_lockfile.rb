#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "lib/maintenance"

Maintenance.chdir_repo_root do
  Maintenance.run!("bundle", "config", "set", "--local", "frozen", "false")
  Maintenance.run!("bundle", "config", "set", "--local", "deployment", "false")
  Maintenance.run!("bundle", "update", "fastlane")
end
