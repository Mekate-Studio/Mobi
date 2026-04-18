#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/common.sh"

android_package_name="studio.mekate.mobi"
android_main_activity="${android_package_name}.MainActivity"

android_require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

android_detect_sdk_root() {
  local adb_path=""
  local sdk_root=""

  if [[ -n "${ANDROID_SDK_ROOT:-}" ]]; then
    printf '%s\n' "${ANDROID_SDK_ROOT}"
    return 0
  fi

  if [[ -n "${ANDROID_HOME:-}" ]]; then
    printf '%s\n' "${ANDROID_HOME}"
    return 0
  fi

  if ! command -v adb >/dev/null 2>&1; then
    return 1
  fi

  adb_path="$(command -v adb)"
  sdk_root="$(cd "$(dirname "${adb_path}")/.." && pwd)"

  if [[ -d "${sdk_root}/platform-tools" ]]; then
    printf '%s\n' "${sdk_root}"
    return 0
  fi

  return 1
}

android_find_emulator_cmd() {
  local emulator_cmd=""
  local sdk_root=""

  if [[ -n "${ANDROID_SDK_ROOT:-}" && -x "${ANDROID_SDK_ROOT}/emulator/emulator" ]]; then
    emulator_cmd="${ANDROID_SDK_ROOT}/emulator/emulator"
  elif [[ -n "${ANDROID_HOME:-}" && -x "${ANDROID_HOME}/emulator/emulator" ]]; then
    emulator_cmd="${ANDROID_HOME}/emulator/emulator"
  else
    sdk_root="$(android_detect_sdk_root || true)"
    if [[ -n "${sdk_root}" && -x "${sdk_root}/emulator/emulator" ]]; then
      emulator_cmd="${sdk_root}/emulator/emulator"
    fi
  fi

  if [[ -z "${emulator_cmd}" ]] && command -v emulator >/dev/null 2>&1; then
    emulator_cmd="$(command -v emulator)"
  fi

  if [[ -z "${emulator_cmd}" ]] && [[ -x "${HOME}/Library/Android/sdk/emulator/emulator" ]]; then
    emulator_cmd="${HOME}/Library/Android/sdk/emulator/emulator"
  fi

  printf '%s\n' "${emulator_cmd}"
}

android_print_available_emulators() {
  local emulator_cmd=""
  local found=0
  local avd=""

  emulator_cmd="$(android_find_emulator_cmd)"

  if [[ -z "${emulator_cmd}" ]]; then
    echo "Android emulator tool not found." >&2
    return 1
  fi

  while IFS= read -r avd; do
    [[ -n "${avd}" ]] || continue
    if [[ "${found}" -eq 0 ]]; then
      echo "Available Android emulators:"
    fi
    found=1
    echo "  ${avd}"
  done < <("${emulator_cmd}" -list-avds 2>/dev/null || true)

  if [[ "${found}" -eq 0 ]]; then
    echo "No Android emulators were found." >&2
    return 1
  fi

  return 0
}

android_avd_exists() {
  local avd_name="${1:?avd name required}"
  local emulator_cmd=""
  local avd=""

  emulator_cmd="$(android_find_emulator_cmd)"

  if [[ -z "${emulator_cmd}" ]]; then
    return 1
  fi

  while IFS= read -r avd; do
    [[ "${avd}" == "${avd_name}" ]] || continue
    return 0
  done < <("${emulator_cmd}" -list-avds 2>/dev/null || true)

  return 1
}

android_print_emulator_help() {
  local emulator_cmd=""

  emulator_cmd="$(android_find_emulator_cmd)"

  if android_print_available_emulators >&2; then
    echo "Start one with: ${emulator_cmd} -avd <name>" >&2
  fi
}

android_select_device() {
  local devices=()
  local device=""

  while IFS= read -r device; do
    [[ -n "${device}" ]] || continue
    devices+=("${device}")
  done < <(adb devices | awk 'NR > 1 && $2 == "device" { print $1 }')

  if [[ ${#devices[@]} -eq 0 ]]; then
    echo "No Android device or emulator is ready. Start one, then run again." >&2
    android_print_emulator_help
    exit 1
  fi

  if [[ -n "${ANDROID_SERIAL:-}" ]]; then
    printf '%s\n' "${ANDROID_SERIAL}"
    return 0
  fi

  if [[ ${#devices[@]} -gt 1 ]]; then
    {
      echo "Multiple Android devices are connected."
      echo "Set ANDROID_SERIAL to choose one of:"
      printf '  %s\n' "${devices[@]}"
    } >&2
    exit 1
  fi

  printf '%s\n' "${devices[0]}"
}

android_latest_debug_apk() {
  local latest=""
  local candidate=""

  while IFS= read -r -d '' candidate; do
    if [[ -z "${latest}" || "${candidate}" -nt "${latest}" ]]; then
      latest="${candidate}"
    fi
  done < <(find "${project_root}/build" -type f \( -name "*debug*.apk" -o -name "*-debug.apk" \) -print0)

  if [[ -z "${latest}" ]]; then
    echo "No debug APK found under ${project_root}/build. Build may have failed." >&2
    exit 1
  fi

  printf '%s\n' "${latest}"
}

android_build_install_and_launch() {
  local launch_flag="${1:-}"
  shift || true

  local device_serial=""
  local apk_path=""

  android_require_cmd adb

  device_serial="$(android_select_device)"

  cd "${project_root}"
  ./scripts/ci/run_job.sh android-build-debug "$@"

  apk_path="$(android_latest_debug_apk)"

  adb -s "${device_serial}" install -r "${apk_path}"

  if [[ -n "${launch_flag}" ]]; then
    adb -s "${device_serial}" shell am start "${launch_flag}" -n "${android_package_name}/${android_main_activity}"
  else
    adb -s "${device_serial}" shell am start -n "${android_package_name}/${android_main_activity}"
  fi

  printf '%s\n' "${device_serial}|${apk_path}"
}
