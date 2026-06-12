#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_dir}/../.." && pwd)"

cd "${project_root}"

renovate_cmd=()
if [[ -n "${RENOVATE_BIN:-}" ]]; then
  renovate_cmd=("${RENOVATE_BIN}")
elif command -v renovate >/dev/null 2>&1; then
  renovate_cmd=("renovate")
elif command -v npx >/dev/null 2>&1; then
  if ! node -e 'const major = Number(process.versions.node.split(".")[0]); process.exit(major >= 24 ? 0 : 1)' >/dev/null 2>&1; then
    cat >&2 <<'EOF'
Running Renovate through npx requires Node.js 24 or newer.

Install a current Node.js runtime, install Renovate globally from that runtime,
or set RENOVATE_BIN to a Renovate executable.
EOF
    exit 127
  fi
  renovate_cmd=("npx" "--yes" "renovate")
else
  cat >&2 <<'EOF'
Renovate is required for dependency lookup.

Install it locally, or run through npx:
  npm install --global renovate

You can also set RENOVATE_BIN to an executable path.
EOF
  exit 127
fi

echo "Running Renovate local lookup..."
"${renovate_cmd[@]}" --platform=local --dry-run=lookup "$@"

if [[ "${SKIP_OSV_SCAN:-0}" == "1" ]]; then
  exit 0
fi

if command -v osv-scanner >/dev/null 2>&1; then
  echo "Running OSV-Scanner source scan..."
  osv-scanner scan source --recursive .
else
  cat <<'EOF'
Skipping OSV-Scanner because osv-scanner is not installed.
Install it to include local vulnerability scanning in this dependency audit.
EOF
fi
