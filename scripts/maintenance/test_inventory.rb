# frozen_string_literal: true

require_relative 'dependencies'
require_relative 'adapters/kotlin'

module InventoryTest
  ROOT = File.expand_path('../..', __dir__)
  @tests = []
  def self.test(name, &block)
    @tests << [name, block]
  end
  def self.assert(value, message = 'assertion failed')
    raise message unless value
  end
  def self.reject(pattern)
    yield
    raise 'Expected rejection'
  rescue Maintenance::Failure => error
    assert(error.message.match?(pattern), error.message)
  end
  def self.fixture
    Dir.mktmpdir('mobi-inventory-test-') do |root|
      env = { 'GIT_CONFIG_GLOBAL' => File::NULL, 'GIT_CONFIG_NOSYSTEM' => '1' }
      _, status = Open3.capture2e(env, 'git', 'init', '--quiet', root)
      assert(status.success?)
      File.write(File.join(root, 'input.txt'), 'original')
      yield root
    end
  end
  def self.policy
    JSON.parse(File.read(File.join(ROOT, 'maintenance-policy.json')))
  end
  NOW = Time.utc(2026, 9, 25, 12)
  def self.provider
    { 'status' => 'ok', 'complete' => true, 'url' => 'https://example.invalid/releases', 'retrieved_at' => (NOW - 60).iso8601, 'response_sha256' => 'a' * 64 }
  end
  def self.packet
    component = { 'id' => 'component', 'version' => '1.1.0', 'ceilings' => ['<1.2.0'] }
    inventory = { 'schema' => 1, 'components' => [component], 'coverage' => [], 'resolved_inputs' => [{ 'id' => 'lock', 'sha256' => 'b' * 64 }] }
    inventory['id'] = Maintenance.digest(inventory)
    evidence = { 'schema' => 1, 'inventory_id' => inventory['id'], 'releases' => [{ 'component_id' => component['id'], 'provider' => provider, 'versions' => [{ 'version' => '1.1.1', 'published_at' => (NOW - 8 * 86_400).iso8601, 'prerelease' => false }] }],
                 'advisories' => [{ 'input_id' => 'lock', 'input_sha256' => 'b' * 64, 'provider' => provider, 'findings' => [] }] }
    [inventory, evidence]
  end
  def self.evaluate(inventory, evidence)
    Maintenance::Policy.new(policy, now: NOW).evaluate(inventory, evidence)
  end

  test('real Renovate fixture retains all expected native manager groups and compiler plugins') do
    native = Maintenance::NativeExtraction.parse(File.join(ROOT, 'scripts/maintenance/fixtures/renovate-44.93.5.jsonl'))
    assert(native['managers'].keys.sort == %w[bundler dockerfile github-actions gradle gradle-wrapper regex ruby-version swift].sort)
    catalog = native['managers']['gradle'].find { |f| f['file'] == 'gradle/libs.versions.toml' }
    assert(catalog['dependencies'].size == 8)
    assert(catalog['dependencies'].any? { |d| d['depName'].include?('skie') })
    assert(native['managers']['regex'].any? { |f| f['dependencies'].any? { |d| d['depName'] == 'dev.zacsweers.metro:compiler' } })
    assert(native['managers']['swift'].first['dependencies'].size == 3)
  end
  test('missing completion, malformed records and native errors cannot look like empty success') do
    fixture do |root|
      input = File.read(File.join(ROOT, 'scripts/maintenance/fixtures/renovate-44.93.5.jsonl'))
      path = File.join(root, 'log')
      File.write(path, input.lines.reject { |line| line.include?('Repository finished') }.join)
      reject(/Incomplete/) { Maintenance::NativeExtraction.parse(path) }
      File.write(path, input + JSON.generate('level' => 50, 'msg' => 'failure') + "\n")
      reject(/reported an error/) { Maintenance::NativeExtraction.parse(path) }
      File.write(path, input + '{truncated')
      reject(/Malformed or truncated/) { Maintenance::NativeExtraction.parse(path) }
      File.write(path, '{"level":30,"msg":"Repository finished"}')
      reject(/Incomplete/) { Maintenance::NativeExtraction.parse(path) }
    end
  end
  test('source guard detects same-stat changes, new files and copied mode drift') do
    fixture do |root|
      source = Maintenance::Source.new(root)
      path = File.join(root, 'input.txt'); stat = File.stat(path)
      File.write(path, 'modified'); File.utime(stat.atime, stat.mtime, path)
      reject(/Source changed/) { source.verify! }
      source = Maintenance::Source.new(root)
      File.write(File.join(root, "odd\nname.txt"), 'new')
      reject(/Source changed/) { source.verify! }
      source = Maintenance::Source.new(root)
      Dir.mktmpdir do |copy|
        source.copy_to(copy)
        source.verify_copy!(copy)
        File.write(File.join(copy, 'unexpected'), 'new')
        reject(/file set differs/) { source.verify_copy!(copy) }
        File.unlink(File.join(copy, 'unexpected'))
        File.chmod(0755, File.join(copy, 'input.txt'))
        reject(/Copied source changed/) { source.verify_copy!(copy) }
      end
    end
  end
  test('source symlinks fail instead of following unowned input') do
    fixture do |root|
      File.symlink('/etc/hosts', File.join(root, 'escape'))
      reject(/symlink unsupported/) { Maintenance::Source.new(root) }
    end
  end
  test('bounded command timeout terminates its owned process') do
    fixture do |root|
      pid_file = File.join(root, 'pid')
      program = 'echo $$ > "$1"; trap "" TERM; sleep 30'
      reject(/timed out/) { Maintenance.run(['/bin/sh', '-c', program, 'timeout-fixture', pid_file], cwd: root, env: {}, log: File.join(root, 'log'), timeout: 2) }
      begin
        Process.kill(0, Integer(File.read(pid_file)))
        raise 'timed out child survived'
      rescue Errno::ESRCH
        nil
      end
    end
  end
  test('missing tool receipt never falls back to ambient binaries') do
    fixture do |root|
      FileUtils.mkdir_p(File.join(root, 'scripts/maintenance/tools'))
      %w[maintenance-tools.json scripts/maintenance/tools/package.json scripts/maintenance/tools/package-lock.json].each { |p| FileUtils.cp(File.join(ROOT, p), File.join(root, p)) }
      tools = Maintenance::Tools.new(root)
      reject(/tools missing/) { tools.verify! }
      FileUtils.mkdir_p(tools.slot)
      File.write(File.join(tools.slot, 'receipt.json'), JSON.generate('identity' => tools.identity, 'files' => {}))
      reject(/tools changed/) { tools.verify! }
      File.write(File.join(tools.slot, 'unexpected'), 'corrupt')
      reject(/tools changed/) { tools.verify! }
      reject(/unowned/) { tools.install!(repair: true) }
    end
  end
  test('tool lock drift is rejected before install') do
    fixture do |root|
      FileUtils.mkdir_p(File.join(root, 'scripts/maintenance/tools'))
      %w[maintenance-tools.json scripts/maintenance/tools/package.json scripts/maintenance/tools/package-lock.json].each { |p| FileUtils.cp(File.join(ROOT, p), File.join(root, p)) }
      File.open(File.join(root, 'scripts/maintenance/tools/package-lock.json'), 'a') { |f| f.write(' ') }
      reject(/identity changed/) { Maintenance::Tools.new(root) }
    end
  end
  test('Kotlin supplementation covers seven modules, plugins, three lock ecosystems and tool/environment gaps') do
    source = Maintenance::Source.new(ROOT)
    native = Maintenance::NativeExtraction.parse(File.join(ROOT, 'scripts/maintenance/fixtures/renovate-44.93.5.jsonl'))
    config = JSON.parse(File.read(File.join(ROOT, 'renovate.json')))
    result = Maintenance::Kotlin.new(ROOT, source.files, native, config).inventory
    assert(result['modules'].size == 7)
    assert(result['resolved_inputs'].map { |r| r['id'].split(':').first }.sort == %w[npm rubygems swift])
    assert(result['resolved_inputs'].find { |r| r['id'].start_with?('swift:') }['packages'].size == 15)
    assert(result['components'].any? { |c| c['name'] == 'Kotlin Toolchain' && c['artifact_sha256'].size == 64 })
    assert(result['components'].any? { |c| c['name'] == 'dev.zacsweers.metro:compiler' && c['ceilings'] == ['<1.2.0'] })
    assert(result['components'].any? { |c| c['source'] == 'quality-tools.json' })
    assert(result['coverage'].any? { |r| r['id'] == 'resolved:kotlin-toolchain-targets' && r['state'] == 'incomplete' })
    source.verify!
  end
  test('missing native manager is a named gap, not no dependencies') do
    source = Maintenance::Source.new(ROOT)
    native = Maintenance::NativeExtraction.parse(File.join(ROOT, 'scripts/maintenance/fixtures/renovate-44.93.5.jsonl'))
    native['managers'].delete('swift')
    result = Maintenance::Kotlin.new(ROOT, source.files, native, JSON.parse(File.read(File.join(ROOT, 'renovate.json')))).inventory
    assert(result['coverage'].any? { |r| r['id'] == 'missing-manager:swift' && r['state'] == 'incomplete' })
  end
  test('backend remains dormant without loading backend tools') do
    assert(Maintenance::Elixir.inventory({})['state'] == 'not_applicable')
    assert(Maintenance::Elixir.inventory('backend/mix.exs' => {})['state'] == 'incomplete')
  end
  test('fresh exact evidence can pass only the named scope, never authorize adoption') do
    result = evaluate(*packet)
    assert(result['state'] == 'checks_passed')
    assert(result['release_scope'] == 'only_named_components' && !result['adoption_authorized'])
  end
  test('raw blocked, new, prerelease, major and unknown-date candidates remain visible') do
    inventory, evidence = packet
    evidence['releases'][0]['versions'] += [
      { 'version' => '1.2.0', 'published_at' => (NOW - 8 * 86_400).iso8601, 'prerelease' => false },
      { 'version' => '2.0.0', 'published_at' => (NOW - 3600).iso8601, 'prerelease' => false },
      { 'version' => '1.1.2-beta', 'prerelease' => true },
      { 'version' => '1.1.2', 'prerelease' => false }
    ]
    result = evaluate(inventory, evidence)
    candidates = result['releases'].first['candidates']
    assert(candidates.size == 5 && result['state'] == 'incomplete')
    assert(candidates[1]['reasons'].include?('ceiling:<1.2.0'))
    assert(%w[too_new major_requires_review].all? { |r| candidates[2]['reasons'].include?(r) })
    assert(candidates[3]['reasons'].include?('prerelease') && candidates[4]['reasons'].include?('missing_publication_timestamp'))
  end
  test('exact seven-day release age boundary is eligible and one second younger is not') do
    inventory, evidence = packet
    version = evidence['releases'].first['versions'].first
    version['published_at'] = (NOW - 7 * 86_400).iso8601
    assert(evaluate(inventory, evidence)['releases'].first['candidates'].first['eligible_for_review'])
    version['published_at'] = (NOW - 7 * 86_400 + 1).iso8601
    assert(!evaluate(inventory, evidence)['releases'].first['candidates'].first['eligible_for_review'])
  end
  test('stale, failed, incomplete or digest-free provider responses cannot be clean') do
    [{ 'retrieved_at' => (NOW - 86_401).iso8601 }, { 'status' => 'failed' }, { 'complete' => false }, { 'response_sha256' => nil }, { 'retrieved_at' => '2026-09-25T11:59:00' }, { 'retrieved_at' => (NOW + 60).iso8601 }].each do |change|
      inventory, evidence = packet
      evidence['advisories'][0]['provider'].merge!(change)
      assert(evaluate(inventory, evidence)['state'] == 'incomplete')
    end
  end
  test('missing, duplicate or mismatched advisory inputs prevent a clean result') do
    4.times do |index|
      inventory, evidence = packet
      case index
      when 0 then evidence['advisories'] = []
      when 1 then evidence['advisories'] << evidence['advisories'].first.dup
      when 2 then evidence['advisories'][0]['input_sha256'] = 'c' * 64
      when 3 then evidence['advisories'][0].delete('findings')
      end
      assert(evaluate(inventory, evidence)['state'] == 'incomplete')
    end
  end
  test('high and critical block, unknown severity needs triage and low findings remain visible') do
    %w[high critical unknown low].each do |severity|
      inventory, evidence = packet
      evidence['advisories'][0]['findings'] = [{ 'id' => 'TEST-1', 'severity' => severity }]
      result = evaluate(inventory, evidence)
      expected = severity == 'unknown' ? 'incomplete' : severity == 'low' ? 'checks_passed' : 'blocked'
      assert(result['state'] == expected)
      assert(result['advisories'][0]['findings'].size == 1)
    end
  end
  test('source or evidence identity drift cannot be evaluated') do
    inventory, evidence = packet
    evidence['inventory_id'] = 'changed'
    reject(/does not match/) { evaluate(inventory, evidence) }
    inventory, evidence = packet
    inventory['coverage'] << { 'id' => 'missing', 'required' => true, 'state' => 'incomplete' }
    reject(/identity is invalid/) { evaluate(inventory, evidence) }
    inventory['id'] = Maintenance.digest(inventory.reject { |key, _| key == 'id' })
    evidence['inventory_id'] = inventory['id']
    assert(evaluate(inventory, evidence)['state'] == 'incomplete')
  end

  test('invalid or weakened policy fails and old releases are not upgrade candidates') do
    [{ 'schema' => 2 }, { 'minimum_release_age_days' => 0 }, { 'advisory_max_age_hours' => 25 }, { 'blocking_severities' => [] }, { 'automatic_adoption' => true }].each do |change|
      reject(/Unsupported or unsafe/) { Maintenance::Policy.new(policy.merge(change)) }
    end
    inventory, evidence = packet
    evidence['releases'][0]['versions'][0]['version'] = '1.1.0'
    candidate = evaluate(inventory, evidence)['releases'][0]['candidates'][0]
    assert(!candidate['eligible_for_review'] && candidate['reasons'].include?('not_newer'))
    evidence['advisories'][0]['findings'] = [nil]
    assert(evaluate(inventory, evidence)['state'] == 'incomplete')
    evidence['advisories'][0]['input_id'] = 'unknown'
    reject(/unknown resolved input/) { evaluate(inventory, evidence) }
  end

  test('native failures and copy mutations clean only the owned directory') do
    fixture do |root|
      File.write(File.join(root, 'renovate.json'), '{"extends":[]}')
      Dir.mktmpdir('mobi-inventory-owner-test-') do |outside|
        marker = File.join(outside, 'owned-path')
        script = File.join(outside, 'fake.sh')
        tools = Struct.new(:node, :renovate).new('/bin/sh', script)
        [false, true].each do |mutate|
          File.write(script, "pwd > '#{marker}'\n" + (mutate ? "echo changed > input.txt\n" : '') + "exit 7\n")
          source = Maintenance::Source.new(root)
          reject(mutate ? /Copied source changed/ : /extraction failed/) { Maintenance::NativeExtraction.run(source, tools) }
          assert(!File.exist?(File.dirname(File.read(marker).strip)), 'owned extraction directory survived')
          assert(File.exist?(script), 'unowned sibling was removed')
          source.verify!
        end
      end
    end
  end

  test('archive traversal is refused before writing outside its owned destination') do
    fixture do |root|
      FileUtils.mkdir_p(File.join(root, 'scripts/maintenance/tools'))
      %w[maintenance-tools.json scripts/maintenance/tools/package.json scripts/maintenance/tools/package-lock.json].each { |p| FileUtils.cp(File.join(ROOT, p), File.join(root, p)) }
      tools = Maintenance::Tools.new(root, platform: 'darwin-arm64')
      archive = File.join(root, 'bad.tar.gz')
      Zlib::GzipWriter.open(archive) do |gzip|
        Gem::Package::TarWriter.new(gzip) do |tar|
          tar.add_file_simple('node-v24.21.0-darwin-arm64/../escape', 0644, 1) { |entry| entry.write('x') }
        end
      end
      destination = File.join(root, 'destination'); FileUtils.mkdir_p(destination)
      reject(/Invalid Node archive path/) { tools.extract(archive, destination) }
      assert(!File.exist?(File.join(root, 'escape')))
    end
  end

  test('new declared modules and plugins are discovered without a module allowlist') do
    fixture do |root|
      File.write(File.join(root, 'project.yaml'), "modules:\n  - new-feature\n")
      FileUtils.mkdir_p(File.join(root, 'new-feature'))
      File.write(File.join(root, 'new-feature/module.yaml'), "product: lib\ndependencies:\n  - example:library:1.0.0\nsettings:\n  kotlin:\n    compilerPlugins:\n      - example:plugin:2.0.0\n")
      FileUtils.cp(File.join(ROOT, 'kotlin'), File.join(root, 'kotlin'))
      source = Maintenance::Source.new(root)
      result = Maintenance::Kotlin.new(root, source.files, { 'managers' => {} }, {}).inventory
      assert(result['modules'] == ['new-feature'])
      assert(%w[example:library example:plugin].all? { |name| result['components'].any? { |c| c['name'] == name } })
    end
  end

  test('omitted native files and separate Xcode declarations remain visible') do
    source = Maintenance::Source.new(ROOT)
    native = Maintenance::NativeExtraction.parse(File.join(ROOT, 'scripts/maintenance/fixtures/renovate-44.93.5.jsonl'))
    native['managers']['gradle'].reject! { |entry| entry['file'] == 'gradle/libs.versions.toml' }
    result = Maintenance::Kotlin.new(ROOT, source.files, native, {}).inventory
    assert(result['coverage'].any? { |row| row['id'] == 'missing-native-file:gradle/libs.versions.toml' && row['state'] == 'incomplete' })
    assert(result['components'].any? { |component| component['name'].include?('swift-perception') && component['source'].end_with?('project.pbxproj') })
    gems = result['resolved_inputs'].find { |input| input['id'].start_with?('rubygems:') }['packages']
    assert(gems.size == 99 && gems.find { |gem| gem['name'] == 'fastlane' }['relationship'] == 'direct')
    assert(gems.find { |gem| gem['name'] == 'xcodeproj' }['dependencies'].key?('rexml'))
  end

  test('unsupported conditional ceilings cannot silently disappear') do
    rule = { 'allowedVersions' => '<2.0.0', 'matchPackageNames' => ['example:library'], 'matchCurrentVersion' => '1.*' }
    [rule, { 'allowedVersions' => nil, 'matchPackageNames' => ['example:library'] }, { 'allowedVersions' => '<2.0.0', 'matchPackageNames' => ['example:library'], 'matchDatasources' => [] }].each do |invalid|
      reject(/Unsupported conditional ceiling/) { Maintenance::Kotlin.new(ROOT, {}, { 'managers' => {} }, { 'packageRules' => [invalid] }) }
    end
  end

  def self.run
    failures = []
    @tests.each do |name, block|
      block.call
      puts "PASS #{name}"
    rescue StandardError => error
      failures << name
      warn "FAIL #{name}: #{error.message}"
    end
    puts "#{@tests.size} inventory tests, #{failures.size} failures"
    exit(failures.empty? ? 0 : 1)
  end
end

InventoryTest.run if $PROGRAM_NAME == __FILE__
