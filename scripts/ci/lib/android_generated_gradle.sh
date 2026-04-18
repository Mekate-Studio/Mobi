#!/usr/bin/env bash

android_generated_gradle_version="${ANDROID_GENERATED_GRADLE_VERSION:-8.14.3}"
android_generated_gradle_distribution_type="${ANDROID_GENERATED_GRADLE_DISTRIBUTION_TYPE:-bin}"
android_generated_gradle_distribution_file="gradle-${android_generated_gradle_version}-${android_generated_gradle_distribution_type}.zip"
android_generated_gradle_distribution_url="https://services.gradle.org/distributions/${android_generated_gradle_distribution_file}"

android_generated_gradle_distribution_id() {
  local distribution_url="${1:-${android_generated_gradle_distribution_url}}"

  python3 - "${distribution_url}" <<'PYTHON'
import hashlib
import sys

url = sys.argv[1]
value = int(hashlib.md5(url.encode()).hexdigest(), 16)
chars = '0123456789abcdefghijklmnopqrstuvwxyz'
out = ''
while value:
    value, rem = divmod(value, 36)
    out = chars[rem] + out
print(out or '0')
PYTHON
}
