#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
source "${script_dir}/common.sh"

mode=precommit
if [[ "${1:-}" == --static ]]; then
  mode=static
  shift
fi

dev_run_quality "${mode}" "$@"
