# frozen_string_literal: true

require_relative 'adapter'
require_relative '../swift_export/assemble'
require_relative '../executor'
require_relative '../recovery'

module Maintenance
  module SwiftExportPilot
    class Qualification
      def initialize(root:, output:, java_home:)
        @root = File.realpath(root)
        @output = File.expand_path(output, @root)
        @java_home = java_home
        @runs = []
        @report = { 'schema' => 1, 'status' => 'incomplete', 'adoption_authorized' => false,
                    'scope' => 'native-only-cold-and-guarded-replay', 'settings_status' => 'experimental', 'simulator_major' => 27,
                    'external_gates' => %w[production_default device minimum_runtime android_parity signed_release advisory_review diagnostic_review limits_review],
                    'cold_boundary' => 'fresh run-owned products; host tools and dependency caches may be read',
                    'hosted' => ENV['GITHUB_ACTIONS'] == 'true', 'github_run_id' => ENV['GITHUB_RUN_ID'], 'runs' => @runs }
      end

      def git(*args)
        text, status = Open3.capture2e('/usr/bin/git', '-C', @root, *args)
        raise Failure, 'Cannot inspect qualification checkout' unless status.success?
        text.strip
      end

      def prepare
        raise Failure, 'Qualification requires a clean committed checkout' unless git('status', '--porcelain').empty?
        relative = @output.delete_prefix(@root + '/')
        raise Failure, 'Evidence must be a new ignored workspace directory' unless relative.start_with?('.maintenance/') && !relative.split('/').include?('..') && !File.exist?(@output)
        cursor = @output
        loop do
          raise Failure, 'Evidence path has a symlink ancestor' if File.symlink?(cursor)
          break if cursor == @root
          cursor = File.dirname(cursor)
        end
        raise Failure, 'Evidence path is not ignored' unless system('/usr/bin/git', '-C', @root, 'check-ignore', '-q', relative)
        FileUtils.mkdir_p(@output)
        @prepared = true
        @report['commit'] = git('rev-parse', 'HEAD')
        @source = Source.new(@root)
        write('source-manifest.json', @source.files)
        @report['source_manifest_sha256'] = Maintenance.file_sha(File.join(@output, 'source-manifest.json'))
        raise Failure, 'Qualification requires Ruby 4.0.6' unless RUBY_VERSION == '4.0.6'
        raise Failure, 'Explicit JDK 26 installation required' unless @java_home && File.executable?(File.join(@java_home, 'bin/java'))
        java_text, java_status = Open3.capture2e(File.join(@java_home, 'bin/java'), '-version')
        @report['java_version'] = java_text.strip
        raise Failure, 'Qualification requires JDK 26' unless java_status.success? && java_text.match?(/version "26(?:[.\"])/)
        @descriptor = Descriptor.new(root: @root, profile: 'coroutine-swift5', repository_policy: 'main-confined', compose: 'disabled', simulator_major: 27)
        tools = SwiftExport::ToolIdentity.capture(File.realpath(File.join(@java_home, 'bin/java')))
        ENV['DEVELOPER_DIR'] = tools.fetch('developer_dir')
        @report['tools'] = tools
        available = JSON.parse(SwiftExport::ToolIdentity.command(['/usr/bin/xcrun', 'simctl', 'list', 'runtimes', '--json'], developer: tools.fetch('developer_dir'))).fetch('runtimes')
        @report['simulator_runtimes'] = available.select { |runtime| runtime['isAvailable'] && runtime.fetch('identifier', '').include?('.iOS-') }
        raise Failure, 'Hosted qualification requires an available iOS Simulator 27 runtime' unless @report['simulator_runtimes'].any? { |runtime| runtime['version'].split('.').first == '27' }
        @report['source_identity'] = Maintenance.digest(@descriptor.inspection.fetch('selected_files'))
        @report['tuple_identity'] = tools.fetch('identity')
        @settings = File.join(@output, 'settings.json')
        write('settings.json', { 'schema' => 1, 'status' => 'experimental', 'source_identity' => @report['source_identity'], 'tuple_identity' => @report['tuple_identity'],
                                'limits' => { 'parent_reservations' => 4, 'native_jobs_per_owner' => 2, 'compose_jobs_per_owner' => 1,
                                              'polling_nanoseconds' => 20_000_000, 'backoff_nanoseconds' => 50_000_000, 'shutdown_observation_nanoseconds' => 500_000_000 },
                                'busy_retry_behavior' => 'reject-before-registration-and-manual-retry',
                                'rationale' => 'Explicit hosted qualification experiment; limits are unapproved. Compose is disabled; embedded soft shutdown value is not exercised by explicit test deadlines.' })
        @store = RunStore.new(File.join(@root, '.maintenance/runs-swift-export-pilot'))
      end

      def write(name, value)
        RunStore.atomic(File.join(@output, name), value)
      end

      def execute(action, delivery: nil, origin: nil)
        descriptor = Descriptor.new(root: @root, profile: 'coroutine-swift5', repository_policy: 'main-confined', compose: 'disabled', simulator_major: 27)
        adapter = Adapter.new(descriptor, java_home: @java_home, settings_path: @settings, action: action, experimental: true, delivery: delivery, origin_id: origin)
        result = Executor.new(source: @source, adapter: adapter, store: @store,
                              policy: JSON.parse(File.read(File.join(@root, 'maintenance-execution-policy.json'))),
                              input_files: [@settings, __FILE__]).run
        entry = { 'action' => action, 'run_id' => result.fetch('run_id'), 'state' => result.fetch('state'), 'reason' => result['reason'] }
        @runs << entry
        write("#{action}-result.json", result)
        entry
      end

      def retain(entry)
        id = entry.fetch('run_id')
        action = entry.fetch('action')
        check_name = action == 'test' ? 'swift-export-app-pilot' : 'swift-export-pilot-replay'
        entry['phases'] = []
        %w[baseline candidate].each do |phase|
          value = { 'phase' => phase, 'status' => 'check_unavailable' }
          entry['phases'] << value
          begin
            output = File.join(@store.path(id), 'work', phase, 'output')
            check_path = File.join(@store.path(id), 'steps', "#{phase}-#{check_name}", 'check.json')
            next unless File.file?(check_path)
            check = JSON.parse(File.read(check_path))
            value.merge!('status' => check['status'], 'check_sha256' => Maintenance.file_sha(check_path), 'simulator_runtime' => check.dig('runtime', 'simulator_runtime'))
            if action == 'test' && check['delivery']
              delivery = File.join(output, 'registry/objects', check.fetch('delivery').fetch('pointer').fetch('object'))
              retained = File.join(@output, "#{action}-#{phase}-delivery")
              SwiftExport::Assemble.copy(delivery, retained)
              identity = SwiftExport::Delivery.verify(retained)
              raise Failure, 'Retained cold delivery differs' unless identity == check.dig('delivery', 'identity')
              value['delivery'] = retained
              value['delivery_identity'] = identity
              value['delivery_members'] = SwiftExport::Delivery.files(retained).size
            end
            bundle = File.join(output, 'PilotBehaviorTests.xcresult')
            if File.directory?(bundle)
              retained = File.join(@output, "#{action}-#{phase}.xcresult")
              FileUtils.cp_r(bundle, retained, preserve: true)
              summary = test_summary(retained, "#{action}-#{phase}")
              write("#{action}-#{phase}-summary.json", summary)
              value['tests_passed'] = summary['result'] == 'Passed' && summary['totalTestCount'] == 9 && summary['passedTests'] == 9 && summary['failedTests'] == 0 && summary['skippedTests'] == 0 && summary['expectedFailures'] == 0
            end
          rescue StandardError => e
            value['retention_error'] = e.message
            value['tests_passed'] = false
          end
        end
      end

      def test_summary(bundle, name)
        text, status = Open3.capture2e('/usr/bin/xcrun', 'xcresulttool', 'get', 'test-results', 'summary', '--path', bundle, '--compact')
        File.write(File.join(@output, name + '-summary.log'), text)
        raise Failure, 'Test summary unavailable; incomplete bundle retained' unless status.success?
        JSON.parse(text)
      end

      def cleanup(entry)
        recovery = Recovery.new(@store)
        recovered = recovery.recover(entry.fetch('run_id'), action: 'stop')
        entry['recovery'] = recovered
        write("#{entry['action']}-recovery.json", recovered)
        raise Failure, 'Run is not positively quiescent' unless recovered['state'] == 'quiescent'
        cleaned = recovery.cleanup(entry.fetch('run_id'), apply: true, discard: true)
        entry['cleanup'] = cleaned
        write("#{entry['action']}-cleanup.json", cleaned)
        raise Failure, 'Owned disposable work was not cleaned' unless cleaned['state'] == 'cleaned'
      end

      def passed!(entry)
        raise Failure, "#{entry['action']} qualification did not pass" unless entry['state'] == 'checks_passed' && entry.fetch('phases').size == 2 && entry['phases'].all? { |phase| phase['status'] == 'passed' && phase['tests_passed'] }
        if entry['action'] == 'test'
          raise Failure, 'Complete cold deliveries required' unless entry['phases'].all? { |phase| phase['delivery'] && phase['delivery_identity'] }
        end
      end

      def export_runs
        @runs.each do |entry|
          id = entry.fetch('run_id')
          destination = File.join(@output, 'runs', id)
          FileUtils.mkdir_p(destination)
          %w[.json .result.json .events.jsonl].each do |suffix|
            path = @store.path(id, suffix)
            FileUtils.cp(path, destination, preserve: true) if File.file?(path)
          end
          steps = File.join(@store.path(id), 'steps')
          FileUtils.cp_r(steps, destination, preserve: true) if File.directory?(steps)
          entry['journal_sha256'] = Maintenance.file_sha(@store.path(id, '.json'))
          entry['result_sha256'] = Maintenance.file_sha(@store.path(id, '.result.json')) if File.file?(@store.path(id, '.result.json'))
          journal = @store.load(id)
          entry['work_retained'] = journal['resources'].any? { |resource| resource['disposable'] && (resource['state'] != 'removed' || File.exist?(@store.safe_path(journal, resource['path']))) }
        end
      end

      def run
        prepare
        cold = execute('test')
        retain(cold)
        passed!(cold)
        cleanup(cold)
        replay = execute('replay', delivery: cold.fetch('phases').first.fetch('delivery'), origin: cold.fetch('run_id'))
        retain(replay)
        passed!(replay)
        cleanup(replay)
        @source.verify!
        raise Failure, 'Qualification checkout changed' unless git('status', '--porcelain').empty?
        @report['status'] = 'checks_passed_review_required'
        @report['source_unchanged'] = true
        0
      rescue StandardError, Interrupt => e
        @report['error_class'], @report['error'] = e.class.name, e.message
        warn e.message
        23
      ensure
        if @prepared
          begin
            @runs.each do |entry|
              next if entry['cleanup']
              begin
                entry['failure_recovery'] = Recovery.new(@store).recover(entry.fetch('run_id'), action: 'stop')
              rescue StandardError => e
                entry['failure_recovery_error'] = e.message
              end
            end
            export_runs
          rescue StandardError => e
            @report['status'] = 'incomplete'
            @report['retention_error'] = e.message
            raise
          ensure
            write('report.json', @report)
            # Artifact ZIP downloads normalize file modes. Keep delivery/tool
            # executable bits inside a bounded archive for receipt verification.
            members = Dir.children(@output).sort - ['evidence.tar.gz']
            archive_log, archive_status = Open3.capture2e('/usr/bin/tar', '-czf', File.join(@output, 'evidence.tar.gz'), '-C', @output, *members)
            unless archive_status.success?
              @report['status'] = 'incomplete'
              @report['archive_error'] = archive_log
              write('report.json', @report)
              raise Failure, 'Evidence archive failed'
            end
            puts JSON.pretty_generate(@report)
          end
        end
      end
    end
  end
end
