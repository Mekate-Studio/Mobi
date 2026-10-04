# frozen_string_literal: true

require_relative 'adapters/mobile_support'
require_relative 'execution_cli'

module SupportPolicyTest
  ROOT = File.expand_path('../..', __dir__)
  NOW = Time.utc(2026, 9, 27, 12)
  @tests = []
  def self.test(name, &block); @tests << [name, block]; end
  def self.assert(value); raise 'assertion failed' unless value; end
  def self.reject
    yield
    raise 'Expected refusal'
  rescue Maintenance::Failure
    true
  end
  def self.inputs
    policy = JSON.parse(File.read(File.join(ROOT, 'maintenance-support-policy.json')))
    catalog = JSON.parse(File.read(File.join(ROOT, 'maintenance-platform-releases.json')))
    catalog['platforms'].each_value { |rows| rows.each { |row| row['source']['retrieved_at'] = NOW.iso8601 } }
    [policy, catalog]
  end
  def self.assess(policy, catalog, now: NOW)
    Maintenance::SupportPolicy.new(policy, catalog, now: now).assess
  end
  def self.fixture
    Dir.mktmpdir('mobi-support-test-') do |root|
      _, status = Open3.capture2e('/usr/bin/git', 'init', '-q', root); assert(status.success?)
      adapter = Maintenance::MobileSupport
      (adapter::INPUTS + [adapter::ANDROID, adapter::PACKAGE, adapter::XCODE]).each do |path|
        target = File.join(root, path); FileUtils.mkdir_p(File.dirname(target)); FileUtils.cp(File.join(ROOT, path), target)
      end
      # Keep this historical mismatch independent of adopted current declarations.
      android = File.join(root, adapter::ANDROID)
      File.write(android, File.read(android).sub(/^    minSdk: \d+$/, '    minSdk: 23').sub(/^    compileSdk: \d+$/, '    compileSdk: 36'))
      package = File.join(root, adapter::PACKAGE)
      File.write(package, File.read(package).sub(/\.iOS\((?:\.v\d+|"[\d.]+")\)/, '.iOS(.v16)'))
      project = File.join(root, adapter::XCODE)
      File.write(project, File.read(project).gsub(/^\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = .*;\n/, ''))
      policy, catalog = inputs
      catalog['platforms'].each_value { |rows| rows.each { |row| row['source']['retrieved_at'] = Time.now.utc.iso8601 } }
      File.write(File.join(root, adapter::INPUTS[1]), JSON.pretty_generate(catalog))
      yield root, adapter.new(root)
    end
  end

  test('previous stable major uses release ordering across the Apple naming jump') do
    policy, catalog = inputs
    older = Marshal.load(Marshal.dump(catalog['platforms']['ios'].first))
    older.merge!('major' => '18', 'minimum' => '18.0', 'released_on' => '2024-09-16')
    catalog['platforms']['ios'].unshift(older)
    assert(assess(policy, catalog)['platforms']['ios']['proposed_major'] == '26')
    policy['platforms']['ios']['stable_major_lag'] = 2
    assert(assess(policy, catalog)['platforms']['ios']['proposed_major'] == '18')
    policy['platforms']['android']['stable_major_lag'] = 0
    assert(assess(policy, catalog)['platforms']['android']['proposed_minimum'] == 37)
  end
  test('previews do not advance the stable window and minor versions are rejected as majors') do
    policy, catalog = inputs
    catalog['platforms']['ios'] << { 'major' => '28', 'channel' => 'preview' }
    assert(assess(policy, catalog)['state'] == 'assessed')
    catalog['platforms']['ios'] << { 'major' => '27.1', 'channel' => 'stable' }
    reject { assess(policy, catalog) }
  end
  test('stale and future evidence are incomplete') do
    policy, catalog = inputs
    assert(assess(policy, catalog, now: NOW + 86_401)['state'] == 'incomplete')
    assert(assess(policy, catalog, now: NOW - 1)['state'] == 'incomplete')
  end
  test('missing history, duplicate families and insufficient lag history cannot pass') do
    policy, catalog = inputs
    catalog['platforms']['android'] = []
    assert(assess(policy, catalog)['state'] == 'incomplete')
    policy, catalog = inputs
    catalog['platforms']['ios'] << catalog['platforms']['ios'].last
    assert(assess(policy, catalog)['state'] == 'incomplete')
    policy, catalog = inputs
    policy['platforms']['ios']['stable_major_lag'] = 2
    assert(assess(policy, catalog)['state'] == 'incomplete')
  end
  test('untrusted URLs, absent digests and future stable releases are incomplete') do
    %w[url sha256 released_on].each do |field|
      policy, catalog = inputs
      row = catalog['platforms']['ios'].last
      case field
      when 'url' then row['source']['url'] = 'https://example.org/fake'
      when 'sha256' then row['source'].delete('sha256')
      when 'released_on' then row['released_on'] = '2027-01-01'
      end
      assert(assess(policy, catalog)['state'] == 'incomplete')
    end
  end
  test('missing primary evidence and minimum mapping do not pass') do
    policy, catalog = inputs
    row = catalog['platforms']['android'].first
    row.delete('source'); row.delete('minimum')
    result = assess(policy, catalog)
    assert(result['state'] == 'incomplete' && !result['adoption_authorized'])
  end
  test('invalid timestamps, policy values and automatic adoption refuse') do
    policy, catalog = inputs
    catalog['platforms']['ios'].first['source']['retrieved_at'] = 'invalid'
    reject { assess(policy, catalog) }
    policy, catalog = inputs
    policy['platforms']['ios']['stable_major_lag'] = -1
    reject { assess(policy, catalog) }
    policy['automatic_adoption'] = true
    reject { assess(policy, catalog) }
    reject { Maintenance::SupportPolicy.new(nil, catalog) }
  end
  test('assessment records implicit app floors and an exact three-file candidate without changing source') do
    fixture do |root, adapter|
      source = Maintenance::Source.new(root)
      result = adapter.assess(source: source)
      assert(result['state'] == 'requires_decision' && result['drift'].size == 3)
      assert(result['declarations']['xcode_configurations'].all? { |row| row['state'] == 'implicit' })
      assert(result['impact']['android_excludes_api_below'] == 36)
      edits = adapter.edits(source)
      assert(edits.map { |e| e['path'] }.sort == [adapter.class::ANDROID, adapter.class::PACKAGE, adapter.class::XCODE].sort)
      source.verify!
      edits.each { |edit| File.write(File.join(root, edit['path']), edit['content']) }
      after = adapter.assess
      assert(after['state'] == 'assessed' && !after['adoption_authorized'])
      assert(after['declarations']['xcode_configurations'].all? { |row| row['minimum'] == '26.0' })
      assert(after['declarations']['android'] == { 'minSdk' => 36, 'compileSdk' => 36, 'targetSdk' => 36 })
      assert(adapter.edits(Maintenance::Source.new(root)).empty?)
    end
  end
  test('a source change after capture refuses candidate generation') do
    fixture do |root, adapter|
      source = Maintenance::Source.new(root)
      File.open(File.join(root, adapter.class::PACKAGE), 'a') { |file| file.puts '// drift' }
      reject { adapter.edits(source) }
    end
  end
  test('minimum above Android compile or target SDK is incomplete') do
    fixture do |root, adapter|
      path = File.join(root, adapter.class::ANDROID)
      File.write(path, File.read(path).sub('compileSdk: 36', 'compileSdk: 35'))
      assert(adapter.assess['state'] == 'incomplete')
      reject { adapter.edits(Maintenance::Source.new(root)) }
    end
  end
  test('new Xcode configurations and conditional or duplicate floor declarations require adapter review') do
    fixture do |_root, adapter|
      text = adapter.read(adapter.class::XCODE)
      block = text.match(adapter.class::CONFIGURATION)[0]
      reject { adapter.configurations(text + block) }
      reject { adapter.configurations(text.sub("buildSettings = {\n", "buildSettings = {\n\t\t\t\t\"IPHONEOS_DEPLOYMENT_TARGET[sdk=iphoneos*]\" = 26.0;\n")) }
      reject { adapter.configurations(text.sub("buildSettings = {\n", "buildSettings = {\n" + "\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 26.0;\n" * 2)) }
    end
  end
  test('named stores are explicit siblings and reject traversal, absolute paths and ambiguous options') do
    args = ['mobile', '--store', 'support-review']
    assert(Maintenance::ExecutionCLI.store_path('/repo', args) == '/repo/.maintenance/runs-support-review')
    assert(args == ['mobile'])
    assert(Maintenance::ExecutionCLI.store_path('/repo', []) == '/repo/.maintenance/runs')
    [['--store', '../runs'], ['--store', '/tmp/run'], ['--store'], ['--store', 'ok', 'extra'], ['--store', 'ok', '--store', 'ok']].each do |bad|
      reject { Maintenance::ExecutionCLI.store_path('/repo', bad) }
    end
  end

  test('mobile mappings cannot truncate Android API fractions or select the wrong iOS major') do
    ['android', 'ios'].each do |platform|
      fixture do |root, adapter|
        path = File.join(root, 'maintenance-platform-releases.json')
        catalog = JSON.parse(File.read(path))
        catalog['platforms'][platform].first['minimum'] = platform == 'android' ? '36.5' : '25.0'
        File.write(path, JSON.pretty_generate(catalog))
        assert(adapter.assess['state'] == 'incomplete')
        reject { adapter.edits(Maintenance::Source.new(root)) }
      end
    end
  end

  failures = 0
  @tests.each do |name, block|
    begin
      block.call
      puts "PASS #{name}"
    rescue StandardError => error
      failures += 1; warn "FAIL #{name}: #{error.class}: #{error.message}"
    end
  end
  puts "#{@tests.size} support policy tests, #{failures} failures"
  exit(failures.zero? ? 0 : 1)
end
