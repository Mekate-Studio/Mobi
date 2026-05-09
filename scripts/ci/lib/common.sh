#!/usr/bin/env bash

set -euo pipefail

ci_log() {
  printf '[ci] %s\n' "$*"
}

ci_has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

ci_require_cmd() {
  if ! ci_has_cmd "$1"; then
    printf 'Required command not found: %s\n' "$1" >&2
    exit 1
  fi
}

ci_prepare_workspace() {
  export AMPER_USER_HOME="${AMPER_USER_HOME:-${CI_PROJECT_DIR}/.amper-user-home}"
  export AMPER_TMP_DIR="${AMPER_TMP_DIR:-${CI_PROJECT_DIR}/build/tmp/amper}"
  export AMPER_JAVA_OPTIONS="${AMPER_JAVA_OPTIONS:+${AMPER_JAVA_OPTIONS} }-Duser.home=${AMPER_USER_HOME} -Djava.io.tmpdir=${AMPER_TMP_DIR}"

  mkdir -p \
    "${AMPER_BOOTSTRAP_CACHE_DIR}" \
    "${AMPER_USER_HOME}/Library/Caches/JetBrains/Amper/telemetry" \
    "${AMPER_TMP_DIR}"
  chmod +x "${CI_PROJECT_DIR}/amper" "${CI_PROJECT_DIR}"/scripts/ci/*.sh
}

ci_set_java_home() {
  local preferred_java_home=""

  if [[ -x /usr/libexec/java_home ]]; then
    preferred_java_home="$(/usr/libexec/java_home -v 21 2>/dev/null || true)"

    if [[ -n "${preferred_java_home}" ]]; then
      export JAVA_HOME="${JAVA_HOME:-${preferred_java_home}}"
    else
      export JAVA_HOME="${JAVA_HOME:-$(/usr/libexec/java_home)}"
    fi
  fi

  if [[ -n "${JAVA_HOME:-}" ]]; then
    ci_log "JAVA_HOME=${JAVA_HOME}"
  fi
}
