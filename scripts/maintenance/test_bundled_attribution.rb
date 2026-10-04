# frozen_string_literal: true

require_relative 'lib/bundled_attribution'
require 'stringio'

module BundledAttributionTest
  @tests = []
  def self.test(name, &block); @tests << [name, block]; end
  def self.assert(value); raise 'assertion failed' unless value; end
  def self.reject
    yield; raise 'Expected refusal'
  rescue Maintenance::Failure
    true
  end
  def self.clone(value); Marshal.load(Marshal.dump(value)); end
  def self.identity(bytes)
    { 'kind' => 'file', 'sha256' => Digest::SHA256.hexdigest(bytes), 'bytes' => bytes.bytesize }
  end
  def self.fixture
    Dir.mktmpdir('mobi-bundled-contract-') do |root|
      _, status = Open3.capture2('/usr/bin/git', 'init', '--quiet', root); assert(status.success?)
      File.write(File.join(root, 'source.txt'), 'unchanged')
      _, status = Open3.capture2('/usr/bin/git', '-C', root, '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.test', 'add', 'source.txt'); assert(status.success?)
      _, status = Open3.capture2('/usr/bin/git', '-C', root, '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.test', 'commit', '--quiet', '-m', 'fixture'); assert(status.success?)
      meta = 'embedded Kotlin module metadata'; member = 'META-INF/owner.kotlin_module'
      FileUtils.mkdir_p(File.join(root, 'META-INF')); File.write(File.join(root, member), meta)
      _out, status = Open3.capture2e('/usr/bin/zip', '-q', File.join(root, 'owner.jar'), member, chdir: root); assert(status.success?)
      owned_bytes = File.binread(File.join(root, 'owner.jar')); third_bytes = 'third party exact bytes'
      project = "modules:\n  - sources/owner\n"; module_body = "product: jvm/lib\n"
      url = Maintenance::BundledAttribution.method(:source_url)
      files = [
        { 'file' => 'arbitrary-name.jar', 'kind' => 'maven_reference', 'identity' => identity(third_bytes), 'component' => { 'group' => 'org.example', 'name' => 'library', 'version' => '1.0' }, 'classifier' => nil, 'url' => 'https://repo.maven.apache.org/maven2/org/example/library/1.0/library-1.0.jar' },
        { 'file' => 'owner-jvm.jar', 'kind' => 'source_module_correspondence', 'identity' => identity(owned_bytes), 'module' => 'sources/owner', 'url' => url.call('sources/owner/module.yaml', '0.13.0'), 'source_sha256' => Digest::SHA256.hexdigest(module_body), 'metadata_member' => member, 'metadata_sha256' => Digest::SHA256.hexdigest(meta) }
      ]
      index = "arbitrary-name.jar\nowner-jvm.jar\nprevious.jar\n"
      tar = StringIO.new(''.b)
      Gem::Package::TarWriter.new(tar) do |writer|
        { 'extra/android-integration-gradle-plugin.classpath.txt' => index, 'extra/jars/arbitrary-name.jar' => third_bytes, 'extra/jars/owner-jvm.jar' => owned_bytes, 'extra/jars/previous.jar' => third_bytes }.each do |name, bytes|
          writer.add_file_simple(name, 0o644, bytes.bytesize) { |out| out.write(bytes) }
        end
      end
      gzip = StringIO.new(''.b); Zlib::GzipWriter.wrap(gzip) { |writer| writer.write(tar.string) }; dist_bytes = gzip.string
      config = { 'schema' => 1, 'toolchain' => '0.13.0', 'automatic_adoption' => false, 'files' => files,
        'sources' => [{ 'path' => 'project.yaml', 'url' => url.call('project.yaml', '0.13.0'), 'sha256' => Digest::SHA256.hexdigest(project) }],
        'distribution' => { 'url' => 'https://packages.jetbrains.team/maven/p/amper/amper/org/jetbrains/kotlin/kotlin-cli/0.13.0/kotlin-cli-0.13.0-dist.tgz', 'sha256' => Digest::SHA256.hexdigest(dist_bytes), 'bytes' => dist_bytes.bytesize, 'classpath_member' => 'extra/android-integration-gradle-plugin.classpath.txt' } }
      report = { 'schema' => 1, 'state' => 'checks_passed', 'run_id' => 'a' * 32, 'result_sha256' => 'b' * 64, 'binding' => { 'adapter' => 'compatibility-upstream-build-inputs' },
        'phases' => [{ 'phase' => 'candidate', 'candidate_selection' => { 'version' => '0.13.0' } }],
        'bundled_settings_inputs' => { 'unassigned' => files.map { |f| { 'name' => f['file'], 'identity' => f['identity'] } }, 'matches' => [{ 'name' => 'previous.jar', 'identity' => identity(third_bytes) }], 'producer_sha256' => { 'baseline' => 'c' * 64, 'candidate' => 'd' * 64 } } }
      resources = { config['distribution']['url'] => dist_bytes, config['sources'][0]['url'] => project, files[0]['url'] => third_bytes, files[1]['url'] => module_body }
      downloads = []
      transport = lambda do |remote, file|
        downloads << File.dirname(file); File.binwrite(file, resources.fetch(remote))
      end
      yield root, config, report, transport, resources, downloads
    end
  end

  test('distribution and independent bytes account for arbitrary filenames with source ownership separate') do
    fixture do |root, config, report, transport, _resources, downloads|
      Maintenance::BundledAttribution.config!(config, config['distribution']['sha256'])
      receipt = Maintenance::BundledAttribution.collect(root, report, config, transport: transport)
      summary = Maintenance::BundledAttribution.verify!(receipt, report, config)
      assert(summary.values_at('file_count', 'independent_maven_count', 'source_module_count') == [2, 1, 1])
      assert(summary['measured_file_count'] == 3 && receipt['archive']['members'].size == 3)
      assert(summary['queries'].size == 1 && summary['queries'][0]['package']['name'] == 'org.example:library')
      assert(summary['source_binary_reproducibility'] == 'unproven' && !summary['adoption_authorized'])
      assert(receipt['caller_preservation'] && downloads.uniq.all? { |d| !File.exist?(d) })
    end
  end
  test('reviewed configuration refuses private endpoints, unknown kinds, traversal, pin changes and duplicates') do
    fixture do |_root, config, report, *_|
      [->(c) { c['files'][0]['url'] = 'https://example.test/fake.jar' }, ->(c) { c['files'][0]['kind'] = 'filename_guess' },
       ->(c) { c['files'][1]['module'] = '../escape' }, ->(c) { c['distribution']['sha256'] = 'e' * 64 },
       ->(c) { c['files'] << c['files'][0] }, ->(c) { c['automatic_adoption'] = true }].each do |mutation|
        c = clone(config); mutation.call(c); reject { Maintenance::BundledAttribution.config!(c, config['distribution']['sha256']) }
      end
      r = clone(report); r['phases'][0]['candidate_selection']['version'] = '0.14.0'; reject { Maintenance::BundledAttribution.binding(r, config) }
      r = clone(report); r['bundled_settings_inputs']['unassigned'].pop; reject { Maintenance::BundledAttribution.binding(r, config) }
    end
  end
  test('changed archive artifact and source transport retain incomplete state and clean owned downloads') do
    fixture do |root, config, report, transport, resources, downloads|
      resources[config['distribution']['url']] = 'different archive'
      r = Maintenance::BundledAttribution.collect(root, report, config, transport: transport)
      assert(r['state'] == 'incomplete' && r['temporary_downloads_cleaned'] && !r['caller_preservation'])
      reject { Maintenance::BundledAttribution.verify!(r, report, config) }
      assert(downloads.uniq.all? { |d| !File.exist?(d) })
    end
    fixture do |root, config, report, _transport, _resources, _downloads|
      r = Maintenance::BundledAttribution.collect(root, report, config, transport: ->(_url, _file) { raise Maintenance::Failure, 'provider unavailable' })
      assert(r['state'] == 'incomplete' && r['temporary_downloads_cleaned'])
    end
    fixture do |root, config, report, transport, resources, _downloads|
      resources[config['files'][0]['url']] = 'same filename different bytes'
      r = Maintenance::BundledAttribution.collect(root, report, config, transport: transport)
      assert(r['state'] == 'incomplete' && r['temporary_downloads_cleaned'])
    end
  end
  test('replay refuses altered binding, membership, source bytes, metadata and independent artifact sets') do
    fixture do |root, config, report, transport, *_|
      receipt = Maintenance::BundledAttribution.collect(root, report, config, transport: transport)
      [->(r) { r['binding']['original_result_sha256'] = 'f' * 64 }, ->(r) { r['archive']['classpath_body'] += "unknown.jar\n"; r['archive']['classpath_sha256'] = Digest::SHA256.hexdigest(r['archive']['classpath_body']) },
       ->(r) { r['sources'][0]['body'] += 'changed' }, ->(r) { r['archive']['members'].find { |m| m['metadata_sha256'] }['metadata_sha256'] = 'f' * 64 },
       ->(r) { r['independent_artifacts'].clear }, ->(r) { r['archive']['members'].pop }, ->(r) { r['temporary_downloads_cleaned'] = false }, ->(r) { r['adoption_authorized'] = true }].each do |mutation|
        r = clone(receipt); mutation.call(r); reject { Maintenance::BundledAttribution.verify!(r, report, config) }
      end
    end
  end
  test('caller drift during collection cannot become preservation evidence') do
    fixture do |root, config, report, transport, *_|
      mutate = lambda do |url, file|
        transport.call(url, file); File.write(File.join(root, 'source.txt'), 'changed')
      end
      r = Maintenance::BundledAttribution.collect(root, report, config, transport: mutate)
      assert(r['state'] == 'incomplete' && !r['caller_preservation'] && r['temporary_downloads_cleaned'])
    end
  end
  test('fresh advisory receipts bind independent attribution and refuse relabelled or substituted evidence') do
    q = { 'package' => { 'ecosystem' => 'Maven', 'name' => 'org.jetbrains.kotlin:kotlin-gradle-plugin' }, 'version' => '2.2.10' }
    report = { 'state' => 'checks_passed', 'run_id' => 'a' * 32, 'result_sha256' => 'b' * 64, 'bundled_file_attribution' => {}, 'input_evidence_sha256' => 'c' * 64,
      'direct_resolution' => { 'candidate' => { 'advisory_queries' => { 'queries' => [q] } } } }
    transport = lambda do |url, payload|
      body = JSON.generate(payload ? { 'results' => [{ 'vulns' => [{ 'id' => 'GHSA-r937-wjx7-w2jp', 'modified' => '2026-10-03T00:00:00Z' }] }] } : { 'id' => 'GHSA-r937-wjx7-w2jp', 'modified' => '2026-10-03T00:00:00Z', 'affected' => [{}] })
      { 'url' => url, 'request' => payload, 'body' => body, 'response_sha256' => Digest::SHA256.hexdigest(body), 'status' => 200, 'retrieved_at' => Time.now.utc.iso8601 }
    end
    receipt = Maintenance::AdvisoryReview.collect(report, transport: transport)
    summary = Maintenance::AdvisoryReview.verify!(receipt, report)
    assert(summary['finding_ids'] == ['GHSA-r937-wjx7-w2jp'] && summary['state'] == 'triage_required')
    r = clone(receipt); r['input_evidence_sha256'] = 'd' * 64; reject { Maintenance::AdvisoryReview.verify!(r, report) }
    r = clone(receipt); r['query_evidence'] = 'named_resolved'; reject { Maintenance::AdvisoryReview.verify!(r, report) }
  end

  failures = 0
  @tests.each do |name, block|
    block.call; puts "PASS #{name}"
  rescue StandardError => e
    failures += 1; warn "FAIL #{name}: #{e.message}"
  end
  puts "#{@tests.size} bundled attribution contracts, #{failures} failures"
  exit(failures.zero? ? 0 : 1)
end
