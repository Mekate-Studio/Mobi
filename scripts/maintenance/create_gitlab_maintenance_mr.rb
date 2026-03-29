#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "optparse"
require_relative "lib/maintenance"

Options = Struct.new(
  :branch,
  :commit_message,
  :title,
  :description,
  :target_branch,
  :paths,
  keyword_init: true
)

def usage
  <<~TEXT
    Usage: create_gitlab_maintenance_mr.rb --branch <name> --commit-message <msg> --title <title> [--description <text>] [--target-branch <name>] [--paths <pathspec>...]
  TEXT
end

args = ARGV.dup
paths = []
paths_index = args.index("--paths")

if paths_index
  paths = args[(paths_index + 1)..] || []
  args = args.take(paths_index)
end

options = Options.new(
  description: "",
  target_branch: ENV.fetch("CI_DEFAULT_BRANCH", "main"),
  paths: paths
)

parser = OptionParser.new do |opts|
  opts.banner = usage
  opts.on("--branch NAME") { |value| options.branch = value }
  opts.on("--commit-message MESSAGE") { |value| options.commit_message = value }
  opts.on("--title TITLE") { |value| options.title = value }
  opts.on("--description TEXT") { |value| options.description = value }
  opts.on("--target-branch NAME") { |value| options.target_branch = value }
  opts.on("-h", "--help") do
    puts usage
    exit 0
  end
end

begin
  parser.parse!(args)
rescue OptionParser::ParseError => e
  warn e.message
  warn usage
  exit 1
end

unless args.empty?
  warn "Unknown argument: #{args.first}"
  warn usage
  exit 1
end

if [options.branch, options.commit_message, options.title].any? { |value| value.nil? || value.empty? }
  warn usage
  exit 1
end

ci_project_url = Maintenance.env!("CI_PROJECT_URL")
ci_project_id = Maintenance.env!("CI_PROJECT_ID")
ci_api_v4_url = Maintenance.env!("CI_API_V4_URL")
gitlab_token = Maintenance.env!("GITLAB_MAINTENANCE_TOKEN")

Maintenance.run!("git", "config", "user.name", ENV.fetch("GITLAB_MAINTENANCE_GIT_NAME", "CI Maintenance Bot"))
Maintenance.run!("git", "config", "user.email", ENV.fetch("GITLAB_MAINTENANCE_GIT_EMAIL", "ci-maintenance-bot@example.invalid"))

if options.paths.empty?
  Maintenance.run!("git", "add", "-A")
else
  Maintenance.run!("git", "add", "--", *options.paths)
end

if system("git", "diff", "--cached", "--quiet")
  puts "No maintenance changes detected. Skipping branch push and merge request."
  exit 0
end

Maintenance.run!("git", "checkout", "-B", options.branch)
Maintenance.run!("git", "commit", "-m", options.commit_message)

push_username = ENV.fetch("GITLAB_MAINTENANCE_USERNAME", "oauth2")
push_remote_url = ci_project_url.sub(/\Ahttps:\/\//, "https://#{push_username}:#{gitlab_token}@")
Maintenance.run!("git", "push", "--force-with-lease", push_remote_url, "HEAD:#{options.branch}")

existing_mr_query = URI.encode_www_form(state: "opened", source_branch: options.branch)
existing_response = Maintenance.get(
  "#{ci_api_v4_url}/projects/#{ci_project_id}/merge_requests?#{existing_mr_query}",
  headers: { "PRIVATE-TOKEN" => gitlab_token }
)
existing_merge_requests = JSON.parse(existing_response.body)

if existing_merge_requests.is_a?(Array) && !existing_merge_requests.empty?
  puts "Merge request already exists: !#{existing_merge_requests.first["iid"]}"
  exit 0
end

Maintenance.post_form(
  "#{ci_api_v4_url}/projects/#{ci_project_id}/merge_requests",
  {
    "source_branch" => options.branch,
    "target_branch" => options.target_branch,
    "title" => options.title,
    "description" => options.description,
    "remove_source_branch" => "true"
  },
  headers: { "PRIVATE-TOKEN" => gitlab_token }
)

puts "Created merge request for branch #{options.branch}"
