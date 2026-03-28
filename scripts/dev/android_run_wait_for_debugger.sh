#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
source "${script_dir}/android_common.sh"

result="$(android_build_install_and_launch "-D" "$@")"
device_serial="${result%%|*}"
apk_path="${result#*|}"

echo "Installed ${apk_path} on ${device_serial}."
echo "The app is waiting for a debugger."
echo "In Android Studio or IntelliJ IDEA, use Run > Attach debugger to Android process and pick ${android_package_name}."
