# frozen_string_literal: true

require_relative 'test_compatibility'
require_relative 'adapters/direct_roundtrip'

module DirectRoundtripTest
  @tests = []
  def self.test(name, &block); @tests << [name, block]; end
  def self.assert(value, message = 'assertion failed'); CompatibilityTest.assert(value, message); end
  def self.reject(pattern, &block); CompatibilityTest.reject(pattern, &block); end
  def self.fixture
    CompatibilityTest.fixture do |root|
      experiment = Maintenance::DirectRoundtrip.new(root, File.join(root, 'scripts/maintenance/fixtures/interop'))
      yield root, experiment
    end
  end

  test('direct probe changes are bounded and exact restoration retains wrapper modes and original tests') do
    fixture do |root, experiment|
      before = Maintenance::Source.new(root).files
      experiment.prepare!
      assert(Maintenance.digest(experiment.manifest) == Maintenance.digest(Maintenance::CompatibilityCheck.allocate.tree(root)))
      assert(!File.exist?(File.join(root, 'gradle-bridge')))
      assert(File.read(File.join(root, Maintenance::DirectRoundtrip::SWIFT_PROBE)).include?('slice10-before'))
      mutation = experiment.mutate!
      assert(mutation['changes'].map { |c| c['path'] }.sort == Maintenance::RoundtripEvidence::PROBE_PATHS)
      assert(mutation['cache_policy'] == 'preserved' && !mutation['generated_products_removed'])
      assert(File.read(File.join(root, Maintenance::DirectRoundtrip::KOTLIN_PROBE)).include?('slice10-after'))
      FileUtils.mkdir_p(File.join(root,'build/stale/KotlinModules.framework'))
      File.write(File.join(root,'build/stale/KotlinModules.framework/KotlinModules'),'stale direct bytes')
      restoration = experiment.restore!
      assert(restoration['generated_products_cleared'] == ['build'])
      assert(!File.exist?(File.join(root,'build')))
      assert(Maintenance::Source.new(root).files == before)
      assert(File.executable?(File.join(root,'gradle-bridge/gradlew')))
      reject(/already restored/) { experiment.restore! }
    end
  end

  test('content and mode drift refuse before any bridge inputs are restored') do
    [:content, :mode].each do |kind|
      fixture do |root, experiment|
        experiment.prepare!
        path = File.join(root,'README.md')
        kind == :content ? File.write(path,'unexpected authored edit') : File.chmod(0o755,path)
        reject(/drifted/) { experiment.restore! }
        assert(!File.exist?(File.join(root,'gradle-bridge')))
        assert(File.exist?(File.join(root,Maintenance::DirectRoundtrip::SWIFT_PROBE)))
      end
    end
  end

  test('unexpected source or early bridge reappearance refuses restoration') do
    [:source, :bridge].each do |kind|
      fixture do |root, experiment|
        experiment.prepare!
        kind == :source ? File.write(File.join(root,'shared-di/src/Unexpected.kt'),'unexpected') : FileUtils.mkdir_p(File.join(root,'gradle-bridge'))
        reject(/unexpected authored|unavailable bridge/) { experiment.restore! }
        assert(File.exist?(File.join(root,Maintenance::DirectRoundtrip::SWIFT_PROBE)))
      end
    end
  end

  test('symlinked authored inputs or generated product roots cannot redirect restoration') do
    [:source, :products].each do |kind|
      fixture do |root, experiment|
        experiment.prepare!
        Dir.mktmpdir do |outside|
          sentinel = File.join(outside,'sentinel'); File.write(sentinel,'untouched')
          path = File.join(root,kind == :source ? Maintenance::DirectRoundtrip::SWIFT_PROBE : 'build')
          File.unlink(path) if kind == :source
          File.symlink(kind == :source ? sentinel : outside,path)
          reject(/symlinked/) { experiment.restore! }
          assert(File.read(sentinel) == 'untouched' && !File.exist?(File.join(root,'gradle-bridge')))
        end
      end
    end
  end

  test('second mutation rejects an unreviewed probe preimage without changing it') do
    fixture do |root, experiment|
      experiment.prepare!; experiment.mutate!
      before = File.read(File.join(root,Maintenance::DirectRoundtrip::KOTLIN_PROBE))
      reject(/probe preimage/) { experiment.mutate! }
      assert(File.read(File.join(root,Maintenance::DirectRoundtrip::KOTLIN_PROBE)) == before)
    end
  end

  def self.receipts
    source = { 'README.md' => { 'sha256' => 'a' * 64, 'executable' => false }, 'gradle-bridge/gradlew' => { 'sha256' => 'a' * 64, 'executable' => true } }
    before = { 'README.md' => source['README.md'] }.merge(Maintenance::RoundtripEvidence::PROBE_PATHS.to_h { |p| [p,{ 'sha256' => 'b' * 64, 'executable' => false }] })
    after = before.transform_values(&:dup)
    Maintenance::RoundtripEvidence::PROBE_PATHS.each { |p| after[p]['sha256'] = 'c' * 64 }
    cases = (3.times.map { |i| "HomeFeatureTests/test#{i}()" } + 9.times.map { |i| "NearbyVehicleMapFeatureTests/test#{i}()" }).sort
    framework = 'build/native/KotlinModules.framework/KotlinModules'
    baseline = { 'source-manifest' => source, 'native-test-cases' => cases }
    candidate = {
      'source-manifest' => source, 'direct-source-manifest' => before, 'incremental-source-manifest' => after, 'restored-source-manifest' => source,
      'native-test-cases' => (cases + [Maintenance::RoundtripEvidence::PROBE]).sort,
      'incremental-native-test-cases' => (cases + [Maintenance::RoundtripEvidence::PROBE]).sort, 'rollback-native-test-cases' => cases,
      'incremental-mutation' => { 'schema' => 1, 'before_source_sha256' => Maintenance.digest(before), 'after_source_sha256' => Maintenance.digest(after), 'cache_policy' => 'preserved', 'generated_products_removed' => false, 'adoption_authorized' => false,
        'changes' => Maintenance::RoundtripEvidence::PROBE_PATHS.map { |p| { 'path' => p, 'before_sha256' => 'b' * 64, 'after_sha256' => 'c' * 64 } } },
      'roundtrip-restoration' => { 'schema' => 1, 'original_source_sha256' => Maintenance.digest(source), 'restored_source_sha256' => Maintenance.digest(source), 'generated_products_cleared' => ['build'], 'fixture_additions_removed' => true, 'bridge_restored' => true, 'adoption_authorized' => false },
      'direct-frameworks-before' => { framework => 'd' * 64 }, 'direct-frameworks-after' => { framework => 'e' * 64 }, 'rollback-frameworks' => { framework => 'f' * 64 }, 'incremental-framework-change' => { 'changed' => [framework] }
    }
    { 'baseline' => baseline, 'candidate' => candidate }
  end

  test('verified roundtrip closes only measured capabilities and preserves the baseline lane gaps') do
    CompatibilityTest.report_fixture('direct-roundtrip',references: receipts) do |store,id,_profile|
      report = Maintenance::CompatibilityReport.read(store,id)
      assert(report['roundtrip']['preserved_native_case_count'] == 12)
      assert(report['roundtrip']['changed_framework_count'] == 1)
      assert(report['missing_capabilities'] == %w[release_archive complete_bridge_target_graph])
      assert(report['phases'].first['missing_capabilities'].include?('incremental_direct_build'))
      assert(report['bridge_retirement'] == 'defer' && !report['adoption_authorized'])
    end
  end

  test('consistent receipt hashes cannot invent unexecuted stage cells or bridge absence') do
    ['bridge_restore','incremental_ios_test','rollback_ios_test'].each do |cell|
      CompatibilityTest.report_fixture('direct-roundtrip',references: receipts) do |store,id,profile|
        CompatibilityTest.change_phase_evidence(store,id,profile,'candidate') { |e| e['cells'][cell]['status'] = 'not_attempted' }
        reject(/required capability/) { Maintenance::CompatibilityReport.read(store,id) }
      end
    end
    CompatibilityTest.report_fixture('direct-roundtrip',references: receipts) do |store,id,profile|
      CompatibilityTest.change_phase_evidence(store,id,profile,'candidate') { |e| e.delete('bridge_absence_scope') }
      reject(/direct-stage/) { Maintenance::CompatibilityReport.read(store,id) }
    end
  end

  test('missing native probe original tests changed framework bytes or restoration identity refuse') do
    [
      ->(c) { c['incremental-native-test-cases'].delete(Maintenance::RoundtripEvidence::PROBE) },
      ->(c) { c['rollback-native-test-cases'] = [] },
      ->(c) { c['direct-frameworks-after'] = c['direct-frameworks-before'] },
      ->(c) { c['roundtrip-restoration']['restored_source_sha256'] = '0' * 64 },
      ->(c) { c['roundtrip-restoration']['generated_products_cleared'] = [] },
      ->(c) { c['incremental-mutation']['cache_policy'] = 'cleared' },
      ->(c) { c.delete('rollback-frameworks') }
    ].each do |mutate|
      refs = receipts; mutate.call(refs['candidate'])
      reject(/consumers|bytes|restoration|mutation|framework identities|Malformed/) { Maintenance::RoundtripEvidence.verify!(refs['baseline'],refs['candidate']) }
    end
  end

  def self.run
    failures = @tests.map do |name, block|
      begin
        block.call; puts "PASS #{name}"; nil
      rescue StandardError => error
        warn "FAIL #{name}: #{error.message}\n#{error.backtrace.first(3).join("\n")}"; name
      end
    end.compact
    puts "#{@tests.size} direct roundtrip contracts, #{failures.size} failures"
    exit(failures.empty? ? 0 : 1)
  end
end

DirectRoundtripTest.run if $PROGRAM_NAME == __FILE__
