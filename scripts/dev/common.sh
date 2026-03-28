#!/usr/bin/env bash

set -euo pipefail

dev_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${dev_script_dir}/../.." && pwd)"

# Reuse the same toolchain/bootstrap setup as CI so local runs behave consistently.
source "${project_root}/scripts/ci/lib.sh"
