# frozen_string_literal: true
require_relative 'lib/executor'
require_relative 'lib/compatibility_report'
root = File.expand_path('../..', __dir__)
files = ARGV
raise Maintenance::Failure, "Supply baseline and candidate APKs" unless files.size == 2
source = Maintenance::Source.new(root)
version_inputs = []
files.each_with_index do |file, index|
  phase = index.zero? ? "baseline" : "candidate"
  run_root = File.realpath(file).split("/work/").first
  journal = JSON.parse(File.read(run_root + ".json"))
  producer_store = Maintenance::RunStore.new(File.dirname(run_root))
  producer = Maintenance::CompatibilityReport.read(producer_store, File.basename(run_root))
  raise Maintenance::Failure, 'Only completed upstream mobile producers are supported' unless producer['state'] == 'checks_passed' && journal.dig('binding', 'adapter') == 'compatibility-upstream-mobile'
  raise Maintenance::Failure, "Producer source mismatch" unless journal.dig("binding", "source_sha256") == Maintenance.digest(source.files)
  log = File.join(run_root, "steps", phase + "-upstream-mobile", "version.log")
  expected = index.zero? ? "0.12.2" : "0.13.0"
  project = File.join(run_root, 'work', phase, 'output/project')
  relative = File.realpath(file).delete_prefix(project + '/')
  products_file = File.join(run_root, 'steps', phase + '-upstream-mobile', 'products.json')
  products = JSON.parse(File.read(products_file))
  raise Maintenance::Failure, 'APK is outside the verified producer products' unless relative != File.realpath(file) && products[relative] == Maintenance.file_sha(file)
  raise Maintenance::Failure, "Producer version mismatch" unless File.read(log).include?("Kotlin Toolchain version " + expected + " ")
  version_inputs << log
  version_inputs += [products_file, producer_store.path(File.basename(run_root), '.result.json')]
end
raise Maintenance::Failure, 'Supply baseline and candidate APKs' unless files.size == 2
sdk = File.join(Dir.home, 'Library/Android/sdk')
host = { 'schema' => 1, 'sdk' => File.realpath(sdk), 'apks' => %w[baseline candidate].each_with_index.to_h { |phase, n| [phase, { 'path' => File.realpath(files[n]), 'sha256' => Maintenance.file_sha(files[n]), 'version' => n.zero? ? '0.12.2' : '0.13.0' }] }, 'adb_sha256' => Maintenance.file_sha(File.join(sdk, 'platform-tools/adb')), 'emulator_sha256' => Maintenance.file_sha(File.join(sdk, 'emulator/emulator')), 'image_sha256' => Maintenance.file_sha(File.join(sdk, 'system-images/android-36/google_apis/arm64-v8a/source.properties')) }
inputs = File.join(root, '.maintenance/runtime-inputs'); FileUtils.mkdir_p(inputs)
host_path = File.join(inputs, Maintenance.digest(host) + '.runtime-input.json'); Maintenance::RunStore.atomic(host_path, host)
check = File.join(__dir__, 'android_runtime_check.rb')
klass = Struct.new(:plan, :code_files)
plan = { 'schema' => 1, 'id' => 'android-minimum-runtime', 'scope' => 'baseline_candidate_apk_api_36_install_launch', 'resource_types' => %w[filesystem process-group], 'edits' => [], 'missing_capabilities' => %w[physical_device comprehensive_android_runtime signed_release direct_toolchain_parity], 'checks' => [{ 'id' => 'android-runtime', 'required' => true, 'timeout_seconds' => 360, 'argv' => [File.realpath(RbConfig.ruby), check, '{source}', '{output}', '{cache}', host_path] }] }
adapter = klass.new(plan, [__FILE__, check, host_path, *files, *version_inputs, File.join(sdk, 'platform-tools/adb'), File.join(sdk, 'emulator/emulator'), File.join(sdk, 'system-images/android-36/google_apis/arm64-v8a/source.properties')])
policy_path = File.join(root, 'maintenance-execution-policy.json')
result = Maintenance::Executor.new(source: Maintenance::Source.new(root), adapter: adapter, store: Maintenance::RunStore.new(File.join(root, '.maintenance/runs-adoption-runtime')), policy: JSON.parse(File.read(policy_path)), input_files: [policy_path]).run
puts JSON.pretty_generate(result)
exit Maintenance::Executor::EXIT_CODES.fetch(result['state'])
