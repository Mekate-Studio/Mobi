#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
source "${script_dir}/common.sh"

status=0

pass() {
  echo "[ok] $1"
}

warn() {
  echo "[warn] $1"
}

fail() {
  echo "[fail] $1"
  status=1
}

check_cmd() {
  local cmd="$1"
  local label="${2:-$1}"

  if command -v "${cmd}" >/dev/null 2>&1; then
    pass "${label}: $(command -v "${cmd}")"
  else
    fail "${label}: missing"
  fi
}

check_optional_cmd() {
  local cmd="$1"
  local label="${2:-$1}"

  if command -v "${cmd}" >/dev/null 2>&1; then
    pass "${label}: $(command -v "${cmd}")"
  else
    warn "${label}: not installed"
  fi
}

print_emulator_help() {
  local emulator_cmd=""
  local found=0
  local avd=""

  if [[ -n "${ANDROID_SDK_ROOT:-}" && -x "${ANDROID_SDK_ROOT}/emulator/emulator" ]]; then
    emulator_cmd="${ANDROID_SDK_ROOT}/emulator/emulator"
  elif [[ -n "${ANDROID_HOME:-}" && -x "${ANDROID_HOME}/emulator/emulator" ]]; then
    emulator_cmd="${ANDROID_HOME}/emulator/emulator"
  elif command -v emulator >/dev/null 2>&1; then
    emulator_cmd="$(command -v emulator)"
  fi

  if [[ -z "${emulator_cmd}" ]]; then
    return 0
  fi

  while IFS= read -r avd; do
    [[ -n "${avd}" ]] || continue
    if [[ "${found}" -eq 0 ]]; then
      echo "Available Android emulators:"
    fi
    found=1
    echo "  ${avd}"
  done < <("${emulator_cmd}" -list-avds 2>/dev/null || true)

  if [[ "${found}" -eq 1 ]]; then
    warn "Start one with: ${emulator_cmd} -avd <name>"
  fi
}

detect_android_sdk_root() {
  local adb_path=""
  local sdk_root=""

  if [[ -n "${ANDROID_SDK_ROOT:-}" ]]; then
    echo "${ANDROID_SDK_ROOT}"
    return 0
  fi

  if [[ -n "${ANDROID_HOME:-}" ]]; then
    echo "${ANDROID_HOME}"
    return 0
  fi

  if ! command -v adb >/dev/null 2>&1; then
    return 1
  fi

  adb_path="$(command -v adb)"
  sdk_root="$(cd "$(dirname "${adb_path}")/.." && pwd)"

  if [[ -d "${sdk_root}/platform-tools" ]]; then
    echo "${sdk_root}"
    return 0
  fi

  return 1
}

print_android_devices() {
  local found=0
  local line=""

  if ! command -v adb >/dev/null 2>&1; then
    return 0
  fi

  while IFS= read -r line; do
    [[ -n "${line}" ]] || continue
    found=1
    echo "  ${line}"
  done < <(adb devices | awk 'NR > 1 && $2 == "device" { print $1 " (ready)" }')

  if [[ "${found}" -eq 0 ]]; then
    warn "Android devices: none ready"
    print_emulator_help
  else
    pass "Android devices listed above"
  fi
}

echo "Developer environment doctor"
echo "Project root: ${project_root}"
echo "AMPER_BOOTSTRAP_CACHE_DIR: ${AMPER_BOOTSTRAP_CACHE_DIR}"

check_cmd java "Java"
check_cmd ruby "Ruby"
check_cmd bundle "Bundler"
check_cmd adb "Android Debug Bridge"
check_cmd xcodebuild "Xcode build tools"

detected_android_sdk_root="$(detect_android_sdk_root || true)"

if [[ -n "${ANDROID_SDK_ROOT:-}" ]]; then
  pass "ANDROID_SDK_ROOT: ${ANDROID_SDK_ROOT}"
elif [[ -n "${ANDROID_HOME:-}" ]]; then
  pass "ANDROID_HOME: ${ANDROID_HOME}"
elif [[ -n "${detected_android_sdk_root}" ]]; then
  warn "ANDROID_HOME / ANDROID_SDK_ROOT not set; inferred SDK at ${detected_android_sdk_root}"
else
  warn "ANDROID_HOME / ANDROID_SDK_ROOT not set"
fi

if [[ -d "${project_root}/.run" ]]; then
  pass "Shared run configs: ${project_root}/.run"
else
  fail "Shared run configs directory missing"
fi

if [[ -f "${project_root}/ios-app/module.xcodeproj/project.pbxproj" ]]; then
  pass "iOS Xcode project present"
else
  fail "iOS Xcode project missing"
fi

print_android_devices

echo
echo "Optional quality tools"
check_optional_cmd ktlint "ktlint"
check_optional_cmd detekt "detekt"
check_optional_cmd swiftformat "SwiftFormat"
check_optional_cmd swiftlint "SwiftLint"
check_optional_cmd shellcheck "ShellCheck"

echo
if [[ "${status}" -eq 0 ]]; then
  echo "Doctor finished without blocking issues."
else
  echo "Doctor found blocking issues."
fi

exit "${status}"
