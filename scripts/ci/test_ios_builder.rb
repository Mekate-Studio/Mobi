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
  def self.with_project
    Dir.mktmpdir('mobi-ios-project-') do |project|
      FileUtils.mkdir_p(File.join(project, 'scripts'))
      FileUtils.cp_r(File.join(ROOT, 'scripts/ci'), File.join(project, 'scripts'))
      FileUtils.mkdir_p(File.join(project, 'ios-app/tests'))
      FileUtils.cp_r(File.join(ROOT, 'ios-app/module.xcodeproj'), File.join(project, 'ios-app'))
      FileUtils.cp_r(File.join(ROOT, 'ios-app/tests/Plans'), File.join(project, 'ios-app/tests'))
      yield project
    end
  end
  def self.model(project)
    output, status = run('/usr/bin/plutil', '-convert', 'json', '-o', '-', File.join(project, 'ios-app/module.xcodeproj/project.pbxproj'))
    assert(status.success?)
    JSON.parse(output)
  end
  def self.write_model(project, model)
    File.write(File.join(project, 'ios-app/module.xcodeproj/project.pbxproj'), JSON.pretty_generate(model))
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
  test('Xcode preflight precedes the generated export producer and rejects Gradle') do
    output, status = run('/usr/bin/plutil', '-convert', 'json', '-o', '-', File.join(ROOT, 'ios-app/module.xcodeproj/project.pbxproj'))
    assert(status.success?)
    objects = JSON.parse(output).fetch('objects')
    app = objects.fetch('A93CFF74FDA625823427EABC')
    phases = app.fetch('buildPhases')
    preflight = 'E04D202610040001001664A3'
    producer = 'A93CF46588F1B180AC5404FB'
    assert(phases.index(preflight) < phases.index(producer))
    script = objects.fetch(preflight).fetch('shellScript')
    output, status = Open3.capture2e({ 'PATH' => '/usr/bin:/bin', 'SRCROOT' => File.join(ROOT, 'ios-app'), 'KOTLIN_IOS_BUILDER' => 'gradle' }, '/bin/sh', '-c', script, unsetenv_others: true)
    assert(status.exitstatus == 64 && output.include?('complete reviewed content patch'))
    assert(objects.fetch(producer).fetch('shellScript') == "set -eu\n/usr/bin/ruby \"${SRCROOT}/../scripts/ios/build_swift_export.rb\"\n")
    assert(phases.none? { |phase| objects.fetch(phase)['name'] == 'Embed Kotlin Frameworks' })
  end
  test('project drift refuses before the generated producer or native setup') do
    with_project do |project|
      data = model(project)
      objects = data.fetch('objects')
      producer = objects.values.find { |object| object['isa'] == 'PBXShellScriptBuildPhase' && object['name'] == 'Build Kotlin' }
      producer['shellScript'] = "# !KOTLIN INTEGRATION STEP!\n\"${KOTLIN_CLI_WRAPPER_PATH}\" tool xcode-integration\n"
      write_model(project, data)
      FileUtils.rm(File.join(project, 'ios-app/module.xcodeproj/xcshareddata/xcschemes/app.xcscheme'))
      output, status = run(File.join(project, 'scripts/ci/validate_ios_builder.sh'), 'build')
      assert(status.exitstatus == 78 && output.include?('IOS-10'), 'framework/scheme drift was accepted')
      assert(!File.exist?(File.join(project, 'build')), 'refusal created build output')
    end
  end
  test('valid project formatting, phase comments and personal UI state remain allowed') do
    with_project do |project|
      data = model(project)
      producer = data.fetch('objects').values.find { |object| object['name'] == 'Build Kotlin' }
      producer['shellScript'] = "# local comment\n" + producer.fetch('shellScript').lines.map { |line| "  #{line}" }.join
      write_model(project, data)
      personal = File.join(project, 'ios-app/module.xcodeproj/xcuserdata/order.txt')
      FileUtils.mkdir_p(File.dirname(personal))
      File.write(personal, 'personal scheme order')
      _, status = run(File.join(project, 'scripts/ci/validate_ios_builder.sh'), 'build')
      assert(status.success?)
    end
  end
  test('a Toolchain management marker cannot be added to the custom producer') do
    ['!KOTLIN INTEGRATION STEP!', '!AMPER KMP INTEGRATION STEP!'].each do |marker|
      with_project do |project|
        data = model(project)
        producer = data.fetch('objects').values.find { |object| object['name'] == 'Build Kotlin' }
        producer['shellScript'] = "# #{marker}\n" + producer.fetch('shellScript')
        write_model(project, data)
        output, status = run(File.join(project, 'scripts/ci/validate_ios_builder.sh'), 'build')
        assert(status.exitstatus == 78 && output.include?('managed integration marker'))
      end
    end
  end
  test('every app and test configuration requires Swift-export search paths and libraries') do
    ['app', 'appTests'].product(%w[Debug Release], %w[SWIFT_INCLUDE_PATHS LIBRARY_SEARCH_PATHS OTHER_LDFLAGS]).each do |name, variant, key|
      with_project do |project|
        data = model(project)
        objects = data.fetch('objects')
        target = objects.values.find { |object| object['isa'] == 'PBXNativeTarget' && object['name'] == name }
        ids = objects.fetch(target.fetch('buildConfigurationList')).fetch('buildConfigurations')
        config = ids.map { |id| objects.fetch(id) }.find { |item| item['name'] == variant }
        config.fetch('buildSettings').delete(key)
        write_model(project, data)
        output, status = run(File.join(project, 'scripts/ci/validate_ios_builder.sh'), 'build')
        assert(status.exitstatus == 78 && output.include?("#{name} #{variant}"), "accepted missing #{name}/#{variant}/#{key}")
      end
    end
  end
  test('dropping one generated library is detected even when the Kotlin archive remains') do
    with_project do |project|
      data = model(project)
      data.fetch('objects').values.select { |object| object['isa'] == 'XCBuildConfiguration' }.each do |config|
        flags = config.fetch('buildSettings', {})['OTHER_LDFLAGS']
        flags.delete('-lMobiNearby') if flags.is_a?(Array)
      end
      write_model(project, data)
      output, status = run(File.join(project, 'scripts/ci/validate_ios_builder.sh'), 'build')
      assert(status.exitstatus == 78 && output.include?('linker libraries'))
    end
  end
  test('dropping the linked test product is detected independently of the producer') do
    with_project do |project|
      data = model(project)
      objects = data.fetch('objects')
      product_id = objects.find { |_id, object| object['productName'] == 'MobiIOSTestDependencies' }.first
      objects.values.select { |object| object['isa'] == 'PBXBuildFile' && object['productRef'] == product_id }.each do |object|
        object.delete('productRef')
      end
      write_model(project, data)
      output, status = run(File.join(project, 'scripts/ci/validate_ios_builder.sh'), 'build')
      assert(status.exitstatus == 78 && output.include?('MobiIOSTestDependencies'))
    end
  end
  test('framework embedding and preflight reordering both refuse') do
    %w[embed reorder].each do |change|
      with_project do |project|
        data = model(project)
        objects = data.fetch('objects')
        app = objects.values.find { |object| object['isa'] == 'PBXNativeTarget' && object['name'] == 'app' }
        phases = app.fetch('buildPhases')
        if change == 'embed'
          objects['PROBE_EMBED'] = { 'isa' => 'PBXShellScriptBuildPhase', 'name' => 'Embed Kotlin Frameworks' }
          phases << 'PROBE_EMBED'
        else
          guard = phases.find { |id| objects.fetch(id)['name'] == 'Validate Kotlin Builder' }
          phases.delete(guard)
          phases << guard
        end
        write_model(project, data)
        _, status = run(File.join(project, 'scripts/ci/validate_ios_builder.sh'), 'build')
        assert(status.exitstatus == 78)
      end
    end
  end
  test('scheme launch target and both plan references are required') do
    %w[launch PullRequest Nightly].each do |change|
      with_project do |project|
        path = File.join(project, 'ios-app/module.xcodeproj/xcshareddata/xcschemes/app.xcscheme')
        text = File.read(path)
        text = if change == 'launch'
                 text.sub('BlueprintIdentifier = "A93CFF74FDA625823427EABC"', 'BlueprintIdentifier = "missing"')
                     .sub(/<LaunchAction.*?<\/LaunchAction>/m, '<LaunchAction/>')
               else
                 text.sub("container:tests/Plans/#{change}.xctestplan", 'container:tests/Plans/missing.xctestplan')
               end
        File.write(path, text)
        _, status = run(File.join(project, 'scripts/ci/validate_ios_builder.sh'), 'build')
        assert(status.exitstatus == 78)
      end
    end
  end
  test('a plan selecting another test target refuses') do
    with_project do |project|
      path = File.join(project, 'ios-app/tests/Plans/PullRequest.xctestplan')
      data = JSON.parse(File.read(path))
      data.fetch('testTargets').first.fetch('target')['identifier'] = 'missing'
      File.write(path, JSON.generate(data))
      output, status = run(File.join(project, 'scripts/ci/validate_ios_builder.sh'), 'build')
      assert(status.exitstatus == 78 && output.include?('PullRequest plan must select appTests'))
    end
  end
  test('malformed project and scheme produce actionable configuration errors') do
    ['ios-app/module.xcodeproj/project.pbxproj', 'ios-app/module.xcodeproj/xcshareddata/xcschemes/app.xcscheme'].each do |path|
      with_project do |project|
        File.write(File.join(project, path), 'not a project or XML document')
        output, status = run(File.join(project, 'scripts/ci/validate_ios_builder.sh'), 'build')
        assert(status.exitstatus == 78 && output.include?('Preserve staged, unstaged and untracked'))
      end
    end
  end
  test('raw build and test wrappers reject drift before creating logs or resolving tools') do
    with_project do |project|
      FileUtils.rm(File.join(project, 'ios-app/module.xcodeproj/xcshareddata/xcschemes/app.xcscheme'))
      [['run_xcodebuild_with_logs.sh', 'Debug'], ['run_xcode_tests_with_logs.sh']].each do |args|
        output, status = run(File.join(project, 'scripts/ci', args.first), *args.drop(1))
        assert(status.exitstatus == 78 && output.include?('IOS-10'))
        assert(!File.exist?(File.join(project, 'build')))
      end
    end
  end
  test('direct producer and open helper reject drift before output or IDE launch') do
    with_project do |project|
      FileUtils.mkdir_p(File.join(project, 'scripts/dev'))
      FileUtils.mkdir_p(File.join(project, 'scripts/ios'))
      %w[ios_open.sh common.sh].each { |name| FileUtils.cp(File.join(ROOT, 'scripts/dev', name), File.join(project, 'scripts/dev')) }
      FileUtils.cp(File.join(ROOT, 'scripts/ios/build_swift_export.rb'), File.join(project, 'scripts/ios'))
      FileUtils.rm(File.join(project, 'ios-app/module.xcodeproj/xcshareddata/xcschemes/app.xcscheme'))
      output, status = run('/usr/bin/ruby', File.join(project, 'scripts/ios/build_swift_export.rb'))
      assert(!status.success? && output.include?('IOS-10') && !File.exist?(File.join(project, 'build')))
      stub = File.join(project, 'stub')
      FileUtils.mkdir_p(stub)
      sentinel = File.join(project, 'ide-was-opened')
      File.write(File.join(stub, 'open'), "#!/bin/sh\necho reached > \"$NATIVE_SENTINEL\"\n")
      FileUtils.chmod(0o755, File.join(stub, 'open'))
      output, status = Open3.capture2e({ 'PATH' => "#{stub}:/usr/bin:/bin", 'NATIVE_SENTINEL' => sentinel }, File.join(project, 'scripts/dev/ios_open.sh'), unsetenv_others: true)
      assert(status.exitstatus == 78 && output.include?('IOS-10') && !File.exist?(sentinel))
    end
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
