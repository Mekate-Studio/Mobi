#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
source "${script_dir}/common.sh"

package_name="studio.mekate.b3"
main_activity="${package_name}.MainActivity"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

select_device() {
  local devices=()
  local device=""

  while IFS= read -r device; do
    [[ -n "${device}" ]] || continue
    devices+=("${device}")
  done < <(adb devices | awk 'NR > 1 && $2 == "device" { print $1 }')

  if [[ ${#devices[@]} -eq 0 ]]; then
    echo "No Android device or emulator is ready. Start one, then run again." >&2
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

latest_debug_apk() {
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

require_cmd adb

device_serial="$(select_device)"

cd "${project_root}"
./scripts/ci/run_job.sh android-build-debug "$@"

apk_path="$(latest_debug_apk)"

adb -s "${device_serial}" install -r "${apk_path}"
adb -s "${device_serial}" shell am start -n "${package_name}/${main_activity}"

echo "Installed ${apk_path} on ${device_serial} and launched ${main_activity}."
