# frozen_string_literal: true

require_relative 'ui_test_inputs'
require 'tmpdir'

module AndroidUIInputsTest
  def self.assert(value, message = 'assertion failed')
    raise message unless value
  end

  def self.write(root, path, value)
    file = File.join(root, path)
    FileUtils.mkdir_p(File.dirname(file))
    File.write(file, value.is_a?(Hash) ? JSON.generate(value) : value)
    file
  end

  def self.fixture
    Dir.mktmpdir('mobi-ui-inputs-') do |root|
      root = File.realpath(root)
      AndroidUITests::Inputs::MODULES.each do |name|
        write(root, "#{name}/module.yaml", "dependencies: []\n")
        jar = write(root, "build/tasks/_#{name}_jarAndroidDebug/#{name}-jvm.jar", name)
        write(root, "build/incremental.state/_#{name}_jarAndroidDebug-fixture", 'codeVersion' => '0.13.0', 'outputFiles' => [jar])
        write(root, "build/incremental.state/_#{name}_compileAndroidDebug-fixture", 'codeVersion' => '0.13.0',
              'inputValues' => { 'user.settings' => JSON.generate('kotlin' => { 'compilerVersion' => '2.5.0-Beta2' }) })
      end
      main = write(root, '.m2.cache/com/google/guava/listenablefuture/1.0/listenablefuture-1.0.jar', 'production')
      test = write(root, '.m2.cache/com/google/guava/listenablefuture/9999.0-empty-to-avoid-conflict-with-guava/listenablefuture-9999.0-empty-to-avoid-conflict-with-guava.jar', 'test')
      %w[main test].zip([main, test]).each do |scope, path|
        write(root, "build/incremental.state/shared-ui-home_android_#{scope}-fixture", 'codeVersion' => '0.13.0',
              'outputValues' => { 'serializedOutput' => JSON.generate('runtimeClasspath' => [path]) })
      end
      write(root, '.kotlin-cache/kotlin-cli-0.13.0/extra/android-integration-gradle-plugin.classpath.txt', "gradle-9.3.1.jar\n")
      write(root, 'android-app/module.yaml', "settings:\n  android: {compileSdk: 37, minSdk: 36, buildToolsVersion: 37.0.0}\n")
      write(root, 'shared-ui-home/module.yaml', "test-settings@android:\n  jvm:\n    test:\n      freeJvmArgs: [--enable-native-access=ALL-UNNAMED]\n")
      write(root, 'shared-ui-home/test@android/ScreenTest.kt', 'class ScreenTest')
      yield root
    end
  end

  def self.refuse(root, pattern)
    inputs(root).call
    raise 'Expected Android UI input refusal'
  rescue AndroidUITests::Failure => error
    assert(error.message.match?(pattern), error.message)
  end

  def self.inputs(root)
    AndroidUITests::Inputs.new(root, cache: File.join(root, '.kotlin-cache'))
  end

  def self.run
    fixture do |root|
      result = inputs(root).call
      assert(result['libraries'].size == 3 && result['agp'] == '9.3.1')
      assert(result['dependencies'].first['version'] == '9999.0-empty-to-avoid-conflict-with-guava')
      assert(result['production_graph'].first['version'] == '1.0')
      assert(result['test_graph_changes'] == [{ 'component' => 'com.google.guava:listenablefuture', 'production' => '1.0', 'test' => '9999.0-empty-to-avoid-conflict-with-guava' }])
      assert(result['test_sources'].size == 1)
      (result['libraries'] + result['dependencies']).each do |item|
        assert(item['sha256'] == Digest::SHA256.file(item['path']).hexdigest)
      end
      puts 'PASS UI target consumes the exact Toolchain test graph and records production substitutions'
    end

    fixture do |root|
      path = File.join(root, 'build/incremental.state/shared-ui-home_android_test-fixture')
      data = JSON.parse(File.read(path)); data['codeVersion'] = 'new-unqualified'
      File.write(path, JSON.generate(data))
      refuse(root, /Requalify/)
      puts 'PASS unqualified Toolchain record versions refuse'
    end

    fixture do |root|
      path = File.join(root, 'build/incremental.state/_shared-core_compileAndroidDebug-fixture')
      data = JSON.parse(File.read(path)); data['inputValues']['user.settings'] = JSON.generate('kotlin' => { 'compilerVersion' => 'different' })
      File.write(path, JSON.generate(data))
      refuse(root, /Mixed Kotlin/)
      puts 'PASS mixed compiler inputs refuse'
    end

    fixture do |root|
      File.delete(File.join(root, 'build/tasks/_shared-core_jarAndroidDebug/shared-core-jvm.jar'))
      refuse(root, /Missing or unsupported/)
      puts 'PASS missing library output refuses'
    end

    fixture do |root|
      File.delete(File.join(root, 'shared-ui-home/test@android/ScreenTest.kt'))
      refuse(root, /No Android UI test sources/)
      puts 'PASS absent UI test sources refuse'
    end
    fixture do |root|
      write(root, 'shared-ui-home/module.yaml', "dependencies: [../unqualified-module]\n")
      refuse(root, /Requalify.*local-module/)
      puts 'PASS a new local-module graph requires qualification'
    end
    puts '6 Android UI input contracts, 0 failures'
  end
end

AndroidUIInputsTest.run if $PROGRAM_NAME == __FILE__
