# frozen_string_literal: true

require_relative 'tool_identity'

# Native consumer products are compiler-specific. Retained delivery is sources/archive.
require 'json'
require 'digest'
require 'fileutils'
gem 'xcodeproj', '= 1.28.1'
require 'xcodeproj'
require_relative '../../adapters/kotlin_resources'
require_relative 'packaging'
source,output,cache,base=ARGV.map { |p| File.realpath(p) }
control=File.dirname(ENV.fetch('MOBI_RESULT_PATH'));phase=ENV.fetch('MOBI_PHASE')
r={'schema'=>1,'check'=>'scene-package','phase'=>phase,'status'=>'infrastructure','adoption_authorized'=>false,'commands'=>[],'supported_toolchain_export'=>'not_established','consumer_runtime'=>'not_run'}
env=ENV.to_h.merge('PATH'=>'/usr/bin:/bin:/usr/sbin:/sbin','DEVELOPER_DIR'=>Maintenance::SwiftExport::ToolIdentity.developer_dir)
command=lambda do |name,argv,cwd=source|
 log=File.join(control,name+'.log');start=Process.clock_gettime(Process::CLOCK_MONOTONIC)
 status=File.open(log,'w') { |f| pid=Process.spawn(env,*argv,chdir:cwd,unsetenv_others:true,out:f,err:[:child,:out],in:File::NULL);Process.wait2(pid).last }
 r['commands']<<{'name'=>name,'argv'=>argv,'exit'=>status.exitstatus,'seconds'=>(Process.clock_gettime(Process::CLOCK_MONOTONIC)-start).round(3),'log_sha256'=>Digest::SHA256.file(log).hexdigest}
 puts "#{phase}/#{name}: #{status.exitstatus}";$stdout.flush;raise "Command failed: #{name}" unless status.success?
 File.read(log,encoding:'UTF-8').scrub
end
begin
 inputs=JSON.parse(File.read(File.join(output,'native-inputs.json'),encoding:'UTF-8'));inputs['files'].each { |f| raise 'Input drift' unless Digest::SHA256.file(f['path']).hexdigest==f['sha256'] }
 app_configuration=inputs.fetch('app_configuration',{});scheme_name=app_configuration.fetch('scheme','SwiftExportConsumer')
 r['source_sha256']=inputs['source_sha256'];r['input_manifest_sha256']=Digest::SHA256.file(File.join(output,'native-inputs.json')).hexdigest;r['xcodeproj_version']=Xcodeproj::VERSION
 r['swift_version']=command.call('swift-version',['/usr/bin/xcrun','swiftc','--version']).strip;r['xcode_version']=command.call('xcode-version',['/usr/bin/xcodebuild','-version']).strip
 sdk=command.call('sdk',['/usr/bin/xcrun','--sdk','iphonesimulator','--show-sdk-path']).strip;env['SDKROOT']=sdk;r['sdk']=sdk
 original=File.join(output,'delivery-original');FileUtils.mkdir_p(original);package=File.join(original,'Package');FileUtils.mkdir_p(package)
 g=inputs['phases'][phase];modules=g['modules'];r['module_modes']={}
 FileUtils.cp_r(g['runtime_headers'],File.join(package,'kotlin_runtime'));maps=['kotlin_runtime/module.modulemap']
 modules.select { |m| m['kind']=='bridge' }.each do |m|
  name=m['bridge'];FileUtils.cp(m['header'],File.join(package,name+'.h'));map=name+'.modulemap';File.write(File.join(package,map),"module #{name} { header \"#{name}.h\" export * }\n");maps<<map
 end
 swift=['/usr/bin/xcrun','swiftc','-sdk',sdk,'-target','arm64-apple-ios26.0-simulator','-module-cache-path',File.join(cache,'module-generation')]
 flags=maps.flat_map { |p| ['-Xcc','-fmodule-map-file='+File.join(package,p)] }+['-I',package,'-L',package]
 compiled=[]
 until compiled.size==modules.size
  m=modules.find { |m| !compiled.include?(m['name']) && (m['dependencies'].to_s.split(',')+File.read(m['swift']).scan(/^import (\w+)/).flatten.select { |d| modules.any? { |o| o['name']==d } }).uniq.all? { |d| compiled.include?(d) } };raise 'Module order unresolved' unless m
  mode=inputs['profile']=='generated-swift5' || m['name']=='KotlinCoroutineSupport' ? '5' : '6';r['module_modes'][m['name']]=mode
  command.call('swift-'+m['name'],swift+flags+['-swift-version',mode,'-emit-module','-parse-as-library','-emit-library','-static','-package-name','MobiSwiftExportCandidate','-module-name',m['name'],'-emit-module-path',File.join(package,m['name']+'.swiftmodule'),m['swift'],'-o',File.join(package,'lib'+m['name']+'.a')]);compiled<<m['name']
 end
 native=File.join(package,'libMobiCompositionNative.a');command.call('copy-native',['/bin/cp','-c',g['native_archive'],native]);raise 'Archive drift' unless Digest::SHA256.file(native).hexdigest==g['native_archive_sha256']
 products=File.join(original,'NativeProducts');command.call('copy-native-products',['/bin/cp','-cR',inputs['package_products'],products])
 nativeflags=flags+['-I',products,'-F',products]+%w[ComposableArchitectureMacros CasePathsMacros PerceptionMacros].flat_map { |n| ['-load-plugin-executable',File.join(products,'macros',n)+'#'+n] }
 command.call('swift-aliases',swift+nativeflags+['-swift-version','6','-warnings-as-errors','-emit-module','-parse-as-library','-emit-library','-static','-module-name','KotlinModules','-emit-module-path',File.join(package,'KotlinModules.swiftmodule'),File.join(base,'Aliases.swift'),'-o',File.join(package,'libKotlinModules.a')]);compiled<<'KotlinModules'
 inputs['sources'].each { |n| FileUtils.cp(File.join(base,n),File.join(original,n)) }
 FileUtils.cp(File.join(base,'offline-style.json'),original)
 if app_configuration['runtime_resource'];FileUtils.cp(File.join(base,'pilot-runtime-settings.json'),original);end
 FileUtils.mkdir_p(File.join(original,'NativeResources'));inputs['resource_bundles'].each { |p| FileUtils.cp_r(p,File.join(original,'NativeResources')) }
 FileUtils.cp(inputs['production_plist'],File.join(original,'App-Info.plist'));FileUtils.cp_r(inputs['production_assets'],File.join(original,'Assets.xcassets'))
 candidate_plist=File.join(original,'App-Info.plist')
 command.call('candidate-scene-manifest',['/usr/libexec/PlistBuddy','-c','Add :UIApplicationSceneManifest dict',candidate_plist])
 command.call('candidate-single-scene',['/usr/libexec/PlistBuddy','-c','Add :UIApplicationSceneManifest:UIApplicationSupportsMultipleScenes bool false',candidate_plist])
 command.call('candidate-scene-configurations',['/usr/libexec/PlistBuddy','-c','Add :UIApplicationSceneManifest:UISceneConfigurations dict',candidate_plist])
 project=Xcodeproj::Project.new(File.join(original,'Consumer.xcodeproj'));target=project.new_target(:application,'SwiftExportConsumer',:ios,'26.0');target.add_file_references(inputs['sources'].map { |n| project.main_group.new_file(n) });target.resources_build_phase.add_file_reference(project.main_group.new_file('offline-style.json'));target.resources_build_phase.add_file_reference(project.main_group.new_file('Assets.xcassets'))
 target.resources_build_phase.add_file_reference(project.main_group.new_file('pilot-runtime-settings.json')) if app_configuration['runtime_resource']
 inputs['resource_bundles'].each { |p| target.resources_build_phase.add_file_reference(project.main_group.new_file('NativeResources/'+File.basename(p))) }
 framework=project.main_group.new_file('NativeProducts/MapLibre.framework');target.frameworks_build_phase.add_file_reference(framework);embed=target.new_copy_files_build_phase('Embed MapLibre');embed.dst_subfolder_spec='10';embed.add_file_reference(framework)
 project.build_configurations.each { |c| c.build_settings['CODE_SIGNING_ALLOWED']='NO' }
 target.build_configurations.each do |c|
  c.build_settings.delete('ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME')
  c.build_settings.merge!({'CURRENT_PROJECT_VERSION'=>'1','MARKETING_VERSION'=>'1.0','ASSETCATALOG_COMPILER_APPICON_NAME'=>'AppIcon','DEVELOPMENT_LANGUAGE'=>'en','SWIFT_VERSION'=>'6.0','SWIFT_STRICT_CONCURRENCY'=>'complete','SWIFT_TREAT_WARNINGS_AS_ERRORS'=>'YES','SWIFT_OPTIMIZATION_LEVEL'=>'-Onone','SDKROOT'=>'iphonesimulator','SUPPORTED_PLATFORMS'=>'iphonesimulator','IPHONEOS_DEPLOYMENT_TARGET'=>'26.0','TARGETED_DEVICE_FAMILY'=>'1,2','PRODUCT_BUNDLE_IDENTIFIER'=>app_configuration.fetch('bundle_identifier','studio.mekate.mobi.maintenance.swift-export-candidate'),'GENERATE_INFOPLIST_FILE'=>'YES','INFOPLIST_FILE'=>'App-Info.plist','INFOPLIST_KEY_UIApplicationSceneManifest_Generation'=>'NO','INFOPLIST_KEY_UILaunchScreen_Generation'=>'YES','CODE_SIGNING_ALLOWED'=>'NO','ARCHS'=>'arm64','ONLY_ACTIVE_ARCH'=>'YES','SWIFT_INCLUDE_PATHS'=>['$(inherited)','$(PROJECT_DIR)/Package','$(PROJECT_DIR)/NativeProducts'],'FRAMEWORK_SEARCH_PATHS'=>['$(inherited)','$(PROJECT_DIR)/NativeProducts'],'LD_RUNPATH_SEARCH_PATHS'=>['$(inherited)','@executable_path/Frameworks'],'LIBRARY_SEARCH_PATHS'=>['$(inherited)','$(PROJECT_DIR)/Package'],'OTHER_SWIFT_FLAGS'=>['$(inherited)']+%w[ComposableArchitectureMacros CasePathsMacros PerceptionMacros].flat_map { |n| ['-load-plugin-executable','$(PROJECT_DIR)/NativeProducts/macros/'+n+'#'+n] }+maps.flat_map { |p| ['-Xcc','-fmodule-map-file=$(PROJECT_DIR)/Package/'+p] },'OTHER_LDFLAGS'=>['$(inherited)']+(compiled+['MobiCompositionNative']).map { |n| '-l'+n }+['-lc++','-framework','Foundation','-framework','UIKit']+Dir.glob(File.join(products,'*.o')).map { |p| '$(PROJECT_DIR)/NativeProducts/'+File.basename(p) },'ENABLE_USER_SCRIPT_SANDBOXING'=>'YES','COMPILER_INDEX_STORE_ENABLE'=>'NO','DEBUG_INFORMATION_FORMAT'=>'dwarf'})
 end
 target.build_configurations.each { |c| c.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = app_configuration.fetch('compilation_conditions',[]) }
 project.save;scheme=Xcodeproj::XCScheme.new;scheme.add_build_target(target);scheme.set_launch_target(target);scheme.save_as(project.path,scheme_name,true)
 build=lambda do |name,dir|
  Maintenance::KotlinResources.new(File.dirname(control),ENV.fetch('MOBI_RESOURCE_NONCE')).register_xcode_project!(File.join(dir,'Consumer.xcodeproj'),developer_dir:env['DEVELOPER_DIR'])
  log=command.call('xcode-'+name,['/usr/bin/xcodebuild','-project',File.join(dir,'Consumer.xcodeproj'),'-scheme',scheme_name,'-configuration','Debug','-sdk','iphonesimulator','-destination','generic/platform=iOS Simulator','-derivedDataPath',File.join(cache,'derived-'+name),'-disableAutomaticPackageResolution','build','CODE_SIGNING_ALLOWED=NO','ARCHS=arm64','ONLY_ACTIVE_ARCH=YES'])
  raise 'Xcode success marker missing' unless log.include?('** BUILD SUCCEEDED **')
  diagnostics=log.lines.grep(/warning:|error:/).map(&:strip);r[name+'_diagnostics']=diagnostics
  raise 'Native consumer diagnostic' if diagnostics.any? { |s| s.include?('error:') || inputs['sources'].any? { |n| s.include?(n+':') } }
  app=File.join(cache,'derived-'+name,'Build/Products/Debug-iphonesimulator/SwiftExportConsumer.app')
  r[name+'_packaging']=Maintenance::SwiftExport::Packaging.verify(app,inputs:inputs,base:base,label:name,command:command)
  r[name+'_single_scene_verified']=r[name+'_packaging']['single_scene_verified']
  binary=File.join(cache,'derived-'+name,'Build/Products/Debug-iphonesimulator/SwiftExportConsumer.app/SwiftExportConsumer');raise 'Missing app executable' unless File.file?(binary)
  command.call('file-'+name,['/usr/bin/file',binary]);FileUtils.mkdir_p(File.join(output,'apps'));FileUtils.cp_r(File.dirname(binary),File.join(output,'apps',name+'.app'));r[name+'_executable_sha256']=Digest::SHA256.file(binary).hexdigest
  Maintenance::KotlinResources.new(File.dirname(control),ENV.fetch('MOBI_RESOURCE_NONCE')).release_xcode_project!(File.join(dir,'Consumer.xcodeproj'))
 end
 build.call('original',original)
 relocated=File.join(output,'relocated','delivery');FileUtils.mkdir_p(File.dirname(relocated));command.call('relocate-package',['/bin/cp','-cR',original,relocated])
 identity=lambda { |dir| %w[Package NativeProducts NativeResources Assets.xcassets].flat_map { |n| Dir.glob(File.join(dir,n,'**','*')) }.select { |p| File.file?(p) }.to_h { |p| [p.delete_prefix(dir+'/'),Digest::SHA256.file(p).hexdigest] }.merge('App-Info.plist'=>Digest::SHA256.file(File.join(dir,'App-Info.plist')).hexdigest,'offline-style.json'=>Digest::SHA256.file(File.join(dir,'offline-style.json')).hexdigest) }
 before=identity.call(original);raise 'Relocation content differs' unless identity.call(relocated)==before
 hidden=original+'-unavailable';File.rename(original,hidden)
 begin;build.call('relocated',relocated);ensure;File.rename(hidden,original);end
 r['original_package_unavailable_during_relocated_build']=true;r['relocation_content_hashes_equal']=true;r['package_files']=before;r['package_manifest_sha256']=Digest::SHA256.hexdigest(JSON.generate(before));r['native_archive_sha256']=g['native_archive_sha256'];r['native_archive_rebuilt']=false
 File.write(File.join(output,'package-manifest.json'),JSON.pretty_generate(before)+"\n")
 r['status']='passed';r['scope']='custom_full_production_plist_assets_relocatable_generated_modules_and_joint_archive_xcode_compile_link_only';r['assessment']='custom_xcode_consumer_bounded_pass_supported_toolchain_export_missing_review_required'
rescue => e
 r['error_class']=e.class.name;r['error']=e.message
ensure
 File.write(File.join(control,'embedding-report.json'),JSON.pretty_generate(r)+"\n");File.write(ENV.fetch('MOBI_RESULT_PATH'),JSON.generate(r))
end
exit(r['status']=='passed' ? 0 : 24)
