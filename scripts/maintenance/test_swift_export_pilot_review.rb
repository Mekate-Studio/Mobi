# frozen_string_literal: true

require 'minitest/autorun'
require_relative 'lib/swift_export_pilot/review'

class SwiftExportPilotReviewTest < Minitest::Test
  SOURCE = 'a' * 64
  TUPLE = 'b' * 64

  def with_settings
    Dir.mktmpdir('mobi-pilot-review-') do |root|
      path = File.join(root, 'settings.json')
      record = { 'schema' => 1, 'status' => 'experimental', 'source_identity' => SOURCE, 'tuple_identity' => TUPLE,
                 'limits' => Maintenance::SwiftExportPilot::Review::LIMITS.to_h { |key| [key, 1] },
                 'busy_retry_behavior' => 'reject-before-registration-and-manual-retry', 'rationale' => 'Provisional experiment; no accepted runtime limits.' }
      File.write(path, JSON.generate(record))
      yield path, record, root
    end
  end

  def read(path, qualified: false, source: SOURCE)
    Maintenance::SwiftExportPilot::Review.settings(path, source_identity: source, tuple_identity: TUPLE, qualified: qualified)
  end

  def test_experiments_do_not_qualify_or_cover_changed_sources
    with_settings do |path, record, _root|
      assert_equal 'experimental', read(path)['status']
      assert_raises(Maintenance::Failure) { read(path, qualified: true) }
      assert_raises(Maintenance::Failure) { read(path, source: 'c' * 64) }
      record['limits']['native_jobs_per_owner'] = 0
      File.write(path, JSON.generate(record))
      assert_raises(Maintenance::Failure) { read(path) }
    end
  end

  def test_reviewed_settings_require_complete_unchanged_real_app_receipts
    with_settings do |path, record, root|
      measured = { 'source_identity' => SOURCE, 'tuple_identity' => TUPLE, 'scope' => 'real-app-pilot',
                   'observations' => %w[cancellation retry background_foreground overlapping_owners retained_objects retained_jobs sustained_polling latency_distributions].to_h { |key| [key, { 'samples' => [1] }] } }
      receipt = File.join(root, 'measurement.json'); File.write(receipt, JSON.generate(measured))
      record.merge!('status' => 'reviewed', 'reviewer' => 'Test reviewer', 'measurements' => [{ 'path' => receipt, 'sha256' => Maintenance.file_sha(receipt) }])
      File.write(path, JSON.generate(record))
      assert_equal 'reviewed', read(path, qualified: true)['status']
      File.write(receipt, JSON.generate(measured.merge('scope' => 'fixture')))
      assert_raises(Maintenance::Failure) { read(path, qualified: true) }
      record['measurements'][0]['sha256'] = Maintenance.file_sha(receipt); File.write(path, JSON.generate(record))
      assert_raises(Maintenance::Failure) { read(path, qualified: true) }
    end
  end

  def test_dispositions_cannot_cover_unknown_or_changed_findings
    finding = { 'fingerprint' => 'd' * 64, 'emitter' => 'compiler', 'profile' => 'coroutine-swift5', 'target' => 'simulator', 'message' => 'cast', 'location' => 'generated.swift:1' }
    accepted = finding.merge('disposition' => 'accepted_for_pilot', 'rationale' => 'Test disposition only', 'reviewer' => 'Test reviewer', 'requalification_trigger' => 'Any input change')
    records = { 'schema' => 1, 'source_identity' => SOURCE, 'tuple_identity' => TUPLE, 'findings' => [accepted] }
    review = ->(findings) { Maintenance::SwiftExportPilot::Review.dispositions(findings, records, source_identity: SOURCE, tuple_identity: TUPLE) }
    assert_equal 'accepted_for_pilot', review.call([finding]).first['disposition']
    assert_equal 'review_required', review.call([finding.merge('fingerprint' => 'e' * 64)]).first['disposition']
    assert_equal 'review_required', review.call([finding.merge('profile' => 'generated-swift5')]).first['disposition']
    records['findings'] << accepted
    assert_raises(Maintenance::Failure) { review.call([finding]) }
  end
end
