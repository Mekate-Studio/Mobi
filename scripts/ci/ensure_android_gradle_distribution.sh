#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./lib/android_generated_gradle.sh
source "${script_dir}/lib/android_generated_gradle.sh"

gradle_user_home="${GRADLE_USER_HOME:-${HOME}/.gradle}"
wrapper_root="${gradle_user_home}/wrapper/dists/gradle-${android_generated_gradle_version}-${android_generated_gradle_distribution_type}"
distribution_id="$(android_generated_gradle_distribution_id)"
install_dir="${wrapper_root}/${distribution_id}"
unpacked_dir="${install_dir}/gradle-${android_generated_gradle_version}"
marker_file="${install_dir}/${android_generated_gradle_distribution_file}.ok"

if [[ -d "${unpacked_dir}" ]]; then
  mkdir -p "${install_dir}"
  touch "${marker_file}"
  exit 0
fi

mkdir -p "${install_dir}"

temp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "${temp_dir}"
}
trap cleanup EXIT

temp_zip="${temp_dir}/${android_generated_gradle_distribution_file}"

if command -v curl >/dev/null 2>&1; then
  curl \
    -L \
    --fail \
    --retry 5 \
    --retry-delay 2 \
    --connect-timeout 30 \
    --max-time 900 \
    --output "${temp_zip}" \
    "${android_generated_gradle_distribution_url}"
elif command -v wget >/dev/null 2>&1; then
  wget \
    --tries=5 \
    --connect-timeout=30 \
    --read-timeout=120 \
    -O "${temp_zip}" \
    "${android_generated_gradle_distribution_url}"
else
  echo "Either curl or wget is required to download ${android_generated_gradle_distribution_file}" >&2
  exit 1
fi

rm -rf "${unpacked_dir}"
unzip -q "${temp_zip}" -d "${install_dir}"
touch "${marker_file}"
