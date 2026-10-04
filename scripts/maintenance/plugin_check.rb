# frozen_string_literal: true

require_relative 'lib/plugin_attribution'
require_relative 'adapters/kotlin_resources'

module Maintenance
if $PROGRAM_NAME == __FILE__
  source, output, cache, input_file, host_file = ARGV
  control = File.dirname(ENV.fetch('MOBI_RESULT_PATH'))
  phase = ENV.fetch('MOBI_PHASE')
  state = 'refused'
  begin
    tree = lambda do
      Dir.glob(File.join(source, '**', '*'), File::FNM_DOTMATCH).reject { |p| %w[. ..].include?(File.basename(p)) || File.directory?(p) && !File.symlink?(p) }.sort.to_h do |p|
        raise Failure, 'Unsafe copied plugin source' unless File.file?(p) && !File.symlink?(p)
        [p.delete_prefix(source + '/'), { 'sha256' => Maintenance.file_sha(p), 'executable' => (File.stat(p).mode & 0o111) != 0 }]
      end
    end
    manifest = tree.call
    resources = KotlinResources.new(control, ENV.fetch('MOBI_RESOURCE_NONCE'))
    input = JSON.parse(File.read(input_file)); host = JSON.parse(File.read(host_file))
    project = File.join(output, 'plugin-resolver'); Dir.mkdir(project)
    FileUtils.mkdir_p(File.join(project, 'gradle/wrapper'))
    FileUtils.cp(File.join(source, 'gradle-bridge/gradlew'), File.join(project, 'gradlew'))
    FileUtils.cp(File.join(source, 'gradle-bridge/gradle/wrapper/gradle-wrapper.jar'), File.join(project, 'gradle/wrapper/gradle-wrapper.jar'))
    properties = File.read(File.join(source, 'gradle-bridge/gradle/wrapper/gradle-wrapper.properties'))
    pin = input.fetch('config').fetch('gradle')
    raise Failure, 'Unreviewed assessment Gradle distribution' unless properties.include?("gradle-#{pin.fetch('version')}-bin.zip") && pin.fetch('distribution_sha256').match?(/\A[0-9a-f]{64}\z/)
    File.write(File.join(project, 'gradle/wrapper/gradle-wrapper.properties'), properties + "\ndistributionSha256Sum=#{pin['distribution_sha256']}\n")
    File.write(File.join(project, 'settings.gradle'), "rootProject.name = 'mobi-plugin-resolver'\n")
    FileUtils.cp(File.join(source, 'scripts/maintenance/adapters/plugin_resolution.gradle'), File.join(project, 'build.gradle'))
    RunStore.atomic(File.join(project, 'roots.json'), input.fetch('phases').fetch(phase).fetch('configuration').fetch('roots'))
    RunStore.atomic(File.join(control, 'input.json'), input)
    environment = { 'PATH' => '/usr/bin:/bin', 'HOME' => ENV.fetch('HOME'), 'TMPDIR' => ENV.fetch('TMPDIR'), 'JAVA_HOME' => host.fetch('java_home'),
                    'GRADLE_USER_HOME' => File.join(cache, 'gradle'), 'JAVA_TOOL_OPTIONS' => resources.tag, 'LANG' => 'C', 'LC_ALL' => 'C' }
    argv = [File.join(project, 'gradlew'), '--no-daemon', '--console=plain', '--no-configuration-cache', 'resolvePlugins']
    log = File.join(control, 'resolver.log')
    # Keep descendants in the executor-owned process group for timeout/recovery.
    status = File.open(log, 'w') do |stream|
      pid = Process.spawn(environment, *argv, chdir: project, unsetenv_others: true, out: stream, err: stream)
      Process.wait2(pid).last
    end
    resources.observe!
    resolver = File.join(project, 'resolver.json')
    FileUtils.cp(resolver, File.join(control, 'resolver.json')) if File.file?(resolver) && !File.symlink?(resolver)
    state = 'infrastructure'
    raise Failure, 'Independent plugin resolver failed; inspect retained log' unless status.success?
    state = 'refused'
    graph = JSON.parse(File.read(File.join(control, 'resolver.json')))
    attribution = PluginAttribution.join(input, phase, graph)
    RunStore.atomic(File.join(control, 'attribution.json'), attribution)
    raise Failure, 'Copied plugin source changed' unless tree.call == manifest
    evidence = { 'schema' => 1, 'phase' => phase, 'source_preservation' => 'verified', 'adoption_authorized' => false,
                 'argv' => ['gradlew'] + argv.drop(1), 'log_sha256' => Maintenance.file_sha(log) }
    %w[input resolver attribution].each { |name| evidence[name + '_sha256'] = Maintenance.file_sha(File.join(control, name + '.json')) }
    RunStore.atomic(File.join(control, 'evidence.json'), evidence)
    state = 'passed'
  rescue StandardError => error
    warn error.message
  ensure
    check = { 'schema' => 1, 'check' => 'plugin-attribution', 'phase' => phase, 'status' => state }
    check['evidence_sha256'] = Maintenance.file_sha(File.join(control, 'evidence.json')) if state == 'passed'
    RunStore.atomic(ENV.fetch('MOBI_RESULT_PATH'), check)
  end
  exit(state == 'passed' ? 0 : 23)
end
end
