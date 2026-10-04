# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'open3'
require 'tmpdir'

# Execute refusal paths without native tools, signing material or provider keys.
module IOSBuilderTest
  ROOT = File.expand_path('../..', __dir__)
  GUARD = File.join(ROOT, 'scripts/ci/validate_ios_builder.sh')
  @tests = []
  def self.test(name, &block); @tests << [name, block]; end
  def self.assert(value, message = 'assertion failed'); raise message unless value; end
  def self.run(*argv, builder: nil, project: ROOT)
    Open3.capture2e({ 'PATH' => '/usr/bin:/bin', 'KOTLIN_IOS_BUILDER' => builder, 'CI_PROJECT_DIR' => project }, *argv, unsetenv_others: true)
  end
  class Held < StandardError; end
  module UI
    def self.user_error!(message); raise Held, message; end
    def self.message(_message); end
  end
  class FastlaneDSL
    attr_reader :lanes, :calls
    def initialize; @lanes = {}; @calls = []; end
    def default_platform(_name); end
    def desc(_text); end
    def platform(name, &block); @platform = name; instance_eval(&block); end
    def lane(name, &block); @lanes[[@platform, name]] = block; end
    def build_ios_app(**_options); @calls << :signing; raise 'Signing was reached'; end
    def app_store_connect_api_key(**_options); @calls << :credentials; raise 'Credentials were reached'; end
    def upload_to_testflight(**_options); @calls << :upload; raise 'Upload was reached'; end
  end
  def self.with_fastlane
    previous = ENV.to_h
    ENV.replace('PATH' => '/usr/bin:/bin')
    dsl = FastlaneDSL.new
    file = File.join(ROOT, 'fastlane/Fastfile')
    dsl.instance_eval(File.read(file), file)
    yield dsl
  ensure
    ENV.replace(previous)
  end
  test('unset, empty and explicit Kotlin selectors permit build scope') do
    [nil, '', 'kotlin'].each do |builder|
      _, status = run(GUARD, 'build', builder: builder)
      assert(status.success?)
    end
  end
  test('Gradle and unknown selectors require content rollback before compilation') do
    %w[gradle unknown].each do |builder|
      output, status = run(GUARD, 'build', builder: builder)
      assert(status.exitstatus == 64 && output.include?('complete reviewed content patch'))
    end
  end
  test('unknown scope and surplus arguments refuse') do
    [['other'], ['build', 'extra']].each do |args|
      _, status = run(GUARD, *args)
      assert(status.exitstatus == 64)
    end
  end
  test('signed scope is held with no enabling environment bypass') do
    output, status = run(GUARD, 'signed-release')
    assert(status.exitstatus == 69 && output.include?('separate signed-delivery evidence'))
  end
  test('raw wrappers reject incompatible content before creating output roots') do
    [['run_xcodebuild_with_logs.sh', 'Debug'], ['run_xcode_tests_with_logs.sh']].each do |args|
      output, status = run(File.join(ROOT, 'scripts/ci', args.first), *args.drop(1), builder: 'gradle')
      assert(status.exitstatus == 64 && output.include?('complete reviewed content patch'))
    end
  end
  test('Xcode delivery signing is held while unsigned archive assessments remain available') do
    cases = [
      [{ 'ACTION' => 'install', 'CODE_SIGNING_ALLOWED' => 'YES' }, 69],
      [{ 'ACTION' => 'install', 'CODE_SIGNING_ALLOWED' => 'NO' }, 0],
      [{ 'ACTION' => 'build', 'CONFIGURATION' => 'Release', 'PLATFORM_NAME' => 'iphoneos', 'CODE_SIGNING_ALLOWED' => 'YES' }, 69],
      [{ 'ACTION' => 'build', 'CONFIGURATION' => 'Release', 'PLATFORM_NAME' => 'iphoneos', 'CODE_SIGNING_ALLOWED' => 'NO' }, 0],
      [{ 'ACTION' => 'build', 'CONFIGURATION' => 'Debug', 'PLATFORM_NAME' => 'iphonesimulator' }, 0]
    ]
    cases.each do |settings, expected|
      _, status = Open3.capture2e({ 'PATH' => '/usr/bin:/bin' }.merge(settings), GUARD, 'build', unsetenv_others: true)
      assert(status.exitstatus == expected)
    end
  end
  test('CI release preparation refuses before normal setup or bundle installation') do
    script = 'source "$CI_PROJECT_DIR/scripts/ci/lib/ios.sh"; ci_prepare_ios_job() { echo UNEXPECTED_SETUP; }; ci_bundle_install() { echo UNEXPECTED_BUNDLE; }; ci_prepare_ios_fastlane_job'
    output, status = run('/bin/bash', '-c', script)
    assert(status.exitstatus == 69 && !output.include?('UNEXPECTED'))
  end
  test('CI delivery entries hold before even installing credential cleanup traps') do
    Dir.mktmpdir('mobi-delivery-refusal-') do |project|
      FileUtils.mkdir_p(File.join(project, 'scripts/ci'))
      FileUtils.cp(GUARD, File.join(project, 'scripts/ci'))
      FileUtils.mkdir_p(File.join(project, 'fastlane'))
      sentinel = File.join(project, 'fastlane/AuthKey.p8')
      File.write(sentinel, 'owned test sentinel, not a credential')
      %w[ios-archive-release ios-testflight].each do |job|
        output, status = run(File.join(ROOT, 'scripts/ci/run_job.sh'), job, project: project)
        assert(status.exitstatus == 69 && output.include?('Credentialed iOS') && File.exist?(sentinel))
      end
    end
  end
  test('Xcode preflight precedes the managed integration phase and rejects Gradle') do
    output, status = run('/usr/bin/plutil', '-convert', 'json', '-o', '-', File.join(ROOT, 'ios-app/module.xcodeproj/project.pbxproj'))
    assert(status.success?)
    objects = JSON.parse(output).fetch('objects')
    app = objects.fetch('A93CFF74FDA625823427EABC')
    phases = app.fetch('buildPhases')
    preflight = 'E04D202610040001001664A3'
    managed = 'A93CF46588F1B180AC5404FB'
    assert(phases.index(preflight) < phases.index(managed))
    script = objects.fetch(preflight).fetch('shellScript')
    output, status = Open3.capture2e({ 'PATH' => '/usr/bin:/bin', 'SRCROOT' => File.join(ROOT, 'ios-app'), 'KOTLIN_IOS_BUILDER' => 'gradle' }, '/bin/sh', '-c', script, unsetenv_others: true)
    assert(status.exitstatus == 64 && output.include?('complete reviewed content patch'))
    assert(objects.fetch(managed).fetch('shellScript') == "# !KOTLIN INTEGRATION STEP!\n# This script is managed by the Kotlin Toolchain, do not edit manually!\n\"${KOTLIN_CLI_WRAPPER_PATH}\" tool xcode-integration\n")
  end
  test('Fastlane selector normalization agrees with shell defaults') do
    with_fastlane do |dsl|
      [nil, '', 'kotlin'].each do |builder|
        builder.nil? ? ENV.delete('KOTLIN_IOS_BUILDER') : ENV['KOTLIN_IOS_BUILDER'] = builder
        assert(dsl.ios_kotlin_builder == 'kotlin')
      end
    end
  end
  test('Fastlane release lanes hold before signing, credentials or uploads') do
    with_fastlane do |dsl|
      %i[buildRelease uploadTestFlight].each do |name|
        begin
          dsl.lanes.fetch([:ios, name]).call
          raise 'Expected release hold'
        rescue Held => error
          assert(error.message.include?('separate signed-delivery evidence') && dsl.calls.empty?)
        end
      end
    end
  end
  test('Fastlane refuses stale selectors and restores caller environment on failure') do
    with_fastlane do |dsl|
      ENV['KOTLIN_IOS_BUILDER'] = 'gradle'
      ENV['GRADLE_USER_HOME'] = '/owned-test-home'
      previous = ENV.to_h
      begin
        dsl.with_ios_kotlin_builder_env { raise 'Unexpected build' }
        raise 'Expected selector refusal'
      rescue Held => error
        assert(error.message.include?('complete reviewed content patch') && ENV.to_h == previous)
      end
    end
  end
  failures = @tests.count do |name, block|
    block.call; puts "PASS #{name}"; false
  rescue StandardError => error
    warn "FAIL #{name}: #{error.message}"; true
  end
  puts "#{@tests.size} iOS builder contracts, #{failures} failures"
  exit 1 unless failures.zero?
end
