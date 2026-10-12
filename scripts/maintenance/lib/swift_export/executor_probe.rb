# frozen_string_literal: true

require 'json'
require 'digest'
require 'fileutils'
require 'timeout'
source,output,cache,base=ARGV.map { |p| File.realpath(p) };phase=ENV.fetch('MOBI_PHASE');control=File.dirname(ENV.fetch('MOBI_RESULT_PATH'))
r={'schema'=>1,'check'=>'executor-backoff','phase'=>phase,'status'=>'infrastructure','commands'=>[],'controls'=>[],'adoption_authorized'=>false}
env=ENV.to_h.merge('DEVELOPER_DIR'=>'/Applications/Xcode.app/Contents/Developer','PATH'=>'/usr/bin:/bin:/usr/sbin:/sbin')
command=lambda do |name,argv,negative=false,extra={}|
 log=File.join(control,name+'.log');status=File.open(log,'w') { |f| pid=Process.spawn(env.merge(extra),*argv,unsetenv_others:true,chdir:source,out:f,err:[:child,:out],in:File::NULL);Timeout.timeout(60) { Process.wait2(pid).last } };text=File.read(log,encoding:'UTF-8').scrub
 r['commands']<<{'name'=>name,'argv'=>argv,'exit'=>status.exitstatus,'signaled'=>status.signaled?,'signal'=>status.termsig,'log_sha256'=>Digest::SHA256.file(log).hexdigest};puts phase+'/'+name+': '+(status.exitstatus || 'signal-'+status.termsig.to_s).to_s;$stdout.flush
 raise 'Unexpected command outcome '+name if negative ? status.success? : !status.success?
 [text,status]
end
begin
 swift=['/usr/bin/xcrun','swiftc','-swift-version','6','-warnings-as-errors','-parse-as-library','-module-cache-path',File.join(cache,'modules')]
 command.call('dependency-surface',swift+['-emit-module','-emit-library','-static','-module-name','MobiIOSDependencies','-emit-module-path',File.join(output,'MobiIOSDependencies.swiftmodule'),File.join(base,'executor/DependencySurface.swift'),'-o',File.join(output,'libMobiIOSDependencies.a')])
 sources=%w[Polling.swift DrainSupervisor.swift TaskScope.swift HomeFeatureClient.swift NearbyVehicleMapFeatureClient.swift executor/AccessSurface.swift SafeExecutor.swift RuntimeSettings.swift].map { |n| File.join(base,n) }
 exe=File.join(output,'ExecutorProbe');command.call('strict-macos-probe',swift+['-I',output,'-L',output,'-lMobiIOSDependencies']+sources+[File.join(base,'executor/Probe.swift'),'-o',exe])
 forbidden,status=command.call('compile-forbidden-sync',swift+['-I',output,'-typecheck']+sources+[File.join(base,'executor/Forbidden.swift')],true)
 raise 'Wrong static rejection' unless forbidden.include?("call to main actor-isolated instance method 'initialSync()'")
 r['controls']<<'actor_annotated_sync_api_rejects_foreign_compile'
 %w[bad-home bad-nearby].each do |kind|
   marker=File.join(output,kind+'-body-entered');text,status=command.call(kind,[exe,kind],true,{'BODY_MARKER'=>marker})
   raise 'Wrong guard termination' unless status.signaled? && text.include?('EXECUTOR_FOREIGN_ATTEMPT='+kind) && text.include?('EXECUTOR_FOREIGN_CALLBACK_STARTED='+kind) && !text.include?('EXECUTOR_FOREIGN_UNEXPECTED_RETURN=') && !File.exist?(marker)
   r['controls']<<kind+'_unchanged_client_guard_traps_before_stub_access'
 end
 text,status=command.call('positive-executor-and-error-backoff',[exe,'safe'])
 checks=text.lines.grep(/^EXECUTOR_CHECK=/).map(&:strip)
 raise 'Incomplete positive checks' unless checks.size==12 && checks.uniq.size==12 && text.include?('EXECUTOR_EXIT=0')
 r['controls']+=checks;r['observed_backoff_ns']=text[/EXECUTOR_BACKOFF_NS=([^\n]+)/,1].split(',').map(&:to_i)
 r['scope']='Foundation typed access stubs; actual client and driver sources; no Kotlin/TCA/UIKit qualification';r['status']='passed'
rescue=>e;r['error']=e.message;r['error_class']=e.class.name
ensure
 File.write(File.join(output,'executor-backoff-report.json'),JSON.pretty_generate(r)+"\n");File.write(ENV.fetch('MOBI_RESULT_PATH'),JSON.generate(r))
end
exit(r['status']=='passed' ? 0 : 1)
