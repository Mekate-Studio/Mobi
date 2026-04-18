#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
source "${script_dir}/common.sh"

quality_prepare_path() {
  ci_set_java_home
  ci_resolve_android_sdk_root >/dev/null 2>&1 || true
  ci_configure_path
}

quality_require_cmd() {
  local cmd="$1"

  if ! command -v "${cmd}" >/dev/null 2>&1; then
    printf 'Required quality tool not found on PATH: %s\n' "${cmd}" >&2
    exit 1
  fi
}

quality_collect_kotlin_files() {
  local file=""

  while IFS= read -r -d '' file; do
    kotlin_files+=("${file}")
  done < <(git ls-files -z -- '*.kt' '*.kts')
}

quality_prepare_path
cd "${project_root}"

quality_require_cmd ktlint
quality_require_cmd swiftformat

kotlin_files=()
quality_collect_kotlin_files

if [[ "${#kotlin_files[@]}" -gt 0 ]]; then
  ktlint --format "${kotlin_files[@]}"
fi

swiftformat \
  --cache ignore \
  --config "${project_root}/.swiftformat" \
  "${project_root}/ios-app/src" \
  "${project_root}/ios-app/tests"
