#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: create_gitlab_maintenance_mr.sh --branch <name> --commit-message <msg> --title <title> [--description <text>] [--target-branch <name>] [--paths <pathspec>...]
EOF
}

branch=""
commit_message=""
title=""
description=""
target_branch="${CI_DEFAULT_BRANCH:-main}"
declare -a paths=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch)
      branch="${2:?Missing value for --branch}"
      shift 2
      ;;
    --commit-message)
      commit_message="${2:?Missing value for --commit-message}"
      shift 2
      ;;
    --title)
      title="${2:?Missing value for --title}"
      shift 2
      ;;
    --description)
      description="${2:?Missing value for --description}"
      shift 2
      ;;
    --target-branch)
      target_branch="${2:?Missing value for --target-branch}"
      shift 2
      ;;
    --paths)
      shift
      while [[ $# -gt 0 ]]; do
        paths+=("$1")
        shift
      done
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${branch}" || -z "${commit_message}" || -z "${title}" ]]; then
  usage >&2
  exit 1
fi

if [[ -z "${CI_PROJECT_URL:-}" || -z "${CI_PROJECT_ID:-}" || -z "${CI_API_V4_URL:-}" ]]; then
  printf 'This script expects to run in GitLab CI.\n' >&2
  exit 1
fi

if [[ -z "${GITLAB_MAINTENANCE_TOKEN:-}" ]]; then
  printf 'Missing required GitLab token: GITLAB_MAINTENANCE_TOKEN\n' >&2
  exit 1
fi

repo_root="$(pwd)"
git config user.name "${GITLAB_MAINTENANCE_GIT_NAME:-CI Maintenance Bot}"
git config user.email "${GITLAB_MAINTENANCE_GIT_EMAIL:-ci-maintenance-bot@example.invalid}"

if [[ ${#paths[@]} -gt 0 ]]; then
  git add -- "${paths[@]}"
else
  git add -A
fi

if git diff --cached --quiet; then
  printf 'No maintenance changes detected. Skipping branch push and merge request.\n'
  exit 0
fi

git checkout -B "${branch}"
git commit -m "${commit_message}"

push_username="${GITLAB_MAINTENANCE_USERNAME:-oauth2}"
push_remote_url="${CI_PROJECT_URL/https:\/\//https://${push_username}:${GITLAB_MAINTENANCE_TOKEN}@}"

git push --force-with-lease "${push_remote_url}" "HEAD:${branch}"

existing_mr_iid="$(
  curl --silent --show-error --header "PRIVATE-TOKEN: ${GITLAB_MAINTENANCE_TOKEN}" \
    "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/merge_requests?state=opened&source_branch=${branch}" \
    | ruby -r json -e '
        merge_requests = JSON.parse($stdin.read)
        if merge_requests.is_a?(Array) && !merge_requests.empty?
          puts merge_requests.first["iid"]
        end
      '
)"

if [[ -n "${existing_mr_iid}" ]]; then
  printf 'Merge request already exists: !%s\n' "${existing_mr_iid}"
  exit 0
fi

curl --fail --silent --show-error \
  --request POST \
  --header "PRIVATE-TOKEN: ${GITLAB_MAINTENANCE_TOKEN}" \
  --data-urlencode "source_branch=${branch}" \
  --data-urlencode "target_branch=${target_branch}" \
  --data-urlencode "title=${title}" \
  --data-urlencode "description=${description}" \
  --data-urlencode "remove_source_branch=true" \
  "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/merge_requests" >/dev/null

printf 'Created merge request for branch %s\n' "${branch}"
