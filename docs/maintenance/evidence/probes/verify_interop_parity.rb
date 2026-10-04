# frozen_string_literal: true

# Manual derived evidence over the existing owned compatibility producers.
# Usage: pinned-ruby verify_interop_parity.rb ASSESSMENT_SOURCE ORIGINAL_REPO RUN_ID
require 'json'
require 'digest'

assessment, original, id = ARGV
abort 'Expected assessment source, original repository and exact run ID' unless ARGV.size == 3 && id.match?(/\A[0-9a-f]{32}\z/)
assessment = File.realpath(assessment)
original = File.realpath(original)
require File.join(original, 'scripts/maintenance/lib/compatibility_report')

store = Maintenance::RunStore.new(File.join(assessment, '.maintenance/runs-interop-parity'))
report = Maintenance::CompatibilityReport.read(store, id)
raise Maintenance::Failure, 'Both native phases must pass' unless report['state'] == 'checks_passed' && report['phases'].map { |p| p['phase'] }.sort == %w[baseline candidate]
source = Maintenance::Source.new(assessment)
raise Maintenance::Failure, 'Assessment source differs from measured snapshot' unless Maintenance.digest(source.files) == report.dig('binding', 'source_sha256')

prior_id = '96942bc52fc76b115913cf5011cc6bf4'
prior_store = Maintenance::RunStore.new(File.join(original, '.maintenance/runs-adoption-direct'))
prior = Maintenance::CompatibilityReport.read(prior_store, prior_id)
raise Maintenance::Failure, 'Original consumer producer did not pass' unless prior['state'] == 'checks_passed'
prior_cases = JSON.parse(File.read(File.join(prior_store.path(prior_id), 'steps/baseline-direct-roundtrip/native-test-cases.json')))
fixture_root = __dir__
golden = JSON.parse(File.read(File.join(fixture_root, 'MobiInteropParity.original-cases.json')))
raise Maintenance::Failure, 'Original consumer identities differ from verified producer' unless golden == prior_cases && golden.size == 12

fixture_paths = {
  'shared-di/src/MobiInteropParity.kt' => 'MobiInteropParity.kt.template',
  'ios-app/tests/Maintenance/MobiInteropParityTests.swift' => 'MobiInteropParityTests.swift.template'
}
fixtures = fixture_paths.to_h do |path, name|
  identity = { 'sha256' => Maintenance.file_sha(File.join(fixture_root, name)), 'executable' => false }
  raise Maintenance::Failure, 'Current fixture source differs from reviewed template' unless source.files.fetch(path) == identity
  [path, identity]
end
cases = %w[
  typedStatePayloadsSurviveNativeAdapters()
  genericPayloadRetainsItsTypeAndIdentity()
  realSuspendClientsPreserveSuccessAndFailurePayloads()
  kotlinCancellationThrowsAndCurrentClientMapsItToUnexpected()
  swiftTaskCancellationLeavesKotlinWorkPendingUntilExplicitCompletion()
  completedContinuationIsReleasedAndSecondCycleIsFresh()
].map { |name| 'MobiInteropParityTests/' + name }.sort

phases = %w[baseline candidate].to_h do |phase|
  control = File.join(store.path(id), 'steps', phase + '-direct-facade')
  evidence = JSON.parse(File.read(File.join(control, 'evidence.json')))
  manifest = JSON.parse(File.read(File.join(control, evidence.fetch('source-manifest').fetch('file'))))
  raise Maintenance::Failure, 'Phase fixture bytes or modes differ' unless fixtures.all? { |path, identity| manifest.fetch(path) == identity }
  measured_cases = JSON.parse(File.read(File.join(control, evidence.fetch('native-test-cases').fetch('file'))))
  log_cases = File.read(File.join(control, 'ios-test.log')).scan(/^Test case '([^']+)' passed on /).flatten.uniq.sort
  raise Maintenance::Failure, 'Native case manifest differs from executed log' unless measured_cases == log_cases
  raise Maintenance::Failure, 'Named fixture or original consumer is missing' unless (golden + cases).sort == measured_cases
  android_counts = File.read(File.join(control, 'android-test.log')).scan(/\[\s*(\d+) tests successful/).flatten.map(&:to_i)
  raise Maintenance::Failure, 'Original Android test count is missing' unless android_counts.sum == 38
  row = report['phases'].find { |p| p['phase'] == phase }
  raise Maintenance::Failure, 'Direct bridge absence is unverified' if phase == 'candidate' && row['bridge_unavailable'] != true
  if phase == 'candidate'
    changes = JSON.parse(File.read(File.join(control, evidence.fetch('experiment-transformations').fetch('file'))))
    raise Maintenance::Failure, 'Direct transformation changed the shared fixtures' unless (changes.map { |c| c['path'] } & fixtures.keys).empty?
  end
  [phase, { 'evidence_sha256' => row['evidence_sha256'], 'native_cases' => measured_cases,
            'android_test_count' => android_counts.sum,
            'fixture_identities' => fixtures, 'bridge_unavailable' => row['bridge_unavailable'],
            'cells' => row['cells'], 'source_preservation' => row['source_preservation'] }]
end
journal = store.load(id)
recovery = Maintenance::Recovery.new(store).recover(id)
disposable = journal.fetch('resources').select { |r| r['disposable'] }
raise Maintenance::Failure, 'Owned recovery or cleanup is incomplete' unless recovery['state'] == 'quiescent' && !disposable.empty? && disposable.all? { |r| r['state'] == 'removed' && !File.exist?(store.safe_path(journal, r['path'])) }
cleanup = { 'state' => 'cleaned', 'removed_paths' => disposable.map { |r| r['path'] }, 'evidence_retained' => true }
source.verify!
puts JSON.pretty_generate({
  'schema' => 1, 'state' => 'bounded_interop_pair_passed', 'run_id' => id, 'store' => 'interop-parity',
  'result_sha256' => report['result_sha256'], 'source_sha256' => report.dig('binding', 'source_sha256'),
  'producer_binding' => report['binding'], 'phases' => phases,
  'original_consumer_producer' => { 'run_id' => prior_id, 'result_sha256' => prior['result_sha256'], 'cases' => golden },
  'derivation' => { 'file' => File.basename(__FILE__), 'sha256' => Maintenance.file_sha(__FILE__) },
  'recovery' => recovery, 'cleanup' => cleanup, 'bridge_retirement' => 'defer', 'adoption_authorized' => false,
  'remaining_capabilities' => report['missing_capabilities'],
  'limits' => ['One explicitly typed generic class and controlled standard-library continuation only',
               'Swift task cancellation and Kotlin cancellation/client mapping remain characterized behavior, not a feature fix',
               'Continuation-slot reuse is not deallocation, leak, arbitrary coroutine-job or universal lifecycle proof',
               'Prepared local host; direct hosted, onboarding, device/floor and release proof remain independent']
})
