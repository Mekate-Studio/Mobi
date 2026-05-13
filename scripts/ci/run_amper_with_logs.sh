#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -eq 0 ]; then
  echo "Usage: run_amper_with_logs.sh <amper args...>" >&2
  exit 1
fi

project_root="$(cd "$(dirname "$0")/../.." && pwd)"
max_attempts="${AMPER_MISSING_ARTIFACT_RETRIES:-20}"
log_dir="${project_root}/build/logs"
started_at="$(date +%s)"
mkdir -p "${log_dir}"

extract_missing_dependency_path_from_file() {
  local log_path="${1:?log path required}"

  sed -n "s/.*File '\([^']*\)' was returned from dependency resolution, but is missing on disk.*/\1/p" "${log_path}" | head -n 1
}

extract_rate_limited_urls_from_file() {
  local log_path="${1:?log path required}"

  sed -n \
    -e "s#.*\(https://repo1\.maven\.org/maven2/[^ )]*\).*actual: 429.*#\1#p" \
    -e "s#.*\(https://repo\.maven\.apache\.org/maven2/[^ )]*\).*actual: 429.*#\1#p" \
    "${log_path}" \
    | sed 's/[).,:]*$//'
}

current_run_amper_logs() {
  local log_file=""

  while IFS= read -r log_file; do
    file_modified_after_start "${log_file}" || continue
    printf '%s\n' "${log_file}"
  done < <(
    find "${log_dir}" -type f \( -name 'info.log' -o -name 'debug.log' \) -exec ls -t {} + 2>/dev/null \
      | head -n 40
  )
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
  done < <(current_run_amper_logs)
}

find_rate_limited_urls() {
  local attempt_log="${1:?attempt log path required}"
  local log_file=""

  {
    extract_rate_limited_urls_from_file "${attempt_log}"
    while IFS= read -r log_file; do
      extract_rate_limited_urls_from_file "${log_file}"
    done < <(current_run_amper_logs)
  } | sort -u
}

file_modified_after_start() {
  local file_path="${1:?file path required}"
  local modified_at=""

  modified_at="$(stat -f %m "${file_path}" 2>/dev/null || stat -c %Y "${file_path}" 2>/dev/null || printf '0')"
  [[ "${modified_at}" -ge "${started_at}" ]]
}

download_artifact_path() {
  local artifact_path="${1:?artifact path required}"
  local maven_relative_path=""
  local temp_file=""

  if [[ "${artifact_path}" != *"/.m2.cache/"* ]]; then
    echo "Cannot recover missing non-Maven-cache artifact:"
    echo "  ${artifact_path}"
    return 1
  fi

  if [[ -f "${artifact_path}" ]]; then
    return 0
  fi

  mkdir -p "$(dirname "${artifact_path}")"
  maven_relative_path="${artifact_path#*/.m2.cache/}"
  download_maven_relative_path "${maven_relative_path}" "${artifact_path}"
}

download_maven_relative_path() {
  local maven_relative_path="${1:?Maven relative path required}"
  local destination_path="${2:?destination path required}"
  local artifact_url="https://repo.maven.apache.org/maven2/${maven_relative_path}"
  local temp_file=""

  mkdir -p "$(dirname "${destination_path}")"
  temp_file="${destination_path}.download"

  echo "Downloading missing Amper artifact:"
  echo "  ${artifact_url}"

  if command -v curl >/dev/null 2>&1; then
    if ! curl --fail --location --silent --show-error --retry 5 --retry-delay 2 --output "${temp_file}" "${artifact_url}"; then
      rm -f "${temp_file}"
      return 1
    fi
  elif command -v wget >/dev/null 2>&1; then
    if ! wget -q -O "${temp_file}" "${artifact_url}"; then
      rm -f "${temp_file}"
      return 1
    fi
  else
    echo "Either curl or wget is required to download ${artifact_url}" >&2
    return 1
  fi

  mv "${temp_file}" "${destination_path}"
}

checksum_base_relative_path() {
  local maven_relative_path="${1:?Maven relative path required}"

  case "${maven_relative_path}" in
    *.sha512|*.sha256|*.sha1|*.md5)
      printf '%s\n' "${maven_relative_path%.*}"
      ;;
    *)
      return 1
      ;;
  esac
}

cache_path_for_maven_relative_path() {
  local maven_relative_path="${1:?Maven relative path required}"

  printf '%s\n' "${AMPER_USER_HOME:?}/Library/Caches/JetBrains/Amper/.m2.cache/${maven_relative_path}"
}

materialize_rate_limited_url() {
  local artifact_url="${1:?artifact URL required}"
  local maven_relative_path="${artifact_url#https://repo1.maven.org/maven2/}"
  maven_relative_path="${maven_relative_path#https://repo.maven.apache.org/maven2/}"
  local destination_path=""
  local base_relative_path=""
  local base_destination_path=""
  local hydrated=0

  destination_path="$(cache_path_for_maven_relative_path "${maven_relative_path}")"

  if base_relative_path="$(checksum_base_relative_path "${maven_relative_path}")"; then
    base_destination_path="$(cache_path_for_maven_relative_path "${base_relative_path}")"
    if [[ ! -f "${base_destination_path}" ]] && download_maven_relative_path "${base_relative_path}" "${base_destination_path}"; then
      hydrated=1
    fi
  fi

  if [[ -f "${destination_path}" ]]; then
    return 0
  fi

  echo "Hydrating rate-limited Maven artifact:"
  echo "  ${artifact_url}"
  if download_maven_relative_path "${maven_relative_path}" "${destination_path}"; then
    return 0
  fi

  [[ "${hydrated}" -eq 1 ]]
}

materialize_rate_limited_urls() {
  local urls="${1:-}"
  local artifact_url=""
  local hydrated_count=0
  local failed_count=0

  while IFS= read -r artifact_url; do
    [[ -n "${artifact_url}" ]] || continue
    if materialize_rate_limited_url "${artifact_url}"; then
      hydrated_count=$((hydrated_count + 1))
    else
      failed_count=$((failed_count + 1))
    fi
  done <<<"${urls}"

  if [[ "${failed_count}" -gt 0 ]]; then
    echo "Skipped ${failed_count} rate-limited Maven URL(s) that could not be hydrated."
  fi

  [[ "${hydrated_count}" -gt 0 ]]
}

materialize_missing_dependency() {
  local artifact_path="${1:?artifact path required}"
  local artifact_dir=""
  local artifact_file=""
  local sibling_file=""

  download_artifact_path "${artifact_path}" || return 1

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
    download_artifact_path "${artifact_dir}/${sibling_file}" || true
  fi
}

attempt=1
while true; do
  attempt_log="${log_dir}/amper-command-attempt-${attempt}-$$.log"
  rate_limited_urls=""

  echo "Running Amper attempt ${attempt}/${max_attempts}: ./amper $*"

  set +e
  ./amper "$@" 2>&1 | tee "${attempt_log}"
  status=${PIPESTATUS[0]}
  set -e

  if [[ "${status}" -eq 0 ]]; then
    exit 0
  fi

  rate_limited_urls="$(find_rate_limited_urls "${attempt_log}")"
  if [[ -n "${rate_limited_urls}" && "${attempt}" -lt "${max_attempts}" ]]; then
    echo
    echo "Amper hit Maven Central rate limiting. Hydrating reported URLs sequentially and retrying..."
    if materialize_rate_limited_urls "${rate_limited_urls}"; then
      attempt=$((attempt + 1))
      sleep 5
      continue
    fi
  fi

  missing_path="$(find_missing_dependency_path "${attempt_log}")"
  if [[ -z "${missing_path}" || "${attempt}" -ge "${max_attempts}" ]]; then
    break
  fi

  echo
  echo "Amper returned a missing dependency path. Materializing it and retrying..."
  echo "  ${missing_path}"
  if ! materialize_missing_dependency "${missing_path}"; then
    echo "Could not materialize missing Amper dependency path."
    break
  fi
  attempt=$((attempt + 1))
done

echo
echo "amper failed; printing recent Amper/Xcode logs if present..."
./scripts/ci/print_recent_logs.sh amper

exit "${status}"
