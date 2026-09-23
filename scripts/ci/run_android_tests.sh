#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${project_root}"
module_list="$(ruby scripts/ci/test_modules.rb)"
if [[ -z "${module_list}" ]]; then
  printf 'No supported host-test modules were discovered.\n' >&2
  exit 1
fi

while IFS= read -r module_name; do
  ./scripts/ci/run_kotlin_with_logs.sh test -m "${module_name}" -p android "$@"
done <<<"${module_list}"
