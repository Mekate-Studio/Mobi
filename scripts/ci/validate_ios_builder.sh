#!/usr/bin/env bash

set -euo pipefail

scope="${1:-build}"
builder="${KOTLIN_IOS_BUILDER:-kotlin}"

if [[ $# -gt 1 || ( "${scope}" != build && "${scope}" != signed-release ) ]]; then
  printf 'Usage: validate_ios_builder.sh [build|signed-release]\n' >&2
  exit 64
fi

if [[ "${builder}" != kotlin ]]; then
  printf 'Unsupported KOTLIN_IOS_BUILDER=%s for direct-content builds. Expected kotlin.\n' "${builder}" >&2
  printf 'Gradle rollback requires restoring the complete reviewed content patch and cleaning owned build products first.\n' >&2
  exit 64
fi

# Xcode archive actions use install. Unsigned archive assessments explicitly
# disable signing; a signing-enabled Release device build is delivery scope too.
xcode_delivery=false
if [[ "${CODE_SIGNING_ALLOWED:-YES}" != NO ]]; then
  if [[ "${ACTION:-}" == install || ( "${CONFIGURATION:-}" == Release && "${PLATFORM_NAME:-}" == iphoneos ) ]]; then
    xcode_delivery=true
  fi
fi

if [[ "${scope}" == signed-release || "${xcode_delivery}" == true ]]; then
  printf 'Credentialed iOS archive/export/upload is held pending separate signed-delivery evidence and risk authorization.\n' >&2
  printf 'Development, tests and unsigned assessments remain available.\n' >&2
  exit 69
fi
