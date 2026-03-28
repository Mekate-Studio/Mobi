#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
source "${script_dir}/common.sh"

cd "${project_root}"
./scripts/ci/run_job.sh ios-build-debug "$@"
