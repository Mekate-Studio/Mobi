#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "$0")/../.." && pwd)"
generated_gradle_project="${project_root}/build/tasks/_android-app_buildAndroidRelease/gradle-project"

if [[ ! -d "${generated_gradle_project}" ]]; then
  echo "Generated Android Gradle project not found at ${generated_gradle_project}" >&2
  exit 1
fi

export GRADLE_USER_HOME="${GRADLE_USER_HOME:-${project_root}/.gradle-user-home}"
mkdir -p "${GRADLE_USER_HOME}"

if [[ -x /usr/libexec/java_home ]]; then
  export JAVA_HOME="${JAVA_HOME:-$(/usr/libexec/java_home)}"
fi

gradle_bin="${GRADLE_BIN:-}"

if [[ -z "${gradle_bin}" ]]; then
  gradle_bin="$(find "${HOME}/.gradle/wrapper/dists/gradle-8.14.3-bin" -path '*/gradle-8.14.3/bin/gradle' -type f 2>/dev/null | head -n 1 || true)"
fi

if [[ -z "${gradle_bin}" ]]; then
  gradle_bin="$(command -v gradle || true)"
fi

if [[ -z "${gradle_bin}" ]]; then
  echo "No Gradle binary found for building the Android App Bundle" >&2
  exit 1
fi

cd "${generated_gradle_project}"

"${gradle_bin}" \
  --no-daemon \
  -p "${generated_gradle_project}" \
  bundleRelease
