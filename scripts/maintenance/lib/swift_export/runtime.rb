# frozen_string_literal: true

# Owned simulator and actual UIKit/SwiftUI/Compose lifecycle controls.
require 'json'
require 'digest'
require 'fileutils'
require 'timeout'
require 'rbconfig'
require_relative '../../adapters/kotlin_resources'
source,output,cache,base=ARGV.map { |p| File.realpath(p) };control=File.dirname(ENV.fetch('MOBI_RESULT_PATH'));phase=ENV.fetch('MOBI_PHASE')
resources=Maintenance::KotlinResources.new(File.dirname(control),ENV.fetch('MOBI_RESOURCE_NONCE'))
env=ENV.to_h.merge('PATH'=>'/usr/bin:/bin:/usr/sbin:/sbin','DEVELOPER_DIR'=>'/Applications/Xcode.app/Contents/Developer')
r={'schema'=>1,'check'=>'denial-retry-host','phase'=>phase,'status'=>'infrastructure','commands'=>[],'variants'=>{},'adoption_authorized'=>false}
command=lambda do |name,argv|
  log=File.join(control,name+'.log');start=Process.clock_gettime(Process::CLOCK_MONOTONIC)
  status=File.open(log,'w') { |f| pid=Process.spawn(env,*argv,chdir:source,unsetenv_others:true,out:f,err:[:child,:out],in:File::NULL);Process.wait2(pid).last }
  r['commands']<<{'name'=>name,'argv'=>argv,'exit'=>status.exitstatus,'seconds'=>(Process.clock_gettime(Process::CLOCK_MONOTONIC)-start).round(3),'log_sha256'=>Digest::SHA256.file(log).hexdigest}
  puts "#{phase}/#{name}: #{status.exitstatus}";$stdout.flush;raise 'Command failed: '+name unless status.success?
  File.read(log,encoding:'UTF-8').scrub
end
begin
  inputs=JSON.parse(File.read(File.join(output,'native-inputs.json')));r['source_sha256']=inputs['source_sha256']
  graph=JSON.parse(File.read(File.join(base,'..','graph.json'))); settings=graph.fetch('runtime_settings')
  native_settings={'repositoryPolicy'=>graph['repository_policy'],'enumVariant'=>graph['enum_variant'],'parentReservations'=>settings['parent_reservations'],'composeJobsPerOwner'=>settings['compose_jobs_per_owner'],'pollingNanoseconds'=>settings['polling_nanoseconds'],'backoffNanoseconds'=>settings['backoff_nanoseconds'],'shutdownObservationNanoseconds'=>settings['shutdown_observation_nanoseconds']}
  env['SIMCTL_CHILD_MOBI_CANDIDATE_SETTINGS']=JSON.generate(native_settings)
  sdk=command.call('sdk',['/usr/bin/xcrun','--sdk','iphonesimulator','--show-sdk-path']).strip
  env['SDKROOT']=sdk;r['sdk']=sdk
  device=resources.create_simulator!(env['DEVELOPER_DIR'],major:26);r['simulator_runtime']=resources.state['runtime']
  command.call('simulator-boot',['/usr/bin/xcrun','simctl','boot',device]);command.call('simulator-ready',['/usr/bin/xcrun','simctl','bootstatus',device,'-b'])
  identifier='studio.mekate.mobi.maintenance.swift-export-candidate'
  {'relocated'=>inputs['phases'][phase]}.each do |variant,generated|
    bundle=File.join(output,'apps/relocated.app');exe=File.join(bundle,'SwiftExportConsumer');modes=graph['module_modes']
    command.call('sign-framework',['/usr/bin/codesign','--force','--sign','-',File.join(bundle,'Frameworks/MapLibre.framework')])
    debug=File.join(bundle,'SwiftExportConsumer.debug.dylib');command.call('sign-debug-library',['/usr/bin/codesign','--force','--sign','-',debug]) if File.file?(debug)
    command.call('sign-app',['/usr/bin/codesign','--force','--sign','-',bundle]);command.call('install',['/usr/bin/xcrun','simctl','install',device,bundle])
    ax_project=File.join(output,'ax-'+variant);ax_cache=File.join(cache,'ax-'+variant)
    command.call(variant+'-ax-project',[RbConfig.ruby,File.join(__dir__,'bootstrap.rb'),ax_project,base])
    resources.register_xcode_project!(File.join(ax_project,'AccessibilityBootstrap.xcodeproj'),developer_dir:env['DEVELOPER_DIR'])
    ax_argv=['/usr/bin/xcodebuild','-project',File.join(ax_project,'AccessibilityBootstrap.xcodeproj'),'-scheme','AccessibilityBootstrap','-configuration','Debug','-sdk','iphonesimulator','-derivedDataPath',ax_cache,'-parallel-testing-enabled','NO','-disableAutomaticPackageResolution']
    command.call(variant+'-ax-build',ax_argv+['-destination','generic/platform=iOS Simulator','build-for-testing'])
    container=command.call(variant+'-container',['/usr/bin/xcrun','simctl','get_app_container',device,identifier,'data']).strip
    raise 'Unexpected owned app container' unless File.realpath(container).include?('/'+device+'/data/Containers/Data/Application/')
    docs=File.join(container,'Documents');FileUtils.mkdir_p(docs)
    log=File.join(control,variant+'-runtime.log');status=nil;pid=nil;original_pid=nil;cycles=[];pending=nil;ax_pid=nil;ax_status=nil;ax_ready=false;ax_log=File.join(control,variant+'-ax-runtime.log');ax_test_argv=nil
    begin
      File.open(log,'w') do |f|
        pid=Process.spawn(env,'/usr/bin/xcrun','simctl','launch','--console',device,identifier,chdir:source,unsetenv_others:true,out:f,err:[:child,:out],in:File::NULL)
        ax_test_argv=ax_argv+['-destination','id='+device,'-resultBundlePath',File.join(output,'AXObservation-'+variant+'.xcresult'),'test-without-building']
        File.open(ax_log,'w') { |ax_file| ax_pid=Process.spawn(env,*ax_test_argv,chdir:source,unsetenv_others:true,out:ax_file,err:[:child,:out],in:File::NULL) }
        Timeout.timeout(300) do
          loop do
            content=File.read(log,encoding:'UTF-8').scrub
            if !ax_ready && File.read(ax_log,encoding:'UTF-8').scrub.include?('MOBI_AX_BRIDGE_READY')
              File.write(File.join(docs,'ax-client-ready'),'owned-test-client-ready');ax_ready=true
            end
            unless ax_status
              ax_waited=Process.waitpid2(ax_pid,Process::WNOHANG)
              if ax_waited
                ax_status=ax_waited.last
                raise 'Owned AX observer failed before completion handshake' unless ax_ready && ax_status.success? && File.read(ax_log).include?('MOBI_AX_HOST_FINISHED')
                File.write(File.join(docs,'ax-client-finished'),'owned-test-client-completed')
              end
            end
            original_pid ||= content[/MOBI_DENIAL_PROCESS=(\d+)/,1]
            ready=content.scan(/MOBI_DENIAL_READY=p(\d+):kind=([\w-]+):cycle=(\d+)/).last
            if !pending && ready && cycles.none? { |record| record['cycle']==ready[2].to_i }
              raise 'App PID missing' unless original_pid
              pending={'policy'=>ready[0].to_i,'kind'=>ready[1],'cycle'=>ready[2].to_i}
              command.call('busy-screenshot-p'+ready[0],['/usr/bin/xcrun','simctl','io',device,'screenshot',File.join(control,'busy-p'+ready[0]+'.png')]) if ready[1]=='denied-route'
              command.call('background-c'+ready[2],['/usr/bin/xcrun','simctl','launch',device,'com.apple.Preferences'])
            elsif pending && content.include?("MOBI_SCENE_PHASE=background:p#{pending['policy']}:c#{pending['cycle']}:pid#{original_pid}")
              events=JSON.parse(File.read(File.join(docs,'scene-events.json')))
              event=events.reverse.find { |e| e['phase']=='background' && e['cycle']==pending['cycle'] && e['policy']==pending['policy'] }
              raise 'Background event binding missing' unless event && event['pid'].to_s==original_pid && event['selection']=='sharedUI' && event['reservations']==3 && event['admissionOpen']==true
              if pending['kind']=='denied-route'
                raise 'Denied route/old job binding missing' unless event['homeActive']==0 && event['nearbyActive']==0 && event['composeJobs']==-1 && event['composeDrains']==1 && event['nativeDrains']==2 && event['oldHomeActive']==2 && event['oldNearbyActive']==1 && event['sharedFailure']=='full' && event['sharedAdmissions']==0
              else
                raise 'Running job binding missing' unless event['homeActive']==2 && event['nearbyActive']==1 && event['composeJobs']==1 && event['composeDrains']==0
                expected=pending['kind']=='running' ? 0 : 2
                raise 'Background native supervision mismatch' unless event['nativeDrains']==expected && event['requests'].all? { |value| expected==0 ? value!='none' : value=='none' }
              end
              File.write(File.join(control,'background-c'+pending['cycle'].to_s+'.json'),JSON.pretty_generate(event)+"\n")
              sleep 0.8
              resumed=command.call('foreground-c'+pending['cycle'].to_s,['/usr/bin/xcrun','simctl','launch',device,identifier])
              resumed_pid=resumed[/#{Regexp.escape(identifier)}: (\d+)/,1]
              raise 'Foreground started a different process' unless resumed_pid==original_pid
              cycles<<pending.merge('background'=>event,'foreground_pid'=>resumed_pid.to_i);pending=nil
            end
            waited=Process.waitpid2(pid,Process::WNOHANG);if waited;status=waited.last;break;end
            sleep 0.025
          end
        end
      end
      Timeout.timeout(60) { ax_status=Process.wait2(ax_pid).last } unless ax_status
      r['commands']<<{'name'=>variant+'-ax-observe','argv'=>ax_test_argv,'exit'=>ax_status.exitstatus,'log_sha256'=>Digest::SHA256.file(ax_log).hexdigest}
      raise 'XCTest AX observer failed' unless ax_ready && ax_status.success? && File.read(ax_log).include?('MOBI_AX_HOST_FINISHED')
    ensure
      unless ax_status || !ax_pid;Process.kill('TERM',ax_pid) rescue Errno::ESRCH;Process.wait(ax_pid) rescue Errno::ECHILD;end
      unless status || !pid;Process.kill('TERM',pid) rescue Errno::ESRCH;Process.wait(pid) rescue Errno::ECHILD;end
    end
    r['scene_cycles']=cycles
    selected=graph['repository_policy']=='main-confined' ? 0 : 1;raise 'Three real same-process OS cycles missing' unless cycles.map { |c| [c['policy'],c['kind'],c['cycle']] }==[[selected,'running',1],[selected,'native-draining',2],[selected,'denied-route',3]]
    FileUtils.cp(File.join(docs,'scene-events.json'),File.join(control,'scene-events.json'))
    text=File.read(log,encoding:'UTF-8').scrub;job_checks=text.lines.grep(/^JOB_CHECK=/).map(&:strip);raise 'Compose per-job controls incomplete' unless job_checks.size==22 && job_checks.uniq.size==22; r['compose_job_controls']=job_checks
    transport=text.lines.grep(/^TRANSPORT_CHECK=/).map(&:strip);raise 'Transport controls incomplete' unless transport.size==13 && transport.uniq.size==13;r['transport_controls']=transport
    checks=text.lines.grep(/^MOBI_DENIAL_CHECK=/).map(&:strip);polls=text.lines.grep(/^MOBI_POLL_METRICS=/).map { |x| JSON.parse(x.delete_prefix('MOBI_POLL_METRICS=')) }
    raise 'Actual app polling observations missing' unless polls.size==1 && polls[0]['waitResumptions'].to_i>0 && polls[0].fetch('latencyNanoseconds').keys.sort==%w[manualRetryToLoadedPeers nativeCancellationToRestoredUI]
    r['variants'][variant]={'module_modes'=>modes,'consumer_mode'=>'6','archive_sha256'=>generated['native_archive_sha256'],'runtime_exit'=>status&.exitstatus,'runtime_log_sha256'=>Digest::SHA256.file(log).hexdigest,'runtime_checks'=>checks,'polling_observations'=>polls,'executable_sha256'=>Digest::SHA256.file(exe).hexdigest}
    raise 'Runtime contract controls failed: '+variant unless status&.success? && text.include?('MOBI_DENIAL_EXIT=0') && checks.size==19 && checks.uniq.size==19
    puts "#{phase}/#{variant}-runtime: 19 groups passed";$stdout.flush
  end
  r['status']='passed'
rescue =>e
  r['error_class']=e.class.name;r['error']=e.message
ensure
  File.write(File.join(output,'denial-retry-report.json'),JSON.pretty_generate(r)+"\n");File.write(ENV.fetch('MOBI_RESULT_PATH'),JSON.generate(r))
end
exit(r['status']=='passed' ? 0 : 1)
