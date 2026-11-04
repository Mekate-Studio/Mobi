#!/usr/bin/env bash

set -euo pipefail

require_result() {
  local job="$1"
  local expected="$2"
  local actual="$3"

  if [[ "${actual}" != "${expected}" ]]; then
    printf 'Validation gate: %s expected %s, got %s\n' "${job}" "${expected}" "${actual:-<missing>}" >&2
    exit 1
  fi
}

require_selected() {
  local job="$1"
  local selected="$2"
  local actual="$3"

  case "${selected}" in
    true) require_result "${job}" success "${actual}" ;;
    false) require_result "${job}" skipped "${actual}" ;;
    *)
      printf 'Validation gate: %s has invalid selection %s\n' "${job}" "${selected:-<missing>}" >&2
      exit 1
      ;;
  esac
}

require_result classify success "${CLASSIFY_RESULT:-}"
case "${DOCS_ONLY:-}" in
  true) require_selected quality false "${QUALITY_RESULT:-}" ;;
  false) require_selected quality true "${QUALITY_RESULT:-}" ;;
  *)
    printf 'Validation gate: invalid docs_only selection %s\n' "${DOCS_ONLY:-<missing>}" >&2
    exit 1
    ;;
esac
require_selected android_test "${ANDROID_TESTS:-}" "${ANDROID_TEST_RESULT:-}"
require_selected ios_test "${IOS_TESTS:-}" "${IOS_TEST_RESULT:-}"
require_selected android_build "${ANDROID_BUILD:-}" "${ANDROID_BUILD_RESULT:-}"
require_selected ios_build "${IOS_BUILD:-}" "${IOS_BUILD_RESULT:-}"

printf 'Selected validation passed.\n'
