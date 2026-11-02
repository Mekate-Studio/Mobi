# frozen_string_literal: true

require 'json'
require 'open3'
require 'rexml/document'
require 'shellwords'

# IOS-10: protect the reviewed Swift-export project until Toolchain can own it.
module IOSProject
  class Check
    PACKAGE = '$(SRCROOT)/../build/swift-export/$(CONFIGURATION)-$(PLATFORM_NAME)/Package'
    LIBRARIES = %w[MobiNative ExportedKotlinPackages KotlinRuntimeSupport KotlinCoroutineSupport MobiCore MobiHome MobiNearby MobiIOS].freeze
    PRODUCER = ['set -eu', '/usr/bin/ruby "${SRCROOT}/../scripts/ios/build_swift_export.rb"'].freeze
    PREFLIGHT = ['set -eu', '"${SRCROOT}/../scripts/ci/validate_ios_builder.sh" build'].freeze
    PLANS = %w[PullRequest Nightly].freeze

    def initialize(root)
      @root = root
      @errors = []
    end

    def assert(condition, message)
      @errors << message unless condition
    end

    def object(id)
      @objects.fetch(id, {})
    end

    def target(name)
      matches = @objects.select { |_id, value| value['isa'] == 'PBXNativeTarget' && value['name'] == name }
      assert(matches.size == 1, "Expected one #{name} native target")
      matches.first || [nil, {}]
    end

    def phases(target)
      Array(target['buildPhases']).map { |id| object(id) }
    end

    def commands(phase)
      phase.fetch('shellScript', '').lines.map(&:strip).reject { |line| line.empty? || line.start_with?('#') }
    end

    def tokens(value)
      value.is_a?(Array) ? value : Shellwords.split(value.to_s)
    end

    def settings(target, name, libraries)
      configurations = Array(object(target['buildConfigurationList'])['buildConfigurations']).map { |id| object(id) }
      %w[Debug Release].each do |variant|
        config = configurations.find { |item| item['name'] == variant }
        assert(config, "Missing #{name} #{variant} configuration")
        next unless config

        settings = config.fetch('buildSettings', {})
        %w[SWIFT_INCLUDE_PATHS LIBRARY_SEARCH_PATHS].each do |key|
          assert(tokens(settings[key]).include?(PACKAGE), "#{name} #{variant}: missing Swift-export #{key}")
        end
        flags = tokens(settings['OTHER_LDFLAGS'])
        assert(libraries.all? { |library| flags.include?("-l#{library}") }, "#{name} #{variant}: missing Swift-export linker libraries")
      end
    end

    def scheme(app_id, tests_id)
      path = File.join(@root, 'ios-app/module.xcodeproj/xcshareddata/xcschemes/app.xcscheme')
      doc = REXML::Document.new(File.read(path))
      entries = REXML::XPath.match(doc, '/Scheme/BuildAction/BuildActionEntries/BuildActionEntry')
      [app_id, tests_id].each do |id|
        assert(id && entries.any? { |entry| entry.attributes['buildForTesting'] == 'YES' && entry.elements['BuildableReference']&.attributes&.[]('BlueprintIdentifier') == id }, 'app scheme must build both app and appTests for testing')
      end
      runnable = doc.elements['Scheme/LaunchAction/BuildableProductRunnable/BuildableReference']
      assert(runnable && runnable.attributes['BlueprintIdentifier'] == app_id, 'app scheme must launch the app target')
      action = doc.elements['Scheme/TestAction']
      assert(action && action.attributes['shouldAutocreateTestPlan'] == 'NO', 'app scheme must retain explicit test plans')
      refs = REXML::XPath.match(doc, '/Scheme/TestAction/TestPlans/TestPlanReference')
      PLANS.each do |name|
        assert(refs.any? { |ref| ref.attributes['reference'] == "container:tests/Plans/#{name}.xctestplan" }, "app scheme is missing #{name} test plan")
        plan = JSON.parse(File.read(File.join(@root, "ios-app/tests/Plans/#{name}.xctestplan")))
        assert(Array(plan['testTargets']).any? { |entry| entry.dig('target', 'identifier') == tests_id && entry['enabled'] != false }, "#{name} plan must select appTests")
      end
    end

    def run
      path = File.join(@root, 'ios-app/module.xcodeproj/project.pbxproj')
      json, error, status = Open3.capture3('/usr/bin/plutil', '-convert', 'json', '-o', '-', path)
      raise ArgumentError, "Cannot parse project.pbxproj: #{error.strip}" unless status.success?

      @objects = JSON.parse(json).fetch('objects')
      app_id, app = target('app')
      tests_id, tests = target('appTests')
      build_phases = phases(app)
      producer = build_phases.find { |phase| phase['name'] == 'Build Kotlin' } || {}
      preflight = build_phases.find { |phase| phase['name'] == 'Validate Kotlin Builder' } || {}
      assert(commands(producer) == PRODUCER, 'Build Kotlin must invoke the reviewed build_swift_export.rb producer')
      assert(!producer.fetch('shellScript', '').match?(/!(KOTLIN|AMPER KMP) INTEGRATION STEP!/), 'Build Kotlin must not claim the Toolchain-managed integration marker')
      assert(commands(preflight) == PREFLIGHT && build_phases.index(preflight).to_i < build_phases.index(producer).to_i, 'Validate Kotlin Builder must run before Build Kotlin')
      assert(build_phases.none? { |phase| phase['name'] == 'Embed Kotlin Frameworks' }, 'Unexpected framework-mode Embed Kotlin Frameworks phase')
      settings(app, 'app', LIBRARIES)
      settings(tests, 'appTests', ['MobiTestSupport'])
      links = phases(tests).select { |phase| phase['isa'] == 'PBXFrameworksBuildPhase' }.flat_map { |phase| Array(phase['files']) }
      assert(links.any? do |id|
        product = object(object(id)['productRef'])
        product['productName'] == 'MobiIOSTestDependencies' && object(product['package'])['relativePath'] == 'Dependencies'
      end, 'appTests must link the local MobiIOSTestDependencies product')
      scheme(app_id, tests_id)
      @errors
    rescue JSON::ParserError, REXML::ParseException, KeyError, TypeError, ArgumentError, Errno::ENOENT => error
      @errors << error.message
    end
  end

  def self.run(root)
    errors = Check.new(root).run
    if errors.empty?
      puts '[ios-project] Swift-export build, test linkage and app scheme are intact'
      return 0
    end
    warn '[ios-project] IOS-10: Xcode project integration drift detected:'
    errors.each { |error| warn "  - #{error}" }
    warn 'Close Mobi in Android Studio and Xcode. Preserve staged, unstaged and untracked changes in a named stash or backup.'
    warn 'Restore the reviewed project/scheme changes from the revision you intend to test, then rerun this check.'
    warn 'Use just ios-open and the shared app scheme. Recovery: docs/reference/local-development.md#ios-project-integrity'
    78
  end
end

if $PROGRAM_NAME == __FILE__
  abort 'Usage: check_ios_project.rb [project-root]' if ARGV.size > 1
  exit IOSProject.run(File.expand_path(ARGV.first || '../..', ARGV.empty? ? __dir__ : Dir.pwd))
end
