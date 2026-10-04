# frozen_string_literal: true

require 'rbconfig'

root = File.expand_path('../..', __dir__)
%w[scripts/dev/test_quality.rb scripts/dev/test_validate.rb scripts/maintenance/test_inventory.rb scripts/maintenance/test_executor.rb scripts/maintenance/test_kotlin_rehearsal.rb scripts/maintenance/test_support_policy.rb scripts/maintenance/test_compatibility.rb scripts/maintenance/test_watch.rb scripts/maintenance/test_upgrade_graph.rb scripts/maintenance/test_direct_roundtrip.rb scripts/maintenance/test_direct_resolution.rb scripts/maintenance/test_build_inputs.rb scripts/maintenance/test_plugin_attribution.rb scripts/maintenance/test_bundled_attribution.rb scripts/maintenance/test_adoption_gates.rb scripts/maintenance/test_jetifier_conditions.rb].each do |suite|
  puts "[contracts] #{suite} (Ruby #{RUBY_VERSION})"
  exit 1 unless system(RbConfig.ruby, File.join(root, suite), chdir: root)
end
