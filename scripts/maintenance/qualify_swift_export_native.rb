# frozen_string_literal: true

require_relative 'lib/swift_export_pilot/qualification'

exit Maintenance::SwiftExportPilot::Qualification.new(root: File.expand_path('../..', __dir__),
                                                     output: '.maintenance/native-hosted-qualification', java_home: ENV['JAVA_HOME']).run
