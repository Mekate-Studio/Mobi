#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "${project_root}"
slice="${1:-operations}"
case "${slice}" in
  operations|nightly|release|archive) ;;
  *) printf 'Unknown manual operational slice: %s\n' "${slice}" >&2; exit 1 ;;
esac
probe_dir="${project_root}/docs/maintenance/evidence/probes"
output_dir="${project_root}/.maintenance/direct-operations-summary"
mkdir -p "${output_dir}"
quality_ruby="$(/usr/bin/ruby -r ./scripts/quality_tools.rb -e 'tools = PinnedQuality::Toolchain.new(Dir.pwd); tools.verify!; puts tools.command("ruby").first')"

# Require existing operator/runner acceptance; this probe grants no SDK license.
"${quality_ruby}" -r json -r digest -r time -e '
  sdk = ENV["ANDROID_SDK_ROOT"] || ENV["ANDROID_HOME"] || File.join(Dir.home, "Library/Android/sdk")
  licenses = Dir.glob(File.join(sdk, "licenses", "*")).select { |file| File.file?(file) }
  raise "SDK with preexisting operator-accepted licenses is required" if licenses.empty?
  receipt = { schema: 1, observed_at: Time.now.utc.iso8601, license_acceptance: "preexisting_operator_or_runner", license_files: licenses.to_h { |file| [File.basename(file), Digest::SHA256.file(file).hexdigest] }, repository_cache_restore: "none", empty_host_proven: false }
  File.write(ARGV.fetch(0), JSON.pretty_generate(receipt) + "\n")
' "${output_dir}/setup.json"

set +e
"${quality_ruby}" "${probe_dir}/direct_release_probe.rb" run "${project_root}" "${slice}" >"${output_dir}/coordinator.log" 2>&1
assessment_exit=$?
set -e

run_id="$("${quality_ruby}" -r json -e '
  paths = Dir.glob(".maintenance/runs-ios-" + ARGV.fetch(0) + "/*.result.json")
  raise "Expected one complete manual producer" unless paths.size == 1
  puts JSON.parse(File.read(paths.first)).fetch("run_id")
' "${slice}")"
./scripts/dev/dependency_updates.sh recover "${run_id}" --store "ios-${slice}" >"${output_dir}/recovery.json"
./scripts/dev/dependency_updates.sh cleanup "${run_id}" --apply --discard --store "ios-${slice}" >"${output_dir}/cleanup.json"
"${quality_ruby}" "${probe_dir}/verify_direct_release.rb" "${project_root}" "${run_id}" "${slice}" >"${output_dir}/receipt.json"
exit "${assessment_exit}"
