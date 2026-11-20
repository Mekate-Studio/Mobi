#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "$0")/../.." && pwd)"
# Final Toolchain package output; keep this locator reviewed on Toolchain updates.
aab_path="${project_root}/build/tasks/_android-app_bundleAndroid/gradle-project-release.aab"
release_output_dir="${project_root}/build/releases/android"
release_output_path="${release_output_dir}/android-app-release.aab"

cd "${project_root}"
rm -f "${release_output_path}"
for retired_override in GRADLE_BIN ANDROID_AAB_GRADLE_JVM_ARGS ANDROID_AAB_MAX_WORKERS; do
  if [[ -n "${!retired_override:-}" ]]; then
    echo "${retired_override} is retired; kotlin package now owns delegated Gradle execution." >&2
    exit 1
  fi
done

export GRADLE_USER_HOME="${GRADLE_USER_HOME:-${project_root}/.gradle-user-home}"
mkdir -p "${GRADLE_USER_HOME}"

if [[ -x /usr/libexec/java_home ]]; then
  preferred_java_home="$(/usr/libexec/java_home -v 21 2>/dev/null || true)"
  if [[ -n "${preferred_java_home}" ]]; then
    export JAVA_HOME="${JAVA_HOME:-${preferred_java_home}}"
  else
    export JAVA_HOME="${JAVA_HOME:-$(/usr/libexec/java_home)}"
  fi
fi

./scripts/ci/run_kotlin_with_logs.sh package -m android-app

if [[ ! -f "${aab_path}" || -L "${aab_path}" ]]; then
  echo "No Android App Bundle regular file found after kotlin package: ${aab_path}" >&2
  exit 1
fi

mkdir -p "${release_output_dir}"
cp "${aab_path}" "${release_output_path}"
echo "Built Android App Bundle: ${release_output_path}"
