#!/usr/bin/env bash

set -euo pipefail

gradle_version="8.14.3"
distribution_type="bin"
distribution_file="gradle-${gradle_version}-${distribution_type}.zip"
distribution_url="https://services.gradle.org/distributions/${distribution_file}"
gradle_user_home="${GRADLE_USER_HOME:-${HOME}/.gradle}"
wrapper_root="${gradle_user_home}/wrapper/dists/gradle-${gradle_version}-${distribution_type}"

compute_distribution_id() {
  python3 - <<'PY'
import hashlib
url = "https://services.gradle.org/distributions/gradle-8.14.3-bin.zip"
value = int(hashlib.md5(url.encode()).hexdigest(), 16)
chars = '0123456789abcdefghijklmnopqrstuvwxyz'
out = ''
while value:
    value, rem = divmod(value, 36)
    out = chars[rem] + out
print(out or '0')
PY
}

distribution_id="$(compute_distribution_id)"
install_dir="${wrapper_root}/${distribution_id}"
unpacked_dir="${install_dir}/gradle-${gradle_version}"
marker_file="${install_dir}/${distribution_file}.ok"

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

temp_zip="${temp_dir}/${distribution_file}"

if command -v curl >/dev/null 2>&1; then
  curl \
    -L \
    --fail \
    --retry 5 \
    --retry-delay 2 \
    --connect-timeout 30 \
    --max-time 900 \
    --output "${temp_zip}" \
    "${distribution_url}"
elif command -v wget >/dev/null 2>&1; then
  wget \
    --tries=5 \
    --connect-timeout=30 \
    --read-timeout=120 \
    -O "${temp_zip}" \
    "${distribution_url}"
else
  echo "Either curl or wget is required to download ${distribution_file}" >&2
  exit 1
fi

rm -rf "${unpacked_dir}"
unzip -q "${temp_zip}" -d "${install_dir}"
touch "${marker_file}"
