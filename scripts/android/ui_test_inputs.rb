# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'json'
require 'yaml'

module AndroidUITests
  class Failure < StandardError; end

  # AND-03: consume the selected Toolchain graph, rather than resolving another
  # app graph in Gradle. Requalify these record formats on Toolchain updates.
  class Inputs
    MODULES = %w[shared-core shared-feature-home shared-ui-home].freeze

    def initialize(root, cache: ENV.fetch('KOTLIN_CLI_BOOTSTRAP_CACHE_DIR', File.join(root, '.kotlin-cache')))
      @root = File.realpath(root)
      @cache = cache
    end

    def record(pattern)
      paths = Dir.glob(File.join(@root, 'build/incremental.state', pattern))
      raise Failure, "Expected one Toolchain record: #{pattern}" unless paths.size == 1

      data = JSON.parse(File.read(paths.first))
      raise Failure, 'Requalify Android UI input records for this Toolchain version' unless data.fetch('codeVersion') == '0.13.0'

      data
    end

    def artifact(path)
      raise Failure, "Missing or unsupported Android UI input: #{path}" unless File.file?(path) && %w[.jar .aar].include?(File.extname(path))

      { 'path' => File.realpath(path), 'sha256' => Digest::SHA256.file(path).hexdigest }
    end

    def dependencies(scope)
      data = record("shared-ui-home_android_#{scope}-*")
      paths = JSON.parse(data.fetch('outputValues').fetch('serializedOutput')).fetch('runtimeClasspath')
      raise Failure, 'Empty Android UI dependency graph' unless paths.is_a?(Array) && !paths.empty?

      paths.uniq.sort.map do |path|
        parts = path.split('/.m2.cache/', 2).fetch(1).split('/')
        raise Failure, 'Unsupported Maven input path' unless parts.size >= 4

        artifact(path).merge('component' => parts[0...-3].join('.') + ':' + parts[-3], 'version' => parts[-2])
      end
    end

    def call
      MODULES.each do |name|
        declarations = YAML.safe_load(File.read(File.join(@root, name, 'module.yaml')))
        declarations.select { |key, _| key.match?(/\A(?:test-)?dependencies(?:@android)?\z/) }.each_value do |items|
          items.each do |item|
            dependency = item.is_a?(Hash) ? item.keys.fetch(0) : item
            next unless dependency.start_with?('../')

            path = File.expand_path(dependency, File.join(@root, name))
            raise Failure, 'Requalify the Android UI local-module graph' unless MODULES.map { |mod| File.join(@root, mod) }.include?(path)
          end
        end
      end
      libraries = MODULES.map do |name|
        compiled = record("_#{name}_compileAndroidDebug-*")
        version = JSON.parse(compiled.fetch('inputValues').fetch('user.settings')).fetch('kotlin').fetch('compilerVersion')
        raise Failure, 'Mixed Kotlin compiler versions' if @kotlin && @kotlin != version

        @kotlin = version
        jar = File.join(@root, "build/tasks/_#{name}_jarAndroidDebug/#{name}-jvm.jar")
        raise Failure, "Missing declared library output: #{name}" unless record("_#{name}_jarAndroidDebug-*").fetch('outputFiles').include?(jar)

        artifact(jar)
      end
      main = dependencies('main')
      test = dependencies('test')
      versions = test.to_h { |item| [item.fetch('component'), item.fetch('version')] }
      changes = main.filter_map do |item|
        selected = versions[item.fetch('component')]
        next if selected == item.fetch('version')

        { 'component' => item.fetch('component'), 'production' => item.fetch('version'), 'test' => selected }
      end

      index = File.join(@cache, 'kotlin-cli-0.13.0/extra/android-integration-gradle-plugin.classpath.txt')
      agp = File.readlines(index).filter_map { |line| line.strip[/\Agradle-(\d+\.\d+\.\d+)\.jar\z/, 1] }
      raise Failure, 'Expected one bundled Android Gradle plugin version' unless agp.size == 1

      app = YAML.safe_load(File.read(File.join(@root, 'android-app/module.yaml'))).fetch('settings').fetch('android')
      ui = YAML.safe_load(File.read(File.join(@root, 'shared-ui-home/module.yaml')))
      sources = Dir.glob(File.join(@root, 'shared-ui-home/test@android/**/*.kt')).sort
      raise Failure, 'No Android UI test sources' if sources.empty?

      { 'schema' => 1, 'toolchain' => '0.13.0', 'kotlin' => @kotlin, 'agp' => agp.first,
        'android' => app.slice('compileSdk', 'minSdk', 'buildToolsVersion'),
        'jvm_args' => ui.fetch('test-settings@android').fetch('jvm').fetch('test').fetch('freeJvmArgs'),
        'libraries' => libraries, 'dependencies' => test, 'production_graph' => main, 'test_graph_changes' => changes,
        'test_sources' => sources.to_h { |path| [path, Digest::SHA256.file(path).hexdigest] } }
    rescue KeyError, IndexError, JSON::ParserError, Psych::Exception => error
      raise Failure, 'Unsupported Android UI input metadata: ' + error.message
    end
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    abort 'Usage: ui_test_inputs.rb' unless ARGV.empty?
    root = File.expand_path('../..', __dir__)
    output = File.join(root, 'build/android-ui-tests/inputs.json')
    FileUtils.mkdir_p(File.dirname(output))
    File.write(output, JSON.pretty_generate(AndroidUITests::Inputs.new(root).call) + "\n")
    puts '[android-ui-tests] Exported actual Toolchain inputs: ' + output
  rescue AndroidUITests::Failure, SystemCallError => error
    warn '[android-ui-tests] FAIL: ' + error.message
    exit 1
  end
end
