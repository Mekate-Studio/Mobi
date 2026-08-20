#!/usr/bin/env bash

set -euo pipefail

usage() {
  printf 'Usage: %s [--paths-file <path> | <base-revision> <head-revision>]\n' "$0" >&2
}

paths_file=""

if [[ "${1:-}" == "--paths-file" ]]; then
  paths_file="${2:-}"
  if [[ -z "${paths_file}" || $# -ne 2 ]]; then
    usage
    exit 2
  fi
elif [[ $# -eq 2 ]]; then
  base_revision="$1"
  head_revision="$2"
  paths_file="$(mktemp "${TMPDIR:-/tmp}/mobi-changed-paths.XXXXXX")"
  trap 'rm -f "${paths_file}"' EXIT
  git diff --name-only "${base_revision}" "${head_revision}" >"${paths_file}"
else
  usage
  exit 2
fi

if [[ ! -f "${paths_file}" ]]; then
  printf 'Changed-path input does not exist: %s\n' "${paths_file}" >&2
  exit 2
fi

docs_only=true
shared_tests=false
android_tests=false
ios_tests=false
android_build=false
ios_build=false
full_validation=false
path_count=0

select_full_validation() {
  docs_only=false
  shared_tests=true
  android_tests=true
  ios_tests=true
  android_build=true
  ios_build=true
  full_validation=true
}

while IFS= read -r changed_path || [[ -n "${changed_path}" ]]; do
  [[ -n "${changed_path}" ]] || continue
  path_count=$((path_count + 1))

  case "${changed_path}" in
    README.md|CONTRIBUTING.md|SECURITY.md|CODE_OF_CONDUCT.md|LICENSE*|NOTICE*|docs/*|openspec/*|.github/ISSUE_TEMPLATE/*|.github/PULL_REQUEST_TEMPLATE*)
      ;;

    shared-core/src/*|shared-core/test/*|shared-feature-*/src/*|shared-feature-*/test/*)
      docs_only=false
      shared_tests=true
      android_tests=true
      ios_tests=true
      ;;

    android-app/test/*)
      docs_only=false
      android_tests=true
      ;;

    android-app/src/*Presenter*|android-app/src/*StateProducer*|android-app/src/*Screen.kt)
      docs_only=false
      android_tests=true
      ;;

    android-app/src/*|android-app/resources/*|android-app/AndroidManifest.xml|android-app/module.yaml)
      docs_only=false
      android_tests=true
      android_build=true
      ;;

    ios-app/tests/*)
      docs_only=false
      ios_tests=true
      ;;

    ios-app/src/*Feature*.swift|ios-app/src/*Client.swift|ios-app/src/*Loadable.swift)
      docs_only=false
      ios_tests=true
      ;;

    ios-app/src/*|ios-app/resources/*|ios-app/Info.plist|ios-app/module.yaml|ios-app/module.xcodeproj/*)
      docs_only=false
      ios_tests=true
      ios_build=true
      ;;

    shared-di/*|shared-ui-*/*)
      docs_only=false
      shared_tests=true
      android_tests=true
      ios_tests=true
      android_build=true
      ios_build=true
      ;;

    project.yaml|kotlin|Justfile|Gemfile|Gemfile.lock|.ruby-version|gradle/*|gradle-bridge/*|fastlane/*|scripts/ci/*|scripts/dev/*|.github/workflows/*|*/module.yaml)
      select_full_validation
      ;;

    *)
      printf 'Unrecognized changed path; selecting full validation: %s\n' "${changed_path}" >&2
      select_full_validation
      ;;
  esac
done <"${paths_file}"

if [[ "${path_count}" -eq 0 ]]; then
  printf 'No changed paths were resolved; selecting full validation.\n' >&2
  select_full_validation
fi

emit_output() {
  local key="$1"
  local value="$2"

  printf '%s=%s\n' "${key}" "${value}"
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    printf '%s=%s\n' "${key}" "${value}" >>"${GITHUB_OUTPUT}"
  fi
}

emit_output docs_only "${docs_only}"
emit_output shared_tests "${shared_tests}"
emit_output android_tests "${android_tests}"
emit_output ios_tests "${ios_tests}"
emit_output android_build "${android_build}"
emit_output ios_build "${ios_build}"
emit_output full_validation "${full_validation}"
emit_output path_count "${path_count}"
