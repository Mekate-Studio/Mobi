# frozen_string_literal: true

require 'minitest/autorun'
require_relative 'lib/swift_export_pilot/qualification'

class SwiftExportNativeQualificationTest < Minitest::Test
  class Fixture < Maintenance::SwiftExportPilot::Qualification
    attr_reader :actions
    attr_accessor :failed_cold, :failed_cleanup, :missing_test

    def prepare
      FileUtils.mkdir_p(@output)
      @prepared = true
      @actions = []
      @source = Object.new
      def @source.verify!; end
    end

    def git(*); ''; end

    def execute(action, delivery: nil, origin: nil)
      @actions << action
      raise 'Replay must consume retained original archive' if action == 'replay' && (delivery != 'retained-original' || origin != 'cold-origin')
      entry = { 'action' => action, 'run_id' => 'cold-origin', 'state' => failed_cold ? 'inconclusive' : 'checks_passed' }
      @runs << entry
      entry
    end

    def retain(entry)
      entry['phases'] = %w[baseline candidate].map { |phase| { 'status' => 'passed', 'tests_passed' => !missing_test, 'delivery' => phase == 'baseline' ? 'retained-original' : 'retained-reordered', 'delivery_identity' => 'sealed' } }
      File.write(File.join(@output, 'retained-diagnostic.log'), 'native diagnostic')
      File.chmod(0o700, File.join(@output, 'retained-diagnostic.log'))
    end

    def cleanup(entry)
      raise Maintenance::Failure, 'ownership uncertain' if failed_cleanup
      @actions << 'cleanup'
      entry['cleanup'] = { 'state' => 'cleaned' }
    end

    def export_runs; end
  end

  def with_fixture
    Dir.mktmpdir do |root|
      fixture = Fixture.new(root: root, output: '.maintenance/evidence', java_home: nil)
      yield fixture, File.join(root, '.maintenance/evidence')
    end
  end

  def test_cold_failure_retains_evidence_and_prevents_replay
    with_fixture do |fixture, output|
      fixture.failed_cold = true
      assert_equal 23, fixture.run
      assert_equal ['test'], fixture.actions
      assert File.file?(File.join(output, 'retained-diagnostic.log'))
      report = JSON.parse(File.read(File.join(output, 'report.json')))
      assert_equal 'incomplete', report['status']
      assert_equal false, report['adoption_authorized']
      extracted = File.join(output, 'downloaded')
      Dir.mkdir(extracted)
      assert system('/usr/bin/tar', '-xzf', File.join(output, 'evidence.tar.gz'), '-C', extracted)
      assert_equal 0o700, File.stat(File.join(extracted, 'retained-diagnostic.log')).mode & 0o777
    end
  end

  def test_missing_tests_or_cleanup_refusal_prevents_replay
    %i[missing_test failed_cleanup].each do |failure|
      with_fixture do |fixture, output|
        fixture.public_send("#{failure}=", true)
        assert_equal 23, fixture.run
        refute_includes fixture.actions, 'replay'
        assert_equal 'incomplete', JSON.parse(File.read(File.join(output, 'report.json')))['status']
      end
    end
  end

  def test_replay_only_after_cleanup_and_remains_review_required
    with_fixture do |fixture, output|
      assert_equal 0, fixture.run
      assert_equal %w[test cleanup replay cleanup], fixture.actions
      report = JSON.parse(File.read(File.join(output, 'report.json')))
      assert_equal 'checks_passed_review_required', report['status']
      assert_includes report['external_gates'], 'limits_review'
      assert_equal false, report['adoption_authorized']
    end
  end

  def test_dirty_checkout_refuses_before_creating_evidence
    Dir.mktmpdir do |root|
      assert system('/usr/bin/git', '-C', root, 'init', '-q')
      File.write(File.join(root, 'untracked'), 'dirty')
      fixture = Maintenance::SwiftExportPilot::Qualification.new(root: root, output: '.maintenance/evidence', java_home: nil)
      assert_equal 23, fixture.run
      refute File.exist?(File.join(root, '.maintenance'))
    end
  end

  def test_selected_xcode_alias_resolves_and_invalid_selection_refuses
    Dir.mktmpdir do |root|
      developer = File.join(root, 'Xcode_27.app/Contents/Developer')
      FileUtils.mkdir_p(File.join(developer, 'usr/bin'))
      executable = File.join(developer, 'usr/bin/xcodebuild')
      File.write(executable, '#!/bin/sh')
      File.chmod(0o755, executable)
      alias_path = File.join(root, 'Xcode.app')
      File.symlink(File.join(root, 'Xcode_27.app'), alias_path)
      assert_equal File.realpath(developer), Maintenance::SwiftExport::ToolIdentity.developer_dir(File.join(alias_path, 'Contents/Developer'))
      assert_raises(Maintenance::Failure) { Maintenance::SwiftExport::ToolIdentity.developer_dir(root) }
      assert_raises(Maintenance::Failure) { Maintenance::SwiftExport::ToolIdentity.developer_dir('relative') }
    end
  end

  def test_escaping_or_symlinked_evidence_refuses_before_writes
    Dir.mktmpdir do |root|
      Dir.mktmpdir do |outside|
        File.symlink(outside, File.join(root, '.maintenance'))
        [outside, '.maintenance/evidence'].each do |output|
          fixture = Maintenance::SwiftExportPilot::Qualification.new(root: root, output: output, java_home: nil)
          def fixture.git(*); ''; end
          assert_equal 23, fixture.run
          assert_empty Dir.children(outside)
        end
      end
    end
  end
end
