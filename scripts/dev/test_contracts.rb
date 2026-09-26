# frozen_string_literal: true

require 'rbconfig'

root = File.expand_path('../..', __dir__)
%w[scripts/dev/test_quality.rb scripts/dev/test_validate.rb scripts/maintenance/test_inventory.rb scripts/maintenance/test_executor.rb].each do |suite|
  puts "[contracts] #{suite} (Ruby #{RUBY_VERSION})"
  exit 1 unless system(RbConfig.ruby, File.join(root, suite), chdir: root)
end
