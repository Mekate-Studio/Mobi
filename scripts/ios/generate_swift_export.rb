# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'open3'
require 'tmpdir'

# IOS-10: this generation step goes away when Toolchain owns Swift export.
# The caller supplies its resolved KLib graph; no second dependency graph lives here.
target, destination, distribution, *modules = ARGV
unless %w[iosArm64 iosSimulatorArm64].include?(target) && destination && distribution && !modules.empty?
  abort 'Usage: generate_swift_export.rb <iosArm64|iosSimulatorArm64> <output> <Native distribution> <name=public|private=klib>...'
end

root = File.expand_path('../..', __dir__)
output = File.expand_path(destination)
FileUtils.mkdir_p(output)
Dir.mktmpdir('mobi-swift-export-') do |temporary|
  # IOS-12: apply private temp ownership to the Toolchain JVM and analysis child.
  options = [ENV['JAVA_TOOL_OPTIONS'], %Q(-Djava.io.tmpdir="#{temporary}")].compact.join(' ')
  environment = { 'TMPDIR' => temporary, 'JAVA_TOOL_OPTIONS' => options }
  native_version, native_status = Open3.capture2e(environment, File.join(distribution, 'bin/konanc'), '-version')
  module_config = File.read(File.join(root, 'tools/swift-export/module.yaml'))
  exporter_version = module_config[/org\.jetbrains\.kotlin:swift-export-embeddable:(\S+)/, 1]
  unless native_status.success? && native_version[/\b(?:kotlinc-native|Kotlin\/Native:)\s+(\S+)/, 1] == exporter_version
    abort 'The standalone exporter and Kotlin/Native versions must match'
  end

  text, status = Open3.capture2e(environment, File.join(root, 'kotlin'), '--shared-cache-dir',
                               File.join(ENV.fetch('KOTLIN_CLI_USER_HOME', File.join(root, '.kotlin-user-home')), 'Library/Caches/JetBrains/Kotlin'), 'run',
                               '-m', 'swift-export', '--main-class', 'MainKt', '--',
                               File.join(output, 'generated'), File.realpath(distribution), target, *modules,
                               chdir: root)
  File.write(File.join(output, 'generate.log'), text)
  unless status.success? && !text.match?(/Exception in thread|NoClassDefFoundError|ClassNotFoundException/)
    abort "Swift export failed:\n#{text}"
  end
  graph = text.lines.each_with_object([]) do |line, entries|
    next unless line.start_with?("MODULE\t")
    fields = line.chomp.split("\t", -1).drop(1)
    abort 'Incomplete Swift-export module record' unless fields.length == 7
    item = %w[name kind swift kotlin header bridge dependencies].zip(fields).to_h
    item['dependencies'] = item.fetch('dependencies').split(',')
    %w[swift kotlin header].each do |key|
      next if item.fetch(key).empty?
      abort "Missing generated #{key}" unless File.file?(item.fetch(key))
    end
    entries << item
  end
  abort 'Swift exporter produced no module graph' if graph.empty?
  File.write(File.join(output, 'modules.json'), JSON.pretty_generate(graph) + "\n")
  puts "Generated #{graph.length} Swift modules for #{target}"
end
