# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'rbconfig'
gem 'xcodeproj', '= 1.28.1'
require 'xcodeproj'
require_relative '../../adapters/kotlin_resources'
require_relative '../core'
require_relative '../swift_export/tool_identity'

source, output, cache, base = ARGV
phase = ENV.fetch('MOBI_PHASE')
control = File.dirname(ENV.fetch('MOBI_RESULT_PATH'))
report = { 'schema' => 1, 'scope' => 'real-app-test-host-clients', 'status' => 'infrastructure', 'commands' => [], 'production_adoption' => false }
resources = Maintenance::KotlinResources.new(File.dirname(control), ENV.fetch('MOBI_RESOURCE_NONCE'))
begin
  inputs = JSON.parse(File.read(File.join(output, 'native-inputs.json')))
  root = File.join(output, 'relocated/delivery')
  project = Xcodeproj::Project.open(File.join(root, 'Consumer.xcodeproj'))
  app = project.targets.find { |target| target.name == 'SwiftExportConsumer' }
  raise Maintenance::Failure, 'Pilot configuration missing' unless inputs.dig('app_configuration', 'scheme') == 'SwiftExportPilot' && inputs.dig('app_configuration', 'bundle_identifier') == 'studio.mekate.mobi'
  FileUtils.cp(File.join(source, 'ios-app/pilot/tests/PilotBehaviorTests.swift'), root)
  tests = project.new_target(:unit_test_bundle, 'PilotBehaviorTests', :ios, '26.0')
  tests.add_file_references([project.main_group.new_file('PilotBehaviorTests.swift')])
  tests.add_dependency(app)
  app.build_configurations.each { |config| config.build_settings['ENABLE_TESTABILITY'] = 'YES' }
  tests.build_configurations.each do |config|
    config.build_settings.merge!('GENERATE_INFOPLIST_FILE' => 'YES', 'PRODUCT_BUNDLE_IDENTIFIER' => 'studio.mekate.mobi.PilotBehaviorTests',
                                'SWIFT_VERSION' => '6.0', 'SWIFT_STRICT_CONCURRENCY' => 'complete', 'SWIFT_TREAT_WARNINGS_AS_ERRORS' => 'YES',
                                'CODE_SIGNING_ALLOWED' => 'NO', 'TEST_HOST' => '$(BUILT_PRODUCTS_DIR)/SwiftExportConsumer.app/SwiftExportConsumer',
                                'BUNDLE_LOADER' => '$(TEST_HOST)', 'SWIFT_INCLUDE_PATHS' => ['$(inherited)', '$(PROJECT_DIR)/Package', '$(PROJECT_DIR)/NativeProducts'],
                                'FRAMEWORK_SEARCH_PATHS' => ['$(inherited)', '$(PROJECT_DIR)/NativeProducts'],
                                'OTHER_SWIFT_FLAGS' => app.build_configurations.first.build_settings['OTHER_SWIFT_FLAGS'],
                                'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => inputs['app_configuration']['compilation_conditions'])
  end
  FileUtils.cp(File.join(source, 'ios-app/pilot/tests/PilotUITests.swift'), root)
  ui = project.new_target(:ui_test_bundle, 'PilotUITests', :ios, '26.0')
  ui.add_file_references([project.main_group.new_file('PilotUITests.swift')]); ui.add_dependency(app)
  ui.build_configurations.each do |config|
    config.build_settings.merge!('GENERATE_INFOPLIST_FILE' => 'YES', 'PRODUCT_BUNDLE_IDENTIFIER' => 'studio.mekate.mobi.PilotUITests',
                                'SWIFT_VERSION' => '6.0', 'SWIFT_STRICT_CONCURRENCY' => 'complete', 'SWIFT_TREAT_WARNINGS_AS_ERRORS' => 'YES',
                                'CODE_SIGNING_ALLOWED' => 'NO', 'TEST_TARGET_NAME' => 'SwiftExportConsumer',
                                'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => inputs['app_configuration']['compilation_conditions'])
  end
  project.save
  scheme = Xcodeproj::XCScheme.new
  scheme.add_build_target(app); scheme.add_test_target(tests); scheme.add_test_target(ui); scheme.set_launch_target(app)
  scheme.save_as(project.path, 'SwiftExportPilot', true)
  developer = Maintenance::SwiftExport::ToolIdentity.developer_dir
  ENV['DEVELOPER_DIR'] = developer
  resources.register_xcode_project!(project.path.to_s, developer_dir: developer)
  major = inputs.dig('app_configuration', 'simulator_major')
  raise Maintenance::Failure, 'Explicit pilot simulator major missing' unless [26, 27].include?(major)
  device = resources.create_simulator!(developer, major: major)
  report['simulator_runtime'] = resources.state['runtime']
  report['test_scopes'] = ['real_app_UI_navigation_background_foreground', 'real_app_test_host_clients_and_separate_cohorts', 'typed_native_noncooperative_cleanup_stub']
  argv = ['/usr/bin/xcodebuild', '-project', project.path.to_s, '-scheme', 'SwiftExportPilot', '-configuration', 'Debug',
          '-destination', 'id=' + device, '-derivedDataPath', File.join(cache, 'pilot-tests'), '-parallel-testing-enabled', 'NO', '-test-timeouts-enabled', 'YES', '-default-test-execution-time-allowance', '30', '-maximum-test-execution-time-allowance', '30',
          '-resultBundlePath', File.join(output, 'PilotBehaviorTests.xcresult'), 'test', 'CODE_SIGNING_ALLOWED=NO', 'ARCHS=arm64']
  log = File.join(control, 'pilot-test.log')
  status = File.open(log, 'w') { |stream| pid = Process.spawn(*argv, chdir: root, out: stream, err: [:child, :out]); Process.wait2(pid).last }
  report['commands'] << { 'argv' => argv, 'exit' => status.exitstatus, 'log_sha256' => Maintenance.file_sha(log) }
  text = File.read(log, encoding: 'UTF-8').scrub
  raise Maintenance::Failure, 'Integrated pilot tests failed' unless status.success? && text.include?('** TEST SUCCEEDED **')
  report['status'] = 'passed'
  report['limits'] = 'provisional; simulator UI and client/stub controls do not qualify energy, memory bytes, devices or runtime floors'
rescue StandardError => e
  report['error_class'], report['error'] = e.class.name, e.message
ensure
  Maintenance::RunStore.atomic(ENV.fetch('MOBI_RESULT_PATH'), report)
end
exit(report['status'] == 'passed' ? 0 : 1)
