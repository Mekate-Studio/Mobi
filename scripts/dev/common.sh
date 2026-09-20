#!/usr/bin/env bash

set -euo pipefail

dev_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${dev_script_dir}/../.." && pwd)"

# Reuse the same toolchain/bootstrap setup as CI so local runs behave consistently.
source "${project_root}/scripts/ci/lib.sh"

dev_run_quality() {
  ci_set_java_home
  ci_resolve_android_sdk_root >/dev/null 2>&1 || true
  ci_configure_path
  if ! command -v ruby >/dev/null 2>&1; then
    printf 'Ruby is required for quality checks; see docs/reference/local-development.md\n' >&2
    return 1
  fi
  exec ruby "${project_root}/scripts/dev/quality.rb" "$@"
}
