# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'json'
require 'open3'
require 'tmpdir'

# IOS-10: Toolchain still owns KLib compilation and resolution. This small
# producer supplies the missing export, native bridge and Swift module steps.
module MobiSwiftExport
  class Build
    PROJECTS = {
      'shared-ios-app' => ['MobiIOS', 'public'],
      'shared-feature-home' => ['MobiHome', 'public'],
      'shared-feature-nearby-vehicle-map' => ['MobiNearby', 'public'],
      'shared-core' => ['MobiCore', 'private'],
      'shared-di' => ['MobiDI', 'private'],
      'shared-ui-home' => ['MobiUI', 'private']
    }.freeze
    EXPECTED_MODULES = %w[ExportedKotlinPackages KotlinRuntimeSupport KotlinCoroutineSupport MobiCore MobiHome MobiNearby MobiIOS].freeze

    def initialize
      @root = File.expand_path('../..', __dir__)
      @platform = ENV.fetch('PLATFORM_NAME', 'iphonesimulator')
      @target = { 'iphonesimulator' => 'iosSimulatorArm64', 'iphoneos' => 'iosArm64' }.fetch(@platform)
      abort 'Unknown producer option' unless (ARGV - %w[--strict-support --runtime-assertions]).empty?
      @configuration = ENV.fetch('CONFIGURATION', 'Debug')
      abort 'Expected Debug or Release' unless %w[Debug Release].include?(@configuration)
      @output = File.join(@root, 'build/swift-export', @configuration + '-' + @platform)
      @cache = File.join(ENV.fetch('KOTLIN_CLI_USER_HOME', File.join(@root, '.kotlin-user-home')), 'Library/Caches/JetBrains/Kotlin')
      FileUtils.mkdir_p(@output)
    end

    def command(name, args)
      puts '[swift-export] ' + name
      $stdout.flush
      text, status = Open3.capture2e(@environment || {}, *args, chdir: @root)
      File.write(File.join(@output, name + '.log'), text)
      @commands ||= []
      @commands << { 'name' => name, 'argv' => args, 'exit' => status.exitstatus }
      File.write(File.join(@output, 'commands.json'), JSON.pretty_generate(@commands) + "\n")
      text.lines.select { |line| line.include?('warning:') }.each { |line| warn line }
      abort "Swift export #{name} failed:\n#{text}" unless status.success?
      text
    end

    def libraries
      command('klibs', [File.join(@root, 'kotlin'), '--shared-cache-dir', @cache,
                       'build', '-m', 'shared-ios-app', '-p', @target, '-v', @configuration.downcase])
      # IOS-10: pinned Toolchain task records identify the exact resolved KLibs.
      # Match declared outputs, not truncated or hashed record filenames.
      records = Dir.glob(File.join(@root, 'build/incremental.state/_shared*compile*')).map { |p| JSON.parse(File.read(p)) }
      projects = PROJECTS.map do |project, (name, visibility)|
        path = File.join(@root, "build/tasks/_#{project}_compile#{@target.sub(/^ios/, 'Ios')}#{@configuration}/#{project}.klib")
        { 'name' => name, 'visibility' => visibility, 'path' => path }
      end
      if @configuration == 'Debug'
        projects << { 'name' => 'MobiTestSupport', 'visibility' => 'public',
                      'path' => File.join(@root, 'build/tasks/_shared-ios-app_compileIosSimulatorArm64TestDebug/shared-ios-app_test.klib').sub('IosSimulatorArm64', @target.sub(/^ios/, 'Ios')) }
      end
      paths = projects.flat_map do |item|
        record = records.find { |r| r.fetch('outputFiles').include?(item.fetch('path')) }
        abort 'Missing Toolchain library record: ' + item.fetch('path') unless record && record.fetch('codeVersion') == '0.13.0'
        version = JSON.parse(record.fetch('inputValues').fetch('kotlin.settings')).fetch('compilerVersion')
        abort 'Mixed Kotlin compiler versions' if @compiler_version && @compiler_version != version
        @compiler_version = version
        record.fetch('inputFiles').select { |p| File.extname(p) == '.klib' }
      end
      external = (paths.uniq - projects.map { |p| p.fetch('path') }).sort.each_with_index.map do |path, index|
        name = File.basename(path).start_with?('kotlinx-coroutines-core-') ? 'KotlinxCoroutinesCore' : "Dependency#{index}"
        { 'name' => name, 'visibility' => 'private', 'path' => path }
      end
      projects + external
    end

    def generate(inputs)
      @native = Dir.glob(File.join(@cache, "extract.cache/*kotlin-native-prebuilt-#{@compiler_version}-macos-aarch64*.d")).fetch(0)
      declarations = inputs.map { |m| [m.fetch('name'), m.fetch('visibility'), m.fetch('path')].join('=') }
      command('generation', ['/usr/bin/ruby', File.join(@root, 'scripts/ios/generate_swift_export.rb'),
                             @target, @output, @native] + declarations)
      @modules = JSON.parse(File.read(File.join(@output, 'modules.json')))
      abort 'Unexpected generated API graph; review its export surface' unless @modules.map { |m| m.fetch('name') }.sort == (EXPECTED_MODULES + (@configuration == 'Debug' ? ['MobiTestSupport'] : [])).sort
      @package = File.join(@output, 'Package')
      FileUtils.mkdir_p(@package)
      runtime = File.join(@native, 'konan/swift_export/kotlin_runtime')
      FileUtils.cp_r(Dir.glob(File.join(runtime, '*')), @package)
      maps = File.read(File.join(@package, 'module.modulemap'))
      @modules.select { |m| m.fetch('kind') == 'bridge' }.each do |m|
        header = m.fetch('bridge') + '.h'
        FileUtils.cp(m.fetch('header'), File.join(@package, header))
        maps += "\nmodule #{m.fetch('bridge')} { header \"#{header}\" export * }\n"
      end
      File.write(File.join(@package, 'module.modulemap'), maps)
    end

    def native_archive(inputs)
      args = [File.join(@native, 'bin/konanc'), '-target', @target == 'iosArm64' ? 'ios_arm64' : 'ios_simulator_arm64',
              '-produce', 'static', '-o', File.join(@package, 'MobiNative'),
              '-Xbinary=swiftExport=true',
              '-opt-in', 'kotlin.experimental.ExperimentalNativeApi', '-opt-in', 'kotlinx.cinterop.ExperimentalForeignApi',
              '-opt-in', 'kotlin.native.internal.InternalForKotlinNative']
      args += ['-Xbinary=runtimeAssertionsMode=panic'] if ARGV.include?('--runtime-assertions') || ENV['MOBI_SWIFT_EXPORT_RUNTIME_ASSERTIONS'] == 'YES'
      args += ['-g'] if @configuration == 'Debug'
      args += ['-opt'] if @configuration == 'Release'
      args += @modules.select { |m| m.fetch('kind') == 'bridge' }.map { |m| m.fetch('kotlin') }
      args += inputs.flat_map { |m| ['-library', m.fetch('path')] }
      archive = File.join(@package, 'libMobiNative.a')
      stamp = File.join(@output, 'native-cache.json')
      sdk = command('native-sdk', ['/usr/bin/xcrun', '--sdk', @platform, '--show-sdk-build-version']).strip
      files = inputs.map { |m| m.fetch('path') } + @modules.select { |m| m.fetch('kind') == 'bridge' }.map { |m| m.fetch('kotlin') }
      signature = Digest::SHA256.hexdigest(JSON.generate([args, sdk, files.map { |p| [p, Digest::SHA256.file(p).hexdigest] }]))
      cached = File.file?(stamp) ? JSON.parse(File.read(stamp)) : {}
      if cached['signature'] == signature && File.file?(archive) && cached['archive_sha256'] == Digest::SHA256.file(archive).hexdigest
        puts '[swift-export] Reusing verified native archive for unchanged inputs'
        return
      end
      command('native', args)
      File.write(stamp, JSON.pretty_generate({ 'signature' => signature, 'archive_sha256' => Digest::SHA256.file(archive).hexdigest,
                                               'argv' => args, 'sdk' => sdk }) + "\n")
    end

    def swift_modules
      sdk = command('sdk', ['/usr/bin/xcrun', '--sdk', @platform, '--show-sdk-path']).strip
      triple = 'arm64-apple-ios' + ENV.fetch('IPHONEOS_DEPLOYMENT_TARGET', '26.0') + (@platform == 'iphonesimulator' ? '-simulator' : '')
      compiled = []
      while compiled.length < @modules.length
        m = @modules.find { |item| !compiled.include?(item.fetch('name')) && (item.fetch('dependencies') - compiled).empty? }
        abort 'Unresolved Swift module order' unless m
        name = m.fetch('name')
        # IOS-08: re-run --strict-support on updates; no automatic fallback.
        mode = name == 'KotlinCoroutineSupport' && !ARGV.include?('--strict-support') ? '5' : '6'
        args = ['/usr/bin/xcrun', 'swiftc', '-sdk', sdk, '-target', triple, '-I', @package,
                '-module-cache-path', File.join(@output, 'module-cache'), '-swift-version', mode,
                '-package-name', 'MobiShared', '-emit-module', '-parse-as-library', '-emit-library', '-static',
                '-module-name', name, '-emit-module-path', File.join(@package, name + '.swiftmodule'),
                '-o', File.join(@package, 'lib' + name + '.a'),
                # IOS-07: generated implementation-only imports need this check.
                '-enable-experimental-feature', 'CheckImplementationOnly', m.fetch('swift')]
        args += [@configuration == 'Debug' ? '-g' : '-O']
        args += ['-warnings-as-errors'] if ARGV.include?('--strict-support')
        command('swift-' + name, args)
        compiled << name
      end
    end

    def call
      Dir.mktmpdir('mobi-swift-export-build-') do |temporary|
        # IOS-12 applies to KLib compilation and the native compiler too.
        options = [ENV['JAVA_TOOL_OPTIONS'], %Q(-Djava.io.tmpdir="#{temporary}")].compact.join(' ')
        @environment = {
          'TMPDIR' => temporary, 'JAVA_TOOL_OPTIONS' => options,
          # AND-02: use Toolchain's supported Maven Central mirror setting.
          'KOTLIN_DEFAULT_MAVEN_CENTRAL_URL' => ENV.fetch('KOTLIN_DEFAULT_MAVEN_CENTRAL_URL', 'https://maven-central.storage-download.googleapis.com/maven2')
        }
        inputs = libraries
        generate(inputs)
        native_archive(inputs)
        swift_modules
        File.write(File.join(@output, 'inputs.json'), JSON.pretty_generate(inputs.map do |item|
          item.merge('sha256' => Digest::SHA256.file(item.fetch('path')).hexdigest)
        end) + "\n")
        puts "[swift-export] Built one Kotlin archive and #{@modules.length} Swift modules"
      end
    end
  end
end

MobiSwiftExport::Build.new.call if $PROGRAM_NAME == __FILE__
