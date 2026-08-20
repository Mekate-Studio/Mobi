#!/usr/bin/env bash

set -euo pipefail

output_path="${1:-}"

if [[ -z "${output_path}" ]]; then
  printf 'Usage: %s <output-path>\n' "$0" >&2
  exit 2
fi

required_variables=(
  CANDIDATE_SHA
  CANDIDATE_RUN_ID
  CANDIDATE_RUN_NUMBER
  CANDIDATE_REPOSITORY
  CANDIDATE_SERVER_URL
)

for variable_name in "${required_variables[@]}"; do
  if [[ -z "${!variable_name:-}" ]]; then
    printf 'Missing candidate manifest variable: %s\n' "${variable_name}" >&2
    exit 2
  fi
done

mkdir -p "$(dirname "${output_path}")"

jq -n \
  --arg source_sha "${CANDIDATE_SHA}" \
  --arg run_id "${CANDIDATE_RUN_ID}" \
  --arg run_number "${CANDIDATE_RUN_NUMBER}" \
  --arg repository "${CANDIDATE_REPOSITORY}" \
  --arg workflow_url "${CANDIDATE_SERVER_URL}/${CANDIDATE_REPOSITORY}/actions/runs/${CANDIDATE_RUN_ID}" \
  --arg generated_at "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  '{
    schema_version: 1,
    candidate_kind: "unsigned-release-configuration-validation",
    source_sha: $source_sha,
    run_id: $run_id,
    run_number: $run_number,
    repository: $repository,
    workflow_url: $workflow_url,
    generated_at: $generated_at,
    releasable_binary: false,
    artifact_names: [
      ("android-candidate-" + $source_sha),
      ("ios-candidate-" + $source_sha),
      ("nightly-android-test-results-" + $source_sha),
      ("nightly-ios-test-results-" + $source_sha)
    ]
  }' >"${output_path}"

printf 'Wrote candidate manifest: %s\n' "${output_path}"
