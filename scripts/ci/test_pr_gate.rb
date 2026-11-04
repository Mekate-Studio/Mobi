# frozen_string_literal: true

require 'open3'
require 'yaml'

module PRGateTest
  ROOT = File.expand_path('../..', __dir__)
  WORKFLOW = YAML.safe_load(File.read(File.join(ROOT, '.github/workflows/mobile-ci.yml')))
  STEP = WORKFLOW.fetch('jobs').fetch('pr_gate').fetch('steps').find { |step| step['name'] == 'Require selected jobs to pass' }
  JOBS = %w[classify quality android_test ios_test android_build ios_build].freeze
  FLAGS = %w[android_tests ios_tests android_build ios_build].freeze
  @failures = 0

  def self.fixture
    needs = JOBS.to_h { |job| [job, { 'result' => 'skipped' }] }
    %w[classify quality ios_test].each { |job| needs.fetch(job)['result'] = 'success' }
    needs.fetch('classify')['outputs'] = FLAGS.to_h { |flag| [flag, flag == 'ios_tests' ? 'true' : 'false'] }.merge('docs_only' => 'false')
    needs
  end

  def self.run(needs)
    # Resolve the workflow's actual needs references, including its selection wiring.
    env = STEP.fetch('env').to_h do |name, expression|
      match = /\A\$\{\{ needs\.([a-z_.]+) \}\}\z/.match(expression)
      raise "Unsupported gate input: #{expression}" unless match

      value = match[1].split('.').reduce(needs) { |object, key| object.is_a?(Hash) ? object.fetch(key, '') : '' }
      [name, value.to_s]
    end
    Open3.capture2e(env.merge('PATH' => '/usr/bin:/bin'), '/bin/bash', '-e', '-o', 'pipefail', '-c', STEP.fetch('run'), chdir: ROOT, unsetenv_others: true)
  end

  def self.check(name)
    yield
    puts "PASS #{name}"
  rescue StandardError => error
    @failures += 1
    warn "FAIL #{name}: #{error.message}"
  end

  def self.assert(value, message)
    raise message unless value
  end

  check('abandoned selected quality cannot pass the aggregate gate') do
    needs = fixture
    needs.fetch('quality')['result'] = 'abandoned'
    output, status = run(needs)
    assert(!status.success?, "gate accepted abandoned quality: #{output}")
  end

  check('every aggregate dependency is covered by the result policy fixtures') do
    dependencies = WORKFLOW.fetch('jobs').fetch('pr_gate').fetch('needs')
    assert(dependencies.sort == JOBS.sort, 'review the result policy when adding or removing a validation job')
  end

  check('documentation, platform-only and full selections accept their exact successful results') do
    [[], %w[android_tests], %w[ios_tests], %w[android_tests android_build], %w[ios_tests ios_build], FLAGS].each do |selected|
      needs = fixture
      needs.fetch('classify')['outputs'] = FLAGS.to_h { |flag| [flag, selected.include?(flag).to_s] }.merge('docs_only' => selected.empty?.to_s)
      needs.fetch('quality')['result'] = selected.empty? ? 'skipped' : 'success'
      %w[android_test ios_test android_build ios_build].zip(FLAGS).each do |job, flag|
        needs.fetch(job)['result'] = selected.include?(flag) ? 'success' : 'skipped'
      end
      output, status = run(needs)
      assert(status.success?, "rejected selection #{selected.inspect}: #{output}")
    end
  end

  check('every required job rejects skipped, unsuccessful, missing and unknown results') do
    JOBS.each do |job|
      ['failure', 'cancelled', 'skipped', 'abandoned', 'timed_out', 'neutral', 'unknown', '', nil].each do |result|
        needs = fixture
        FLAGS.each { |flag| needs.fetch('classify').fetch('outputs')[flag] = 'true' }
        JOBS.each { |selected| needs.fetch(selected)['result'] = 'success' }
        needs.fetch(job)['result'] = result
        output, status = run(needs)
        assert(!status.success? && output.include?(job), "accepted/misreported #{job}=#{result.inspect}: #{output}")
      end
    end
  end

  check('unselected jobs require skipped rather than any other result') do
    %w[quality android_test ios_test android_build ios_build].each do |job|
      ['success', 'failure', 'cancelled', 'abandoned', 'unknown', '', nil].each do |result|
        needs = fixture
        needs.fetch('classify')['outputs'] = FLAGS.to_h { |flag| [flag, 'false'] }.merge('docs_only' => 'true')
        needs.each { |name, entry| entry['result'] = name == 'classify' ? 'success' : 'skipped' }
        needs.fetch(job)['result'] = result
        output, status = run(needs)
        assert(!status.success? && output.include?(job), "accepted/misreported unselected #{job}=#{result.inspect}: #{output}")
      end
    end
  end

  check('missing or invalid selection outputs cannot silently skip validation') do
    (FLAGS + ['docs_only']).each do |flag|
      ['', nil, 'TRUE', 'unknown'].each do |value|
        needs = fixture
        needs.fetch('classify').fetch('outputs')[flag] = value
        output, status = run(needs)
        assert(!status.success? && output.include?('selection'), "accepted selection #{flag}=#{value.inspect}: #{output}")
      end
    end
    needs = fixture
    needs.delete('classify')
    _, status = run(needs)
    assert(!status.success?, 'missing classifier passed')
  end

  exit(@failures.zero? ? 0 : 1)
end
