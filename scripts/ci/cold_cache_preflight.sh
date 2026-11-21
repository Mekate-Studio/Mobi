#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${project_root}"

cache_roots=(build .kotlin-cache .kotlin-user-home .gradle-user-home .quality ios-app/Dependencies/.build)
for path in "${cache_roots[@]}"; do
  if [[ -e "${path}" || -L "${path}" ]]; then
    echo "Cold validation requires an absent cache/output path: ${path}" >&2
    exit 1
  fi
done

# Check before writing the receipt; preserve existing files on refusal.
mkdir -p build/logs/cold-cache
printf 'Verified absent before setup: %s\n' "${cache_roots[@]}" \
  | tee build/logs/cold-cache/preflight.log
