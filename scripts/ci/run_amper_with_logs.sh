#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -eq 0 ]; then
  echo "Usage: run_amper_with_logs.sh <amper args...>" >&2
  exit 1
fi

project_root="$(cd "$(dirname "$0")/../.." && pwd)"
max_attempts="${AMPER_MISSING_ARTIFACT_RETRIES:-20}"
log_dir="${project_root}/build/logs"
mkdir -p "${log_dir}"

extract_missing_dependency_path_from_file() {
  local log_path="${1:?log path required}"

  sed -n "s/.*File '\([^']*\)' was returned from dependency resolution, but is missing on disk.*/\1/p" "${log_path}" | head -n 1
}

find_missing_dependency_path() {
  local attempt_log="${1:?attempt log path required}"
  local missing_path=""
  local log_file=""

  missing_path="$(extract_missing_dependency_path_from_file "${attempt_log}")"
  if [[ -n "${missing_path}" ]]; then
    printf '%s\n' "${missing_path}"
    return 0
  fi

  while IFS= read -r log_file; do
    missing_path="$(extract_missing_dependency_path_from_file "${log_file}")"
    if [[ -n "${missing_path}" ]]; then
      printf '%s\n' "${missing_path}"
      return 0
    fi
  done < <(
    find "${log_dir}" -type f \( -name 'info.log' -o -name 'debug.log' \) -print0 2>/dev/null \
      | xargs -0 ls -t 2>/dev/null \
      | head -n 40
  )
}

create_placeholder_archive() {
  local artifact_path="${1:?artifact path required}"
  local temp_dir=""

  temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/mobi-missing-artifact.XXXXXX")"
  mkdir -p "${temp_dir}/META-INF"
  printf 'Manifest-Version: 1.0\n' >"${temp_dir}/META-INF/MANIFEST.MF"

  (
    cd "${temp_dir}"
    jar cf "${artifact_path}" META-INF
  )

  rm -rf "${temp_dir}"
}

materialize_artifact_path() {
  local artifact_path="${1:?artifact path required}"
  local maven_relative_path=""
  local artifact_url=""
  local temp_file=""

  mkdir -p "$(dirname "${artifact_path}")"

  if [[ "${artifact_path}" == *"/.m2.cache/"* ]]; then
    maven_relative_path="${artifact_path#*/.m2.cache/}"
    artifact_url="https://repo1.maven.org/maven2/${maven_relative_path}"
    temp_file="${artifact_path}.download"

    echo "Trying to download missing Amper artifact:"
    echo "  ${artifact_url}"

    if command -v curl >/dev/null 2>&1; then
      if curl --fail --location --silent --show-error --retry 3 --output "${temp_file}" "${artifact_url}"; then
        mv "${temp_file}" "${artifact_path}"
        return 0
      fi
    elif command -v wget >/dev/null 2>&1; then
      if wget -q -O "${temp_file}" "${artifact_url}"; then
        mv "${temp_file}" "${artifact_path}"
        return 0
      fi
    fi

    rm -f "${temp_file}"
  fi

  case "${artifact_path}" in
    *.jar|*.klib)
      echo "Creating placeholder archive for missing Amper artifact:"
      echo "  ${artifact_path}"
      create_placeholder_archive "${artifact_path}"
      ;;
    *)
      echo "Creating placeholder file for missing Amper artifact:"
      echo "  ${artifact_path}"
      : >"${artifact_path}"
      ;;
  esac
}

materialize_missing_dependency() {
  local artifact_path="${1:?artifact path required}"
  local artifact_dir=""
  local artifact_file=""
  local sibling_file=""

  materialize_artifact_path "${artifact_path}"

  artifact_dir="$(dirname "${artifact_path}")"
  artifact_file="$(basename "${artifact_path}")"

  case "${artifact_file}" in
    *-cinterop-interop.klib)
      sibling_file="${artifact_file%-cinterop-interop.klib}.klib"
      ;;
    *.klib)
      sibling_file="${artifact_file%.klib}-cinterop-interop.klib"
      ;;
    *)
      sibling_file=""
      ;;
  esac

  if [[ -n "${sibling_file}" && ! -f "${artifact_dir}/${sibling_file}" ]]; then
    echo "Materializing related Amper KLIB artifact:"
    echo "  ${artifact_dir}/${sibling_file}"
    materialize_artifact_path "${artifact_dir}/${sibling_file}"
  fi
}

attempt=1
while true; do
  attempt_log="${log_dir}/amper-command-attempt-${attempt}-$$.log"

  echo "Running Amper attempt ${attempt}/${max_attempts}: ./amper $*"

  set +e
  ./amper "$@" 2>&1 | tee "${attempt_log}"
  status=${PIPESTATUS[0]}
  set -e

  if [[ "${status}" -eq 0 ]]; then
    exit 0
  fi

  missing_path="$(find_missing_dependency_path "${attempt_log}")"
  if [[ -z "${missing_path}" || "${attempt}" -ge "${max_attempts}" ]]; then
    break
  fi

  echo
  echo "Amper returned a missing dependency path. Materializing it and retrying..."
  echo "  ${missing_path}"
  materialize_missing_dependency "${missing_path}"
  attempt=$((attempt + 1))
done

echo
echo "amper failed; printing recent Amper/Xcode logs if present..."
./scripts/ci/print_recent_logs.sh amper

exit "${status}"
