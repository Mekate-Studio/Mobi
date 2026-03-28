#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
source "${script_dir}/android_common.sh"

avd_name="${1:-}"

if [[ -z "${avd_name}" ]]; then
  echo "Usage: $0 <avd-name>" >&2
  echo >&2
  android_print_available_emulators >&2
  exit 1
fi

emulator_cmd="$(android_find_emulator_cmd)"

if [[ -z "${emulator_cmd}" ]]; then
  echo "Android emulator tool not found." >&2
  exit 1
fi

if ! android_avd_exists "${avd_name}"; then
  echo "Unknown Android emulator: ${avd_name}" >&2
  echo >&2
  android_print_available_emulators >&2
  exit 1
fi

log_dir="${project_root}/build/logs"
log_file="${log_dir}/android-emulator-${avd_name}.log"

mkdir -p "${log_dir}"
nohup "${emulator_cmd}" -avd "${avd_name}" >"${log_file}" 2>&1 &

echo "Starting Android emulator '${avd_name}'."
echo "Log: ${log_file}"
echo "Wait for it to finish booting, then run 'just android-run' or 'just android-run-debug'."
