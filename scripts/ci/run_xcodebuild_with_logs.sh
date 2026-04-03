#!/usr/bin/env bash

set -euo pipefail

configuration="${1:-}"

if [[ -z "${configuration}" ]]; then
  echo "Usage: run_xcodebuild_with_logs.sh <Debug|Release>" >&2
  exit 1
fi

project_root="$(cd "$(dirname "$0")/../.." && pwd)"
configuration_slug="$(printf '%s' "${configuration}" | tr '[:upper:]' '[:lower:]')"
log_dir="${project_root}/build/logs"
derived_data_dir="${project_root}/build/xcode-derived-data-cli-${configuration_slug}"
log_file="${log_dir}/xcodebuild-ios-${configuration}.log"
workspace_path="${project_root}/ios-app/module.xcodeproj/project.xcworkspace"
workspace_contents_path="${workspace_path}/contents.xcworkspacedata"
project_path="${project_root}/ios-app/module.xcodeproj"

mkdir -p "${log_dir}" "${derived_data_dir}"

echo "Using KOTLIN_IOS_BUILDER=${KOTLIN_IOS_BUILDER:-gradle}"
echo "Using GRADLE_USER_HOME=${GRADLE_USER_HOME:-${project_root}/.gradle-user-home}"
echo "Using SWIFT_ENABLE_EXPLICIT_MODULES=${SWIFT_ENABLE_EXPLICIT_MODULES:-NO}"

cmd=(xcodebuild)

if [[ -f "${workspace_contents_path}" ]]; then
  echo "Using Xcode workspace=${workspace_path}"
  cmd+=(-workspace "${workspace_path}")
else
  echo "Using Xcode project=${project_path} (workspace metadata missing)"
  cmd+=(-project "${project_path}")
fi

cmd+=(
  -scheme app
  -configuration "${configuration}"
  -destination "generic/platform=iOS Simulator"
  -derivedDataPath "${derived_data_dir}"
  CODE_SIGNING_ALLOWED=NO
  CODE_SIGNING_REQUIRED=NO
  "SWIFT_ENABLE_EXPLICIT_MODULES=${SWIFT_ENABLE_EXPLICIT_MODULES:-NO}"
  build
)

if command -v xcbeautify >/dev/null 2>&1; then
  set -o pipefail
  "${cmd[@]}" 2>&1 | tee "${log_file}" | xcbeautify
else
  "${cmd[@]}" 2>&1 | tee "${log_file}"
fi
