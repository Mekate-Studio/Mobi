#!/usr/bin/env bash

ci_resolve_skip_macro_validation() {
  if [[ -n "${SKIP_MACRO_VALIDATION:-}" ]]; then
    printf '%s\n' "${SKIP_MACRO_VALIDATION}"
  elif [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    printf 'YES\n'
  else
    printf 'NO\n'
  fi
}
