#!/usr/bin/env ruby
# frozen_string_literal: true

require "net/http"
require "shellwords"
require "uri"

module Maintenance
  module_function

  def repo_root
    @repo_root ||= File.expand_path("../../..", __dir__)
  end

  def project_path(*parts)
    File.join(repo_root, *parts)
  end

  def chdir_repo_root(&block)
    Dir.chdir(repo_root, &block)
  end

  def run!(*command)
    success = system(*command)
    return if success

    exit_code = $?.exitstatus || 1
    abort("Command failed (#{exit_code}): #{Shellwords.join(command)}")
  end

  def env!(key)
    value = ENV[key]
    return value unless value.nil? || value.empty?

    abort("Missing required environment variable: #{key}")
  end

  def get(uri_string, headers: {})
    uri = URI(uri_string)
    request = Net::HTTP::Get.new(uri)
    headers.each { |key, value| request[key] = value }
    perform_request(uri, request)
  end

  def post_form(uri_string, form_data, headers: {})
    uri = URI(uri_string)
    request = Net::HTTP::Post.new(uri)
    headers.each { |key, value| request[key] = value }
    request.set_form_data(form_data)
    perform_request(uri, request)
  end

  def perform_request(uri, request)
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.request(request)
    end

    return response if response.is_a?(Net::HTTPSuccess)

    abort(
      "HTTP request failed: #{request.method} #{uri} -> #{response.code} #{response.message}\n#{response.body}"
    )
  end
  private_class_method :perform_request
end
