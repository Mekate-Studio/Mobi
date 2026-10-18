# frozen_string_literal: true

require_relative 'tool_identity'

# Fresh public-source producer; never accepts assessment binary seeds.
require 'json'
require 'digest'
require 'fileutils'
require 'timeout'
require_relative '../../adapters/kotlin_resources'
source,output,cache,base=ARGV.map { |p| File.realpath(p) }
control=File.dirname(ENV.fetch('MOBI_RESULT_PATH'));phase=ENV.fetch('MOBI_PHASE');nonce=ENV.fetch('MOBI_RESOURCE_NONCE')
r={'schema'=>1,'check'=>'kotlin-cold','phase'=>phase,'status'=>'infrastructure','commands'=>[],'downloads'=>[],'seed_operations'=>0,'adoption_authorized'=>false}
inputs=JSON.parse(File.read(File.join(output,'candidate-inputs.json')));java=inputs.fetch('java_home');resources=Maintenance::KotlinResources.new(File.dirname(control),nonce)
shared=File.join(cache,'toolchain');jvm_home=File.join(cache,'jvm-user');bootstrap=File.join(cache,'bootstrap');konan=File.join(cache,'konan');gradle=File.join(cache,'gradle')
options=resources.tag+' -Duser.home='+jvm_home+' -Djava.io.tmpdir='+ENV.fetch('TMPDIR')
env=ENV.to_h.merge('JAVA_HOME'=>java,'PATH'=>java+'/bin:/usr/bin:/bin:/usr/sbin:/sbin','DEVELOPER_DIR'=>Maintenance::SwiftExport::ToolIdentity.developer_dir,'KONAN_DATA_DIR'=>konan,'GRADLE_USER_HOME'=>gradle,'KOTLIN_CLI_BOOTSTRAP_CACHE_DIR'=>bootstrap,'KOTLIN_CLI_JAVA_HOME'=>java,'JAVA_OPTS'=>options,'KOTLIN_CLI_JAVA_OPTIONS'=>options,'KOTLIN_CLI_NO_WELCOME_BANNER'=>'1')
command=lambda do |name,argv,seconds=600|
 log=File.join(control,name+'.log');status=nil;pid=nil;started=Process.clock_gettime(Process::CLOCK_MONOTONIC)
 begin
  File.open(log,'w') do |f|
   pid=Process.spawn(env,*argv,chdir:source,unsetenv_others:true,out:f,err:[:child,:out],in:File::NULL)
   status=Timeout.timeout(seconds) { Process.wait2(pid).last }
  end
 ensure
  unless status || !pid;Process.kill('KILL',pid) rescue Errno::ESRCH;Process.wait(pid) rescue Errno::ECHILD;end
  r['commands']<<{'name'=>name,'argv'=>argv,'exit'=>status&.exitstatus,'seconds'=>(Process.clock_gettime(Process::CLOCK_MONOTONIC)-started).round(3),'log_sha256'=>Digest::SHA256.file(log).hexdigest};puts "#{phase}/#{name}: #{status&.exitstatus}";$stdout.flush
 end
 raise 'Kotlin cold command failed: '+name unless status&.success?;File.read(log,encoding:'UTF-8').scrub
end
begin
 inputs=JSON.parse(File.read(File.join(output,'candidate-inputs.json'),encoding:'UTF-8'));inputs['files'].each { |f| raise 'Input drift '+f['path'] unless Digest::SHA256.file(f['path']).hexdigest==f['sha256'] }
 r['source_sha256']=inputs['source_sha256'];r['input_manifest_sha256']=Digest::SHA256.file(File.join(output,'candidate-inputs.json')).hexdigest
  [shared,jvm_home,bootstrap,konan,gradle].each { |p| raise 'Cold root already exists' if File.exist?(p);FileUtils.mkdir_p(p) }
  r['initial_empty_roots']=[shared,jvm_home,bootstrap,konan,gradle].to_h { |p| [p,Dir.children(p).empty?] }
  version=command.call('toolchain-version',[File.join(source,'kotlin'),'--shared-cache-dir',shared,'--version']);raise 'Toolchain pin mismatch' unless version.include?('Kotlin Toolchain version 0.13.0');r['toolchain_version']=version.strip
  r['java_version']=command.call('java-version',[java+'/bin/java',resources.tag,'-version']).strip;raise 'JDK pin mismatch' unless r['java_version'].match?(/version "26[."]/)
  r['java_binary_sha256']=Digest::SHA256.file(java+'/bin/java').hexdigest;r['java_release_sha256']=Digest::SHA256.file(java+'/release').hexdigest
  jars=File.join(cache,'exporter-jars');FileUtils.mkdir_p(jars)
  inputs['cold_artifacts'].each_with_index do |f,i|
   target=File.join(jars,f['path']);raise 'Invalid artifact name' unless File.dirname(target)==jars
   command.call('download-'+i.to_s,['/usr/bin/curl','--fail','--location','--connect-timeout','15','--max-time','90','--output',target+'.part',f['url']],100)
   raise 'Publisher artifact checksum mismatch '+f['path'] unless Digest::SHA256.file(target+'.part').hexdigest==f['sha256'];File.rename(target+'.part',target);r['downloads']<<f
  end
  selected=inputs['export_jar_names'].map { |n| File.join(jars,n) };raise 'Analysis jar missing' unless selected.all? { |p| File.file?(p) }
  harness=File.join(output,'export-harness.jar');command.call('harness-compile',[java+'/bin/java',resources.tag,'-Xmx3g','-cp',selected.join(':'),'org.jetbrains.kotlin.cli.jvm.K2JVMCompiler','-jvm-target','17','-no-stdlib','-no-reflect','-opt-in=org.jetbrains.kotlin.analysis.api.KaExperimentalApi','-classpath',selected.join(':'),'-d',harness,File.join(base,'ExportHarness.kt')])
  r['harness_source_sha256']=Digest::SHA256.file(File.join(base,'ExportHarness.kt')).hexdigest;r['harness_jar_sha256']=Digest::SHA256.file(harness).hexdigest;r['harness_recompiled_from_source']=true
  build=File.join(cache,'kotlin-build');build_modules=inputs.fetch('build_modules',%w[shared-di shared-ui-home]);command.call('project-graph',[File.join(source,'kotlin'),'--shared-cache-dir',shared,'build']+build_modules.flat_map { |m| ['-m',m] }+['-p','iosSimulatorArm64','--build-dir',build],600)
  native=Dir.glob(File.join(shared,'extract.cache','*kotlin-native-prebuilt-2.4.20-macos-aarch64*.d')).fetch(0);nv=command.call('native-version',[native+'/bin/konanc','-version']);raise 'Native pin mismatch' unless nv.include?('2.4.20');r['native_version']=nv.strip
  target=File.join(output,'fresh-kotlin');FileUtils.mkdir_p(File.join(target,'klibs'))
  libs=%w[shared-core shared-feature-home shared-feature-nearby-vehicle-map shared-di shared-ui-home].each_with_index.map do |name,i|
   next unless inputs.fetch('declared_modules').include?(%w[MobiCore MobiHome MobiNearby MobiDI MobiUI][i])
   path=Dir.glob(File.join(build,'tasks','*'+name+'_compileIosSimulatorArm64Debug','*.klib')).fetch(0);dest=File.join(target,'klibs',name+'.klib');FileUtils.cp(path,dest);{'name'=>%w[MobiCore MobiHome MobiNearby MobiDI MobiUI][i],'visibility'=>i==0 ? 'partial' : 'full','path'=>dest}
  end.compact
  libs.select! { |m| inputs.fetch('declared_modules').include?(m['name']) }
  libs.each { |m| m['visibility']=inputs.fetch('module_visibility').fetch(m['name']) }
  external=inputs['external_libraries_locked'].each_with_index.map do |f,i|
   path=File.join(shared,f['relative_path']);raise 'Fresh dependency differs from lock '+f['relative_path'] unless File.file?(path) && Digest::SHA256.file(path).hexdigest==f['sha256'];{'name'=>File.basename(path).start_with?('kotlinx-coroutines-core-iossimulatorarm64-') ? 'KotlinxCoroutinesCore' : "Dependency#{i}",'visibility'=>'partial','path'=>path}
  end
  plugin=nil
  if inputs.fetch('declared_modules').any? { |name| %w[MobiUI MobiRouteProbe MobiSharedUIOwner].include?(name) }
   plugin=File.join(shared,inputs['compose_plugin_locked']['relative_path']);raise 'Fresh Compose compiler differs' unless File.file?(plugin) && Digest::SHA256.file(plugin).hexdigest==inputs['compose_plugin_locked']['sha256']
  end
  if inputs.fetch('enum_variant')=='reordered'
   metro=File.join(shared,inputs['metro_plugin_locked']['relative_path']);raise 'Metro compiler checksum differs' unless Digest::SHA256.file(metro).hexdigest==inputs['metro_plugin_locked']['sha256']
   nearby=libs.find { |m| m['name']=='MobiNearby' };raise 'Enum control requires Nearby module' unless nearby
   sources=Dir.glob(File.join(source,'shared-feature-nearby-vehicle-map/src/*.kt')).map { |p| File.basename(p)=='NearbyVehicleMapFeatureState.kt' ? File.join(base,'ReorderedNearbyState.kt') : p }
   command.call('reordered-nearby-source',[native+'/bin/konanc','-target','ios_simulator_arm64','-produce','library','-module-name','shared-feature-nearby-vehicle-map','-o',nearby['path'],'-Xplugin='+metro]+sources+(libs.select { |m| m['name']=='MobiCore' }+external).flat_map { |m| ['-library',m['path']] })
  end
  r['enum_variant']=inputs['enum_variant']
  fixtures=[]
  inputs['fixture_sources'].each do |name,path|
   fixture=File.join(target,'klibs',name+'.klib');argv=[native+'/bin/konanc','-target','ios_simulator_arm64','-produce','library','-module-name',name,'-o',fixture]+Array(path)
   argv+=['-Xplugin='+plugin] if %w[MobiRouteProbe MobiSharedUIOwner].include?(name)
   command.call('fixture-'+name,argv+(libs+external+fixtures).flat_map { |m| ['-library',m['path']] })
   fixtures<<{'name'=>name,'visibility'=>inputs.fetch('module_visibility').fetch(name),'path'=>fixture}
  end
  declarations=(libs+fixtures+external).map { |m| m['name']+'='+m['visibility']+'='+m['path'] }
  text=command.call('swift-export',[java+'/bin/java',resources.tag,'-Xmx4g','-cp',([harness]+selected).join(':'),'ExportHarnessKt',File.join(target,'generated/modules'),native]+declarations)
  raise 'Export analysis failed' if text.match?(/Exception in thread|NoClassDefFoundError|ERROR:/)
  modules=text.lines.grep(/^MODULE\t/).map { |line| %w[marker name kind swift kotlin header bridge dependencies].zip(line.chomp.split("\t",-1)).to_h };raise 'Incomplete export module graph' unless modules.size==inputs.fetch('expected_modules').size
  expected=inputs.fetch('expected_modules');raise 'Unexpected modules' unless modules.map { |m| m['name'] }.sort==expected.sort
  archive=File.join(target,'libMobiCompositionNative.a');bridges=modules.select { |m| m['kind']=='bridge' }
  command.call('joint-native-archive',[native+'/bin/konanc','-target','ios_simulator_arm64','-produce','static','-o',File.join(target,'MobiCompositionNative'),]+inputs.fetch('archive_flags')+bridges.map { |m| m['kotlin'] }+(libs+external+fixtures).flat_map { |m| ['-library',m['path']] })
  headers=File.join(target,'kotlin_runtime');FileUtils.cp_r(File.join(native,'konan/swift_export/kotlin_runtime'),headers)
  r['producer']=inputs.fetch('producer_scope','cold_current_source_and_all_four_diagnostic_facades');r['project_klibs_compiled']=libs.map { |m| {'name'=>m['name'],'sha256'=>Digest::SHA256.file(m['path']).hexdigest} };r['fixture_klibs_compiled']=fixtures.map { |m| {'name'=>m['name'],'source_sha256'=>inputs['fixture_sources'][m['name']].is_a?(Array) ? inputs['fixture_sources'][m['name']].map { |p| Digest::SHA256.file(p).hexdigest } : Digest::SHA256.file(inputs['fixture_sources'][m['name']]).hexdigest,'klib_sha256'=>Digest::SHA256.file(m['path']).hexdigest} };r['locked_external_klibs_matched']=external.size;r['compose_plugin_sha256']=plugin ? Digest::SHA256.file(plugin).hexdigest : nil;r['generated_modules']=modules.map { |m| m['name'] };r['native_archive_sha256']=Digest::SHA256.file(archive).hexdigest;r['native_archive_rebuilt_in_phase']=true
  files=[harness,archive]+libs.map { |m| m['path'] }+fixtures.map { |m| m['path'] }+modules.flat_map { |m| %w[swift kotlin header].filter_map { |k| m[k] unless m[k].to_s.empty? } }+Dir.glob(File.join(headers,'**','*')).select { |p| File.file?(p) }
  generated={'modules'=>modules,'runtime_headers'=>headers,'native_archive'=>archive,'native_archive_sha256'=>r['native_archive_sha256'],'native_rebuilt_in_run'=>true}
  inputs['producer_stage']=File.join(output,'kotlin-inputs.json');inputs['phases']={'baseline'=>generated,'candidate'=>generated};inputs['files']+=files.uniq.map { |p| {'path'=>p,'sha256'=>Digest::SHA256.file(p).hexdigest} }
  File.write(File.join(output,'kotlin-inputs.json'),JSON.pretty_generate(inputs)+"\n")
 r['status']='passed';r['scope']='cold_same_run_kotlin_sources_facades_exporter_and_joint_archive_for_isolated_app_consumers'
rescue =>e
 r['error_class']=e.class.name;r['error']=e.message
ensure
 File.write(File.join(output,'kotlin-cold-report.json'),JSON.pretty_generate(r)+"\n");File.write(ENV.fetch('MOBI_RESULT_PATH'),JSON.generate(r))
end
exit(r['status']=='passed' ? 0 : 1)
