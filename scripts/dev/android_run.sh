#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
source "${script_dir}/android_common.sh"

result="$(android_build_install_and_launch "" "$@")"
device_serial="${result%%|*}"
apk_path="${result#*|}"

echo "Installed ${apk_path} on ${device_serial} and launched ${android_main_activity}."
