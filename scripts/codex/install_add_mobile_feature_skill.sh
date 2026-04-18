#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Install the repo-local add-mobile-feature skill into Codex.

Usage:
  install_add_mobile_feature_skill.sh [--link|--copy] [--force]

Options:
  --link   Install as a symlink for active local development (default)
  --copy   Install as a copied snapshot
  --force  Replace an existing installed skill
  --help   Show this help text

The target install path is:
  ${CODEX_HOME:-$HOME/.codex}/skills/add-mobile-feature
EOF
}

mode="link"
force="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --link)
      mode="link"
      ;;
    --copy)
      mode="copy"
      ;;
    --force)
      force="true"
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"
skill_name="add-mobile-feature"
source_dir="${repo_root}/.codex/skills/${skill_name}"
codex_home="${CODEX_HOME:-${HOME}/.codex}"
target_dir="${codex_home}/skills/${skill_name}"

if [[ ! -d "${source_dir}" ]]; then
  printf 'Skill source directory not found: %s\n' "${source_dir}" >&2
  exit 1
fi

mkdir -p "${codex_home}/skills"

if [[ -e "${target_dir}" || -L "${target_dir}" ]]; then
  if [[ "${force}" != "true" ]]; then
    printf 'Skill already exists at %s\n' "${target_dir}" >&2
    printf 'Re-run with --force to replace it.\n' >&2
    exit 1
  fi

  rm -rf "${target_dir}"
fi

case "${mode}" in
  link)
    ln -s "${source_dir}" "${target_dir}"
    printf 'Linked %s -> %s\n' "${target_dir}" "${source_dir}"
    ;;
  copy)
    cp -R "${source_dir}" "${target_dir}"
    printf 'Copied %s -> %s\n' "${source_dir}" "${target_dir}"
    ;;
  *)
    printf 'Unsupported install mode: %s\n' "${mode}" >&2
    exit 1
    ;;
esac

printf 'Restart Codex to pick up new skills.\n'
