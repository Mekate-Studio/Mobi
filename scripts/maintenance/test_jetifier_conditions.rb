# frozen_string_literal: true

require_relative 'lib/jetifier_conditions'
require_relative 'test_build_inputs'

module JetifierConditionsTest
  @tests = []
  def self.test(name, &block); @tests << [name, block]; end
  def self.assert(value); raise 'assertion failed' unless value; end
  def self.reject
    yield; raise 'Expected refusal'
  rescue Maintenance::Failure
    true
  end
  def self.packet(enabled = false)
    data = BuildInputsTest.delegated
    id = { 'kind' => 'file', 'sha256' => 'b' * 64, 'bytes' => 5 }
    data['jetifier_conditions'] = { 'schema' => 1, 'projects' => [{ 'project' => ':', 'state' => 'collected', 'enabled' => enabled,
      'agp_version' => '9.3.1', 'option_api' => 'actual_plugin_project_services_project_options', 'explicit_property' => { 'present' => false, 'value' => nil },
      'plugin_identity' => id, 'options_identity' => id }],
      'transforms' => { 'state' => 'observed', 'reason' => nil, 'gradle' => '9.6.1', 'interval' => 'init_script_to_build_finished', 'observer_api' => 'planned_identify_action_v1', 'identified_count' => 0, 'planned_count' => 0, 'action_count' => 0, 'events' => [] } }
    { 'data' => data, 'raw_sha256' => 'a' * 64 }
  end
  test('bounded disabled observation never clears the advisory or authorizes adoption') do
    r = Maintenance::JetifierConditions.read([packet])
    assert(r['state'] == 'bounded_disabled' && r['advisory_state'] == 'review_required' && !r['mitigation_verified'] && !r['adoption_authorized'])
  end
  test('historical missing null and incomplete settings never become disabled') do
    p = packet; p['data'].delete('jetifier_conditions')
    assert(Maintenance::JetifierConditions.read([p])['builds'][0]['state'] == 'unmeasured')
    p['data']['jetifier_conditions'] = nil; reject { Maintenance::JetifierConditions.read([p]) }
    p = packet; p['data']['jetifier_conditions']['projects'].clear
    assert(Maintenance::JetifierConditions.read([p])['state'] == 'incomplete')
    p = packet; p['data']['jetifier_conditions']['projects'][0] = { 'project' => ':', 'state' => 'incomplete', 'reason' => 'unsupported_agp_api' }
    assert(Maintenance::JetifierConditions.read([p])['state'] == 'incomplete')
    p['data']['jetifier_conditions']['projects'][0]['enabled'] = false; reject { Maintenance::JetifierConditions.read([p]) }
  end
  test('unsupported listener contradictory options unsafe fields and missing identities refuse credit') do
    p = packet; p['data']['jetifier_conditions']['transforms']['state'] = 'incomplete'; p['data']['jetifier_conditions']['transforms']['reason'] = 'unsupported_api'
    assert(Maintenance::JetifierConditions.read([p])['state'] == 'incomplete')
    p = packet; p['data']['jetifier_conditions']['projects'][0]['explicit_property'] = { 'present' => true, 'value' => true }
    assert(Maintenance::JetifierConditions.read([p])['state'] == 'incomplete')
    p = packet; p['data']['jetifier_conditions']['transforms']['interval'] = 'task_graph_only'; reject { Maintenance::JetifierConditions.read([p]) }
    p = packet; p['data']['jetifier_conditions']['projects'][0]['options_identity']['sha256'] = ''; reject { Maintenance::JetifierConditions.read([p]) }
    p = packet; p['data']['jetifier_conditions']['projects'][0]['reason'] = '/Users/private'; reject { Maintenance::JetifierConditions.read([p]) }
    p = packet; p.delete('raw_sha256'); reject { Maintenance::JetifierConditions.read([p]) }
  end
  test('actual actions unavailable inputs and contradictory disabled states remain incomplete') do
    p = packet(true); t = p['data']['jetifier_conditions']['transforms']; t['planned_count'] = 0; t['identified_count'] = 1; t['action_count'] = 1
    t['events'] = [{ 'implementation' => 'com.android.build.gradle.internal.dependency.JetifyTransform', 'transformer' => 'JetifyTransform', 'subject' => 'fixture.jar',
      'implementation_identity' => { 'kind' => 'file', 'sha256' => 'c' * 64, 'bytes' => 6 }, 'action_count' => 1, 'outcome' => 'passed',
      'input_identity' => { 'state' => 'unavailable', 'reason' => 'no_input_path' } }]
    assert(Maintenance::JetifierConditions.read([p])['state'] == 'incomplete')
    t['events'][0]['input_identity'] = { 'state' => 'verified', 'identity' => { 'kind' => 'file', 'sha256' => 'd' * 64, 'bytes' => 8 } }
    assert(Maintenance::JetifierConditions.read([p])['state'] == 'review_required')
    p['data']['jetifier_conditions']['projects'][0]['enabled'] = false
    assert(Maintenance::JetifierConditions.read([p])['builds'][0]['reasons'].include?('disabled_options_with_observed_jetifier_action'))
    t['action_count'] = 0; reject { Maintenance::JetifierConditions.read([p]) }
  end
  test('planned-only or silent identity observation cannot claim disabled coverage') do
    p = packet; t = p['data']['jetifier_conditions']['transforms']; t.delete('observer_api'); t.delete('identified_count')
    assert(Maintenance::JetifierConditions.read([p])['state'] == 'incomplete')
    p = packet; t = p['data']['jetifier_conditions']['transforms']; t['action_count'] = 12
    assert(Maintenance::JetifierConditions.read([p])['state'] == 'incomplete')
    t['identified_count'] = -1; reject { Maintenance::JetifierConditions.read([p]) }
  end
  test('enabled builds and mixed old/new producers cannot gain mitigation credit') do
    p = packet(true); assert(Maintenance::JetifierConditions.read([p])['state'] == 'review_required')
    old = packet; old['data'].delete('jetifier_conditions')
    assert(Maintenance::JetifierConditions.read([packet, old])['state'] == 'incomplete')
    p = packet; p['data']['jetifier_conditions']['projects'] *= 2; reject { Maintenance::JetifierConditions.read([p]) }
  end
  if $PROGRAM_NAME == __FILE__
    failures = []
    @tests.each do |name, block|
      block.call; puts "PASS #{name}"
    rescue StandardError => error
      failures << name; warn "FAIL #{name}: #{error.message}"
    end
    puts "#{@tests.size} Jetifier condition contracts; #{failures.size} failures"
    exit(failures.empty? ? 0 : 1)
  end
end
