#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "$0")/../.." && pwd)"
log_dir="${project_root}/build/logs"
derived_data_dir="${project_root}/build/xcode-derived-data-cli-tests"
log_file="${log_dir}/xcodebuild-ios-tests.log"
test_plan="${IOS_TEST_PLAN:-PullRequest}"
test_plan_slug="$(printf '%s' "${test_plan}" | tr '[:upper:]' '[:lower:]')"
result_bundle_dir="${project_root}/build/test-results"
result_bundle_path="${result_bundle_dir}/ios-${test_plan_slug}.xcresult"
workspace_path="${project_root}/ios-app/module.xcodeproj/project.xcworkspace"
workspace_contents_path="${workspace_path}/contents.xcworkspacedata"
project_path="${project_root}/ios-app/module.xcodeproj"

mkdir -p "${log_dir}" "${derived_data_dir}" "${result_bundle_dir}"
rm -rf "${result_bundle_path}"

echo "Using KOTLIN_IOS_BUILDER=${KOTLIN_IOS_BUILDER:-gradle}"
echo "Using GRADLE_USER_HOME=${GRADLE_USER_HOME:-${project_root}/.gradle-user-home}"
echo "Using SWIFT_ENABLE_EXPLICIT_MODULES=${SWIFT_ENABLE_EXPLICIT_MODULES:-NO}"
echo "Using IOS_TEST_PLAN=${test_plan}"
echo "Using result bundle=${result_bundle_path}"

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

simulator_destination="$(ci_resolve_ios_simulator_destination)"
echo "Using iOS simulator destination=${simulator_destination}"

cmd+=(
  -scheme app
  -configuration Debug
  -destination "${simulator_destination}"
  -derivedDataPath "${derived_data_dir}"
  -testPlan "${test_plan}"
  -resultBundlePath "${result_bundle_path}"
  "SWIFT_ENABLE_EXPLICIT_MODULES=${SWIFT_ENABLE_EXPLICIT_MODULES:-NO}"
  test
)

if command -v xcbeautify >/dev/null 2>&1; then
  set -o pipefail
  "${cmd[@]}" 2>&1 | tee "${log_file}" | xcbeautify
else
  "${cmd[@]}" 2>&1 | tee "${log_file}"
fi
