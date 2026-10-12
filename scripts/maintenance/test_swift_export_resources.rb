# frozen_string_literal: true

require 'minitest/autorun'
require_relative 'adapters/kotlin_resources'

class SwiftExportResourcesTest < Minitest::Test
  def test_declared_project_identity_and_escaped_roots
    Dir.mktmpdir('mobi-export-resources-', '/private/tmp') do |root|
      store = Maintenance::RunStore.new(File.join(root, 'runs'))
      id = SecureRandom.hex(16)
      journal = store.allocate(id, {}, {})
      workspace = store.directory(journal, 'work/baseline')
      control = store.directory(journal, 'steps/native', disposable: false)
      nonce = SecureRandom.hex(16)
      Maintenance::KotlinResources.prepare(control: control, workspace: workspace, nonce: nonce)
      resources = Maintenance::KotlinResources.new(control, nonce)
      developer = File.join(root, 'Developer'); FileUtils.mkdir_p(developer)
      binary = File.join(developer, 'Toolchains/XcodeDefault.xctoolchain/usr/bin/clang')
      FileUtils.mkdir_p(File.dirname(binary)); File.write(binary, 'compiler fixture')
      project = File.join(workspace, 'output/native/Consumer.xcodeproj')
      FileUtils.mkdir_p(project); File.write(File.join(project, 'project.pbxproj'), 'project fixture')
      resources.register_xcode_project!(project, developer_dir: developer)
      identity = { 'uid' => Process.uid, 'command' => binary + ' -c ' + File.dirname(project) + '/App.swift' }
      assert_equal 'xcode_private_project', resources.native_child_proof(identity)['scope']
      foreign = identity.merge('command' => binary + ' -c ' + root + '/Foreign.swift')
      assert_nil resources.native_child_proof(foreign)
      outside = File.join(root, 'Foreign.xcodeproj'); FileUtils.mkdir_p(outside); File.write(File.join(outside, 'project.pbxproj'), 'foreign')
      assert_raises(Maintenance::Failure) { resources.register_xcode_project!(outside, developer_dir: developer) }
      File.write(File.join(project, 'project.pbxproj'), 'changed')
      assert_raises(Maintenance::Failure) { resources.native_child_proof(identity) }
    end
  end
end
