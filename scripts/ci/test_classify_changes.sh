#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "$0")/../.." && pwd)"
classifier="${project_root}/scripts/ci/classify_changes.sh"
fixture_dir="$(mktemp -d "${TMPDIR:-/tmp}/mobi-classifier-tests.XXXXXX")"
trap 'rm -rf "${fixture_dir}"' EXIT

assert_output() {
  local fixture_name="$1"
  local expected_key="$2"
  local expected_value="$3"
  local output_file="${fixture_dir}/${fixture_name}.output"

  if ! rg -q "^${expected_key}=${expected_value}$" "${output_file}"; then
    printf 'Fixture %s expected %s=%s\n' "${fixture_name}" "${expected_key}" "${expected_value}" >&2
    sed -n '1,80p' "${output_file}" >&2
    exit 1
  fi
}

run_fixture() {
  local fixture_name="$1"
  shift
  local paths_file="${fixture_dir}/${fixture_name}.paths"
  local output_file="${fixture_dir}/${fixture_name}.output"

  printf '%s\n' "$@" >"${paths_file}"
  "${classifier}" --paths-file "${paths_file}" >"${output_file}"
}

run_fixture docs docs/reference/mobile-architecture.md README.md
assert_output docs docs_only true
assert_output docs android_tests false
assert_output docs ios_build false

run_fixture shared_behavior shared-feature-home/src/HomeFeatureService.kt
assert_output shared_behavior shared_tests true
assert_output shared_behavior android_tests true
assert_output shared_behavior ios_tests true
assert_output shared_behavior android_build false
assert_output shared_behavior ios_build false

run_fixture android_logic android-app/src/home/HomePresenterStateProducer.kt
assert_output android_logic android_tests true
assert_output android_logic android_build false
assert_output android_logic ios_tests false

run_fixture ios_logic ios-app/src/Features/Home/HomeFeature.swift
assert_output ios_logic ios_tests true
assert_output ios_logic ios_build false
assert_output ios_logic android_tests false

run_fixture shared_ui shared-ui-home/src/HomeContent.kt
assert_output shared_ui android_build true
assert_output shared_ui ios_build true

run_fixture build_system project.yaml scripts/ci/run_job.sh
assert_output build_system full_validation true
assert_output build_system android_build true
assert_output build_system ios_build true

run_fixture unknown unexpected/new-surface.txt
assert_output unknown full_validation true

printf 'Changed-path classifier fixtures passed.\n'
