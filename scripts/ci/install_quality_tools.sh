#!/usr/bin/env bash

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  printf 'Quality tool bootstrap currently supports macOS runners only.\n' >&2
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  printf 'Homebrew is required to install quality tools on a clean runner.\n' >&2
  exit 1
fi

missing_formulas=()

add_formula_if_missing() {
  local command_name="$1"
  local formula_name="$2"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    missing_formulas+=("${formula_name}")
  fi
}

add_formula_if_missing ktlint ktlint
add_formula_if_missing detekt detekt
add_formula_if_missing swiftformat swiftformat
add_formula_if_missing swiftlint swiftlint
add_formula_if_missing shellcheck shellcheck

if [[ "${#missing_formulas[@]}" -gt 0 ]]; then
  printf 'Installing missing quality tools: %s\n' "${missing_formulas[*]}"
  HOMEBREW_NO_AUTO_UPDATE=1 brew install "${missing_formulas[@]}"
else
  printf 'All quality tools are already available.\n'
fi

printf 'Quality tool versions:\n'
ktlint --version
detekt --version
swiftformat --version
swiftlint version
shellcheck --version | sed -n '1,2p'
