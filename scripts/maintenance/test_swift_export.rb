# frozen_string_literal: true

require 'minitest/autorun'
require_relative 'lib/swift_export/descriptor'
require_relative 'lib/swift_export/fixtures'

class SwiftExportTest < Minitest::Test
  ROOT = File.expand_path('../..', __dir__)
  PATH = 'scripts/maintenance/swift-export-inputs.json'
  D = Maintenance::SwiftExport::Descriptor

  def descriptor(root = ROOT, profile = 'coroutine-swift5', policy = 'main-confined')
    D.new(root: root, path: PATH, profile: profile, repository_policy: policy)
  end

  def with_source
    Dir.mktmpdir('mobi-swift-export-test-') do |root|
      data = JSON.parse(File.read(File.join(ROOT, PATH)))
      paths = data['inputs'].values.flatten + data['modules'].flat_map { |m| m['inputs'] } + data['native']['sources'] + data['native'].values_at('lock', 'plist', 'assets') + [data['native']['package'] + '/Package.swift', data['native']['package'] + '/Sources', PATH]
      D.inventory(ROOT, paths).each_key do |p|
        FileUtils.mkdir_p(File.dirname(File.join(root, p)))
        FileUtils.cp(File.join(ROOT, p), File.join(root, p), preserve: true)
      end
      yield root, data
    end
  end

  def write_descriptor(root, data)
    File.write(File.join(root, PATH), JSON.generate(data))
  end

  def test_explicit_profiles_and_policies
    [nil, '', 'all-swift6'].each { |p| assert_raises(Maintenance::Failure) { descriptor(ROOT, p) } }
    assert_raises(Maintenance::Failure) { descriptor(ROOT, 'coroutine-swift5', nil) }
    names = %w[KotlinCoroutineSupport KotlinRuntimeSupport MobiHome]
    assert_equal %w[5 6 6], descriptor.modes(names).values
    assert_equal %w[5 5 5], descriptor(ROOT, 'generated-swift5').modes(names).values
  end

  def test_same_path_content_and_api_removal_invalidate_identity
    with_source do |root, data|
      before = descriptor(root).inspection
      file = File.join(root, 'shared-feature-home/src/HomeFeatureService.kt')
      File.write(file, File.read(file).gsub('fun initialState', 'fun removedInitialState'))
      refute_equal before['identity'], descriptor(root).inspection['identity']
      File.unlink(file)
      refute descriptor(root).inspection['selected_files'].key?('shared-feature-home/src/HomeFeatureService.kt')
      data['modules'].reject! { |m| m['name'] == 'MobiUI' }
      write_descriptor(root, data)
      refute_equal before['identity'], descriptor(root).inspection['identity']
    end
  end

  def test_dependency_schema_settings_and_lock_changes_invalidate_identity
    with_source do |root, data|
      before = descriptor(root).inspection['identity']
      data['runtime_settings']['compose_jobs_per_owner'] = 2
      write_descriptor(root, data)
      refute_equal before, descriptor(root).inspection['identity']
      before = descriptor(root).inspection['identity']
      lock = File.join(root, data['native']['lock'])
      value = JSON.parse(File.read(lock)); value['pins'][0]['state']['revision'] = 'a' * 40
      File.write(lock, JSON.generate(value))
      refute_equal before, descriptor(root).inspection['identity']
    end
  end

  def test_invalid_closure_and_paths_refuse
    with_source do |root, data|
      data['modules'][0]['dependencies'] = ['Missing']
      write_descriptor(root, data)
      assert_raises(Maintenance::Failure) { descriptor(root) }
      data['modules'][0]['dependencies'] = ['MobiDI']
      write_descriptor(root, data)
      assert_raises(Maintenance::Failure) { descriptor(root) }
    end
    %w[/etc/passwd ../README.md a//b a/./b a/../b].each { |p| assert_raises(Maintenance::Failure) { D.safe(ROOT, p) } }
  end

  def test_symlink_files_and_directories_refuse
    with_source do |root, _|
      source = File.join(root, 'shared-core/src')
      File.symlink('/etc/passwd', File.join(source, 'escape.kt'))
      assert_raises(Maintenance::Failure) { descriptor(root).inspection }
      File.unlink(File.join(source, 'escape.kt'))
      File.symlink('/private/tmp', File.join(source, 'escape'))
      assert_raises(Maintenance::Failure) { descriptor(root).inspection }
    end
  end

  def test_materialization_preserves_declared_template_bytes
    Dir.mktmpdir('mobi-export-fixtures-', '/private/tmp') do |root|
      receipt = Maintenance::SwiftExport::Fixtures.materialize(ROOT, File.join(root, 'fixtures'))
      %w[ExportHarness.kt HomeFacade.kt RuntimeSettings.swift executor/Probe.swift].each do |name|
        value = receipt['files'].fetch(name)
        assert_equal name + '.template', value['source']
        assert_equal value['sha256'], Maintenance.file_sha(File.join(receipt['directory'], name))
      end
      assert_raises(Maintenance::Failure) { Maintenance::SwiftExport::Fixtures.materialize(ROOT, receipt['directory']) }
    end
  end
end
