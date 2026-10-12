# frozen_string_literal: true

# Xcode/SwiftPM own native source, macros and binary artifact resolution.
require 'json'
require 'digest'
require 'fileutils'
gem 'xcodeproj', '= 1.28.1'
require 'xcodeproj'
require_relative '../../adapters/kotlin_resources'
source,output,cache,base=ARGV.map { |p| File.realpath(p) }
control=File.dirname(ENV.fetch('MOBI_RESULT_PATH'));phase=ENV.fetch('MOBI_PHASE')
r={'schema'=>1,'check'=>'native-cold','phase'=>phase,'status'=>'infrastructure','commands'=>[],'native_product_seeds'=>0,'adoption_authorized'=>false}
env=ENV.to_h.merge('PATH'=>'/usr/bin:/bin:/usr/sbin:/sbin','DEVELOPER_DIR'=>'/Applications/Xcode.app/Contents/Developer')
command=lambda do |name,argv,cwd=source|
 log=File.join(control,name+'.log');start=Process.clock_gettime(Process::CLOCK_MONOTONIC)
 status=File.open(log,'w') { |f| pid=Process.spawn(env,*argv,chdir:cwd,unsetenv_others:true,out:f,err:[:child,:out],in:File::NULL);Process.wait2(pid).last }
 r['commands']<<{'name'=>name,'argv'=>argv,'exit'=>status.exitstatus,'seconds'=>(Process.clock_gettime(Process::CLOCK_MONOTONIC)-start).round(3),'log_sha256'=>Digest::SHA256.file(log).hexdigest}
 puts "#{phase}/#{name}: #{status.exitstatus}";$stdout.flush
 raise "Command failed: #{name}" unless status.success?;File.read(log,encoding:'UTF-8').scrub
end
begin
 inputs=JSON.parse(File.read(File.join(output,'kotlin-inputs.json'),encoding:'UTF-8'));inputs['files'].each { |f| raise 'Input drift '+f['path'] unless Digest::SHA256.file(f['path']).hexdigest==f['sha256'] }
 bootstrap=File.join(cache,'native-bootstrap');packages=File.join(cache,'source-packages');pkgcache=File.join(cache,'package-cache');derived=File.join(cache,'native-derived')
 [bootstrap,packages,pkgcache,derived].each { |p| raise 'Cold path already exists' if File.exist?(p);FileUtils.mkdir_p(p) }
 r['initial_empty_roots']=[bootstrap,packages,pkgcache,derived].to_h { |p| [p,Dir.children(p).empty?] }
 dependency=File.join(bootstrap,'Dependencies');FileUtils.mkdir_p(dependency)
 FileUtils.cp(File.join(inputs['native_package_source'],'Package.swift'),dependency)
 FileUtils.cp_r(File.join(inputs['native_package_source'],'Sources'),dependency)
 File.write(File.join(bootstrap,'Bootstrap.swift'),"import SwiftUI\nimport MobiIOSDependencies\n@main struct NativeBootstrap: App { var body: some Scene { WindowGroup { Text(\"Native build probe\") } } }\n")
 project=Xcodeproj::Project.new(File.join(bootstrap,'Bootstrap.xcodeproj'));target=project.new_target(:application,'NativeBootstrap',:ios,'26.0');target.add_file_references([project.main_group.new_file('Bootstrap.swift')])
 ref=project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference);ref.relative_path='Dependencies';project.root_object.package_references<<ref
 product=project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency);product.package=ref;product.product_name='MobiIOSDependencies';target.package_product_dependencies<<product
 buildfile=project.new(Xcodeproj::Project::Object::PBXBuildFile);buildfile.product_ref=product;target.frameworks_build_phase.files<<buildfile
 project.build_configurations.each { |c| c.build_settings['CODE_SIGNING_ALLOWED']='NO' }
 target.build_configurations.each { |c| c.build_settings.merge!({'PRODUCT_BUNDLE_IDENTIFIER'=>'studio.mekate.mobi.maintenance.native-bootstrap','GENERATE_INFOPLIST_FILE'=>'YES','SWIFT_VERSION'=>'6.0','CODE_SIGNING_ALLOWED'=>'NO','ARCHS'=>'arm64','ONLY_ACTIVE_ARCH'=>'YES','COMPILER_INDEX_STORE_ENABLE'=>'NO'}) }
 project.save;scheme=Xcodeproj::XCScheme.new;scheme.add_build_target(target);scheme.set_launch_target(target);scheme.save_as(project.path,'NativeBootstrap',true)
 Maintenance::KotlinResources.new(File.dirname(control),ENV.fetch('MOBI_RESOURCE_NONCE')).register_xcode_project!(project.path.to_s,developer_dir:env['DEVELOPER_DIR'])
 lockdir=File.join(project.path,'project.xcworkspace/xcshareddata/swiftpm');FileUtils.mkdir_p(lockdir);lock=File.join(lockdir,'Package.resolved');FileUtils.cp(inputs['lock_path'],lock)
 pins=JSON.parse(File.read(lock))['pins'];r['locked_pins']=pins;r['input_lock_sha256']=Digest::SHA256.file(lock).hexdigest
 common=['/usr/bin/xcodebuild','-project',project.path.to_s,'-scheme','NativeBootstrap','-clonedSourcePackagesDirPath',packages,'-packageCachePath',pkgcache,'-disablePackageRepositoryCache','-onlyUsePackageVersionsFromResolvedFile']
 3.times do |attempt|
  name=attempt.zero? ? 'resolve' : 'resolve-retry-'+attempt.to_s
  begin
   command.call(name,common+['-resolvePackageDependencies'])
   break
  rescue RuntimeError
   text=File.read(File.join(control,name+'.log'),encoding:'UTF-8').scrub
   raise unless attempt < 2 && text.match?(/timed out|network connection|NSURLErrorDomain/i)
   r['resolution_retries']=attempt+1
  end
 end
 resolved=JSON.parse(File.read(lock))['pins'];raise 'Resolution pins changed' unless resolved==pins;r['resolved_pins_equal']=true
 r['checkout_heads']=pins.to_h do |pin|
  path=File.join(packages,'checkouts',pin['identity']);head=command.call('git-'+pin['identity'],['/usr/bin/git','-C',path,'rev-parse','HEAD']).strip
  raise 'Checkout revision differs' unless head==pin.dig('state','revision');[pin['identity'],head]
 end
 workspace=JSON.parse(File.read(File.join(packages,'workspace-state.json'),encoding:'UTF-8'))
 artifacts=workspace.fetch('object').fetch('artifacts');raise 'Unexpected binary artifact graph' unless artifacts.size==1
 artifact=artifacts.first;raise 'Unexpected binary artifact' unless artifact.dig('packageRef','identity')=='maplibre-gl-native-distribution' && artifact['targetName']=='MapLibre'
 binary=artifact.fetch('source');locked_binary=inputs.fetch('binary_artifacts').fetch(0);raise 'Unexpected binary artifact source' unless binary['type']=='remote' && binary['url']==locked_binary['url'] && binary['checksum']==locked_binary['sha256']
 manifest=File.read(File.join(packages,'checkouts/maplibre-gl-native-distribution/Package.swift'),encoding:'UTF-8')
 raise 'Artifact checksum differs from locked package manifest' unless manifest.include?('checksum: "'+binary['checksum']+'"')
 archive=File.join(cache,'fresh-maplibre.zip');extracted=File.join(cache,'fresh-maplibre');raise 'Fresh binary input already exists' if File.exist?(archive) || File.exist?(extracted)
 command.call('download-maplibre',['/usr/bin/curl','--fail','--location','--retry','2','--output',archive,binary['url']])
 checksum=Digest::SHA256.file(archive).hexdigest;raise 'Publisher binary checksum differs' unless checksum==binary['checksum']
 FileUtils.mkdir_p(extracted);command.call('extract-maplibre',['/usr/bin/ditto','-x','-k',archive,extracted])
 fresh=File.join(extracted,'MapLibre.xcframework');raise 'Downloaded xcframework missing' unless File.directory?(fresh)
 owned_artifact=artifact.fetch('path');raise 'Artifact path is not owned' unless File.realpath(owned_artifact).start_with?(File.realpath(packages)+'/artifacts/')
 hash_tree=lambda { |path| Dir.glob(File.join(path,'**','*')).select { |p| File.file?(p) }.to_h { |p| [p.delete_prefix(path+'/'),Digest::SHA256.file(p).hexdigest] } }
 fresh_hashes=hash_tree.call(fresh);raise 'Independent binary differs from resolved artifact' unless fresh_hashes==hash_tree.call(owned_artifact)
 FileUtils.rm_rf(owned_artifact);FileUtils.cp_r(fresh,owned_artifact);raise 'Fresh artifact replacement drift' unless hash_tree.call(owned_artifact)==fresh_hashes
 r['fresh_maplibre']={'url'=>binary['url'],'publisher_checksum'=>binary['checksum'],'download_sha256'=>checksum,'download_bytes'=>File.size(archive),'downloaded_independently'=>true,'resolved_artifact_replaced_before_build'=>true,'full_xcframework_manifest'=>fresh_hashes}
 FileUtils.cp(archive,File.join(output,'MapLibrePublisher.zip'))
 log=command.call('build',common+['-configuration','Debug','-destination','generic/platform=iOS Simulator','-derivedDataPath',derived,'-disableAutomaticPackageResolution','build','CODE_SIGNING_ALLOWED=NO','ARCHS=arm64','ONLY_ACTIVE_ARCH=YES'])
 raise 'Build success marker absent' unless log.include?('** BUILD SUCCEEDED **')
 products=File.join(derived,'Build/Products');sim=File.join(products,'Debug-iphonesimulator');dest=File.join(output,'ColdNativeProducts');FileUtils.mkdir_p(dest)
 Dir.children(sim).each do |name|
  p=File.join(sim,name);next unless (name.end_with?('.o','.swiftmodule') && !name.start_with?('NativeBootstrap.')) || name=='MapLibre.framework'
  FileUtils.cp_r(p,File.join(dest,name),preserve:true)
 end
 FileUtils.mkdir_p(File.join(dest,'macros'));r['macro_build_evidence']={}
 %w[ComposableArchitectureMacros CasePathsMacros PerceptionMacros].each do |name|
  p=[File.join(products,'Debug',name),File.join(sim,name)].find { |f| File.file?(f) };raise 'Missing freshly built macro' unless p
  platform=command.call('macro-platform-'+name,['/usr/bin/xcrun','vtool','-show-build',p]);raise 'Macro is not a macOS host executable' unless platform.include?('platform MACOS')
  raise 'Macro linker invocation absent' unless log.lines.any? { |line| line.start_with?('Ld ') && line.include?('/'+name+' ') }
  FileUtils.cp(p,File.join(dest,'macros',name),preserve:true);r['macro_build_evidence'][name]={'sha256'=>Digest::SHA256.file(p).hexdigest,'link_invocation_observed'=>true,'platform'=>'MACOS'}
 end
 resources=File.join(output,'ColdNativeResources');FileUtils.mkdir_p(resources)
 bundles=Dir.glob(File.join(sim,'*.bundle'));raise 'Native privacy bundles missing' unless bundles.map { |p| File.basename(p) }.sort==%w[swift-composable-architecture_ComposableArchitecture.bundle swift-sharing_Sharing.bundle].sort
 bundles.each { |p| FileUtils.cp_r(p,resources,preserve:true) }
 inputs['package_products']=dest;inputs['resource_bundles']=bundles.map { |p| File.join(resources,File.basename(p)) }
 products_files=Dir.glob(File.join(dest,'**','*')).select { |p| File.file?(p) }+Dir.glob(File.join(resources,'**','*')).select { |p| File.file?(p) }
 inputs['files']+=products_files.map { |p| {'path'=>p,'sha256'=>Digest::SHA256.file(p).hexdigest} }
 File.write(File.join(output,'native-inputs.json'),JSON.pretty_generate(inputs)+"\n")
 r['product_manifest']=products_files.to_h { |p| [p.delete_prefix(output+'/'),Digest::SHA256.file(p).hexdigest] };r['binary_target_manifest']=File.read(File.join(packages,'checkouts/maplibre-gl-native-distribution/Package.swift'),encoding:'UTF-8');r['package_products']=dest;r['resource_bundles']=inputs['resource_bundles'];r['status']='passed';r['scope']='fresh_locked_native_swiftpm_sources_macros_and_maplibre_binary_artifact'
rescue => e
 r['error_class']=e.class.name;r['error']=e.message
ensure
 File.write(File.join(output,'native-cold-report.json'),JSON.pretty_generate(r)+"\n");File.write(ENV.fetch('MOBI_RESULT_PATH'),JSON.generate(r))
end
exit(r['status']=='passed' ? 0 : 1)
