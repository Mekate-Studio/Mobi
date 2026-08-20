#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "$0")/../.." && pwd)"
generated_gradle_project="${project_root}/build/tasks/_android-app_buildAndroidRelease/gradle-project"
generated_release_bundle_dir="${generated_gradle_project}/build/_android-app/outputs/bundle/release"
release_output_dir="${project_root}/build/releases/android"
release_output_path="${release_output_dir}/android-app-release.aab"

resolve_generated_gradle_version() {
  local candidate=""
  local newest_execution_history=""

  for candidate in "${generated_gradle_project}"/.gradle/*/executionHistory; do
    [[ -d "${candidate}" ]] || continue

    if [[ -z "${newest_execution_history}" || "${candidate}" -nt "${newest_execution_history}" ]]; then
      newest_execution_history="${candidate}"
    fi
  done

  if [[ -n "${newest_execution_history}" ]]; then
    basename "$(dirname "${newest_execution_history}")"
  fi
}

resolve_gradle_bin() {
  local gradle_bin="${GRADLE_BIN:-}"
  local generated_gradle_version=""
  local wrapper_root=""

  if [[ -n "${gradle_bin}" ]]; then
    printf '%s\n' "${gradle_bin}"
    return 0
  fi

  generated_gradle_version="$(resolve_generated_gradle_version)"
  if [[ -z "${generated_gradle_version}" ]]; then
    return 0
  fi

  wrapper_root="${GRADLE_USER_HOME}/wrapper/dists/gradle-${generated_gradle_version}-bin"

  gradle_bin="$(find "${wrapper_root}" -path "*/gradle-${generated_gradle_version}/bin/gradle" -type f 2>/dev/null | head -n 1 || true)"
  if [[ -n "${gradle_bin}" ]]; then
    printf '%s\n' "${gradle_bin}"
    return 0
  fi
}

find_release_aab() {
  find "${generated_release_bundle_dir}" -maxdepth 1 -type f -name '*.aab' | head -n 1 || true
}

if [[ ! -d "${generated_gradle_project}" ]]; then
  echo "Generated Android Gradle project not found at ${generated_gradle_project}" >&2
  exit 1
fi

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

gradle_bin="$(resolve_gradle_bin)"

if [[ -z "${gradle_bin}" ]]; then
  echo "No matching Gradle binary found for the generated Android project" >&2
  exit 1
fi

echo "Using generated-project Gradle: ${gradle_bin}"

cd "${generated_gradle_project}"

android_aab_gradle_jvm_args="${ANDROID_AAB_GRADLE_JVM_ARGS:--Xmx4g -XX:MaxMetaspaceSize=1g -Dfile.encoding=UTF-8}"
android_aab_max_workers="${ANDROID_AAB_MAX_WORKERS:-2}"
rm -f "${release_output_path}"

"${gradle_bin}" \
  -Dorg.gradle.jvmargs="${android_aab_gradle_jvm_args}" \
  --no-daemon \
  --max-workers="${android_aab_max_workers}" \
  -p "${generated_gradle_project}" \
  :android-app:bundleRelease

aab_path="$(find_release_aab)"

if [[ -z "${aab_path}" ]]; then
  echo "No Android App Bundle found after bundleRelease" >&2
  exit 1
fi

mkdir -p "${release_output_dir}"
cp "${aab_path}" "${release_output_path}"
echo "Built Android App Bundle: ${release_output_path}"
