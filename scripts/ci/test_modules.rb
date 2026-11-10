# frozen_string_literal: true

require_relative '../dev/quality'

module HostTests
  # AND-03: these module-owned component tests run through the resource-enabled
  # AGP target. Keep unknown native test roots refusing below.
  ANDROID_UI_ROOT = 'shared-ui-home/test@android/'

  def self.ui_test?(path)
    path.start_with?(ANDROID_UI_ROOT) && path.end_with?('.kt')
  end

  def self.ui_sources(paths: nil)
    (paths || Dir.glob(ANDROID_UI_ROOT + '**/*.kt')).select { |path| ui_test?(path) }.sort
  end

  # These Kotlin fixture libraries are exercised by the hosted Swift tests in
  # ios-test. This is not support for running arbitrary Kotlin/Native test roots.
  IOS_CLIENT_FIXTURES = %w[
    shared-ios-app/test@ios/IosInteropTestServices.kt
  ].freeze

  def self.modules(paths: nil)
    graph = Quality::ModuleGraph.new
    graph.modules.select do |name|
      tests = if paths
                paths.select { |path| path.start_with?(name + '/') && path.delete_prefix(name + '/').match?(/\Atest(?:@[^\/]+)?\/.*\.kt\z/) }.sort
              else
                Dir.glob("#{name}/test{,@*}/**/*.kt").sort
              end
      tests.each do |path|
        Quality.source_path!(path)
        next if IOS_CLIENT_FIXTURES.include?(path) || ui_test?(path)
        source_root = path.delete_prefix(name + '/').split('/').first
        unless %w[test test@android].include?(source_root)
          raise Quality::Failure, "Uncovered Kotlin test target: #{path}; add an explicit native test runner before claiming coverage"
        end
      end
      next false if tests.all? { |path| IOS_CLIENT_FIXTURES.include?(path) || ui_test?(path) }

      product = graph.configs.fetch(name).fetch('product')
      android = product == 'android/app' || product == 'android/lib' ||
                (product.is_a?(Hash) && (product['type'].to_s.start_with?('android/') ||
                 Array(product['platforms']).include?('android')))
      raise Quality::Failure, "No host-test runner for #{name}: #{product.inspect}" unless android

      true
    end
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    Dir.chdir(File.expand_path('../..', __dir__))
    raise Quality::Failure, 'Usage: test_modules.rb' unless ARGV.empty?

    puts HostTests.modules
  rescue Quality::Failure, KeyError, SystemCallError => error
    warn "[host-tests] FAIL: #{error.message}"
    exit 1
  end
end
