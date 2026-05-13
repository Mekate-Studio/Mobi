#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "$0")/../.." && pwd)"
log_dir="${project_root}/build/logs"
derived_data_dir="${project_root}/build/xcode-derived-data-cli-tests"
log_file="${log_dir}/xcodebuild-ios-tests.log"
workspace_path="${project_root}/ios-app/module.xcodeproj/project.xcworkspace"
workspace_contents_path="${workspace_path}/contents.xcworkspacedata"
project_path="${project_root}/ios-app/module.xcodeproj"

mkdir -p "${log_dir}" "${derived_data_dir}"

echo "Using KOTLIN_IOS_BUILDER=${KOTLIN_IOS_BUILDER:-gradle}"
echo "Using GRADLE_USER_HOME=${GRADLE_USER_HOME:-${project_root}/.gradle-user-home}"
echo "Using SWIFT_ENABLE_EXPLICIT_MODULES=${SWIFT_ENABLE_EXPLICIT_MODULES:-NO}"

# shellcheck source=./lib/xcode.sh
source "${project_root}/scripts/ci/lib/xcode.sh"
skip_macro_validation="$(ci_resolve_skip_macro_validation)"

echo "Using SKIP_MACRO_VALIDATION=${skip_macro_validation}"

cmd=(xcodebuild)

if [[ -f "${workspace_contents_path}" ]]; then
  echo "Using Xcode workspace=${workspace_path}"
  cmd+=(-workspace "${workspace_path}")
else
  echo "Using Xcode project=${project_path} (workspace metadata missing)"
  cmd+=(-project "${project_path}")
fi

if [[ "${skip_macro_validation}" == "YES" ]]; then
  cmd+=(-skipMacroValidation)
fi

resolve_simulator_destination() {
  if [[ -n "${IOS_SIMULATOR_DESTINATION:-}" ]]; then
    printf '%s\n' "${IOS_SIMULATOR_DESTINATION}"
    return
  fi

  "${cmd[@]}" -scheme app -showdestinations 2>&1 | ruby -e '
    destination = STDIN.each_line.find do |entry|
      entry.include?("{ platform:iOS Simulator") &&
        entry.include?("name:iPhone") &&
        !entry.include?("placeholder")
    end

    abort("No Xcode-eligible iPhone simulator destination found") unless destination

    simulator_id = destination[/id:([^, }]+)/, 1]
    abort("No simulator id found in destination: #{destination}") unless simulator_id

    puts "platform=iOS Simulator,id=#{simulator_id}"
  '
}

simulator_destination="$(resolve_simulator_destination)"
echo "Using iOS simulator destination=${simulator_destination}"

cmd+=(
  -scheme app
  -configuration Debug
  -destination "${simulator_destination}"
  -derivedDataPath "${derived_data_dir}"
  "SWIFT_ENABLE_EXPLICIT_MODULES=${SWIFT_ENABLE_EXPLICIT_MODULES:-NO}"
  test
)

if command -v xcbeautify >/dev/null 2>&1; then
  set -o pipefail
  "${cmd[@]}" 2>&1 | tee "${log_file}" | xcbeautify
else
  "${cmd[@]}" 2>&1 | tee "${log_file}"
fi
