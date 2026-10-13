# frozen_string_literal: true

require 'minitest/autorun'
require_relative 'lib/swift_export/macro_approvals'

class SwiftExportMacroApprovalsTest < Minitest::Test
  M = Maintenance::SwiftExport::MacroApprovals

  def with_workspace
    Dir.mktmpdir do |root|
      root = File.realpath(root)
      home = File.join(root, 'home'); Dir.mkdir(home)
      pins = M::TARGETS.keys.map { |identity| { 'identity' => identity, 'state' => { 'revision' => 'a' * 40 } } }
      heads = M::TARGETS.keys.to_h { |identity| [identity, 'a' * 40] }
      yield root, home, pins, heads
    end
  end

  def test_only_exact_locked_macro_targets_are_approved_in_owned_home
    with_workspace do |root, home, pins, heads|
      record = M.install(workspace: root, home: home, pins: pins, checkout_heads: heads)
      assert_equal 'enabled', record['validation']
      assert_equal M::TARGETS.values.sort, record['records'].map { |entry| entry['targetName'] }.sort
      assert record['records'].all? { |entry| entry['fingerprint'] == 'a' * 40 }
      assert_equal record['records'], JSON.parse(File.read(record['path']))
      assert_equal Maintenance.file_sha(record['path']), record['sha256']
      assert record['path'].start_with?(home + '/')
    end
  end

  def test_drift_and_missing_or_duplicate_locks_refuse_before_approval
    with_workspace do |root, home, pins, heads|
      changed = heads.merge(M::TARGETS.keys.first => 'b' * 40)
      [ [pins, changed], [pins.drop(1), heads], [pins + [pins.first], heads] ].each do |locked, actual|
        assert_raises(Maintenance::Failure) { M.install(workspace: root, home: home, pins: locked, checkout_heads: actual) }
        refute File.exist?(File.join(home, 'Library'))
      end
    end
  end

  def test_unowned_home_and_escaping_security_store_refuse
    with_workspace do |root, home, pins, heads|
      Dir.mktmpdir do |outside|
        assert_raises(Maintenance::Failure) { M.install(workspace: root, home: outside, pins: pins, checkout_heads: heads) }
        File.symlink(outside, File.join(home, 'Library'))
        assert_raises(Maintenance::Failure) { M.install(workspace: root, home: home, pins: pins, checkout_heads: heads) }
        assert_empty Dir.children(outside)
      end
    end
  end

  def test_bypassed_validation_or_unowned_foundation_home_refuses
    with_workspace do |root, home, _pins, _heads|
      text = 'MOBI_MACRO_PREFERENCES=' + JSON.generate('foundation_home' => home, 'library_directory' => File.join(home, 'Library'), 'skip_macro_validation' => false)
      assert_equal false, M.verify_environment(text, home: home)['skip_macro_validation']
      assert_raises(Maintenance::Failure) { M.verify_environment(text.sub('false', 'true'), home: home) }
      assert_raises(Maintenance::Failure) { M.verify_environment('MOBI_MACRO_PREFERENCES=' + JSON.generate('foundation_home' => root, 'library_directory' => File.join(root, 'Library'), 'skip_macro_validation' => false), home: home) }
      assert_raises(Maintenance::Failure) { M.verify_environment('', home: home) }
    end
  end
end
