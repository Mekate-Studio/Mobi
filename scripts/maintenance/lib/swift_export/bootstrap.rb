# frozen_string_literal: true

gem 'xcodeproj', '=1.28.1'
require 'xcodeproj'
require 'fileutils'
folder,base=ARGV
FileUtils.mkdir_p(folder)
FileUtils.cp(File.join(base,'AccessibilityBootstrap.swift.txt'),File.join(folder,'AccessibilityBootstrap.swift'))
project=Xcodeproj::Project.new(File.join(folder,'AccessibilityBootstrap.xcodeproj'))
target=project.new_target(:ui_test_bundle,'AccessibilityBootstrap',:ios,'26.0')
target.add_file_references([project.main_group.new_file('AccessibilityBootstrap.swift')])
target.build_configurations.each do |config|
  config.build_settings.merge!('GENERATE_INFOPLIST_FILE'=>'YES','PRODUCT_BUNDLE_IDENTIFIER'=>'studio.mekate.mobi.maintenance.AccessibilityBootstrap','SWIFT_VERSION'=>'6.0','CODE_SIGNING_ALLOWED'=>'NO','TARGETED_DEVICE_FAMILY'=>'1,2','SDKROOT'=>'iphonesimulator')
end
project.save
scheme=Xcodeproj::XCScheme.new
scheme.add_build_target(target);scheme.add_test_target(target)
scheme.save_as(project.path,'AccessibilityBootstrap',true)
