#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
exec /usr/bin/ruby "${script_dir}/dependencies.rb" install "$@"
