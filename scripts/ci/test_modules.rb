# frozen_string_literal: true

require_relative '../dev/quality'

module HostTests
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
        source_root = path.delete_prefix(name + '/').split('/').first
        unless %w[test test@android].include?(source_root)
          raise Quality::Failure, "Uncovered Kotlin test target: #{path}; add an explicit native test runner before claiming coverage"
        end
      end
      next false if tests.empty?

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
