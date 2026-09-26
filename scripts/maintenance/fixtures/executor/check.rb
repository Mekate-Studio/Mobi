# frozen_string_literal: true

require 'json'

file, cache, output, scenario = ARGV
phase = ENV.fetch('MOBI_PHASE')
raise 'Caller credentials leaked' if %w[GITHUB_TOKEN AWS_SECRET_ACCESS_KEY RUBYOPT JAVA_TOOL_OPTIONS DATABASE_URL].any? { |key| ENV.key?(key) }
raise 'Git metadata copied' if File.exist?('.git')
raise 'Mutable cache crossed phase boundary' if File.exist?(File.join(cache, 'compiled.fixture'))
File.write(File.join(cache, 'compiled.fixture'), phase)
# A fake database resource is a file; no PostgreSQL process or connection exists.
File.write(File.join(output, 'database.fixture'), phase)
File.write(File.join(output, 'started.fixture'), Process.pid.to_s)
if scenario == 'barrier'
  sleep 0.02 until File.exist?(File.join(output, 'continue.fixture'))
end
if scenario == 'timeout'
  trap('TERM') { }
  sleep 60
end
if scenario == 'child-survivor'
  child = fork { trap('TERM') { }; sleep 60 }
  puts "owned_child=#{child}"
end
File.write(file, 'unexpected mutation') if scenario == 'source-drift'
status = File.read(file).match?(/\Adependency=1\.0\.[01]\n\z/) ? 'passed' : 'failed'
status = scenario if %w[missing infrastructure].include?(scenario)
result = { 'schema' => 1, 'check' => 'behavior', 'phase' => phase, 'status' => status }
File.write(ENV.fetch('MOBI_RESULT_PATH'), scenario == 'malformed' ? '{truncated' : JSON.generate(result))
exit 7 if scenario == 'forged-success'
exit(status == 'passed' ? 0 : 1)
