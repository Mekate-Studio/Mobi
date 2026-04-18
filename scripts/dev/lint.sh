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

quality_collect_shell_files() {
  local file=""

  while IFS= read -r -d '' file; do
    shell_files+=("${file}")
  done < <(find scripts -type f -name '*.sh' -print0)
}

quality_collect_detekt_inputs() {
  local candidate=""

  for candidate in \
    android-app/src \
    android-app/test \
    shared-core/src \
    shared-core/src@ios \
    shared-core/test \
    shared-di/src \
    shared-di/test \
    shared-feature-home/src \
    shared-feature-home/test \
    shared-ui-home/src \
    shared-ui-home/src@ios
  do
    if [[ -d "${project_root}/${candidate}" ]]; then
      detekt_inputs+=("${project_root}/${candidate}")
    fi
  done
}

quality_join_detekt_inputs() {
  local candidate=""

  detekt_input_csv=""

  for candidate in "${detekt_inputs[@]}"; do
    if [[ -n "${detekt_input_csv}" ]]; then
      detekt_input_csv="${detekt_input_csv},"
    fi

    detekt_input_csv="${detekt_input_csv}${candidate}"
  done
}

quality_prepare_path
cd "${project_root}"

quality_require_cmd ktlint
quality_require_cmd detekt
quality_require_cmd swiftformat
quality_require_cmd swiftlint
quality_require_cmd shellcheck

kotlin_files=()
quality_collect_kotlin_files

if [[ "${#kotlin_files[@]}" -gt 0 ]]; then
  ktlint "${kotlin_files[@]}"
fi

detekt_inputs=()
quality_collect_detekt_inputs
quality_join_detekt_inputs

if [[ -n "${detekt_input_csv}" ]]; then
  detekt \
    --build-upon-default-config \
    --config "${project_root}/detekt.yml" \
    --input "${detekt_input_csv}"
fi

swiftformat \
  --cache ignore \
  --lint \
  --config "${project_root}/.swiftformat" \
  "${project_root}/ios-app/src" \
  "${project_root}/ios-app/tests"

swiftlint lint --strict --no-cache --config "${project_root}/.swiftlint.yml"

shell_files=()
quality_collect_shell_files

if [[ "${#shell_files[@]}" -gt 0 ]]; then
  shellcheck --external-sources --source-path=SCRIPTDIR "${shell_files[@]}"
fi
