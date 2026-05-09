#!/usr/bin/env bash

set -euo pipefail

ci_reset_android_amper_maven_cache() {
  local amper_maven_cache="${AMPER_USER_HOME:?}/Library/Caches/JetBrains/Amper/.m2.cache"

  if [[ -d "${amper_maven_cache}" ]]; then
    ci_log "Clearing Amper Maven cache for Android dependency resolution"
    rm -rf "${amper_maven_cache}"
  fi
}

ci_prepare_android_job() {
  ci_detect_context
  ci_prepare_workspace
  ci_reset_android_amper_maven_cache
  ci_set_java_home
  ci_resolve_android_sdk_root || true
  ci_bundle_install

  (
    cd "${CI_PROJECT_DIR}"
    ./scripts/ci/ensure_android_gradle_distribution.sh
  )

  ci_log_android_sdk_env

  (
    cd "${CI_PROJECT_DIR}"
    ./scripts/ci/apply_android_version.sh
  )

  if [[ -n "${ANDROID_KEYSTORE_FILE:-}" || -n "${ANDROID_KEYSTORE_BASE64:-}" ]]; then
    ci_log "Android signing material detected"
    (
      cd "${CI_PROJECT_DIR}"
      ./scripts/ci/write_android_signing_files.sh
    )
  else
    case "${CI_ANDROID_SIGNING_MODE:-auto}" in
      debug-smoke)
        ci_log "Android signing material missing; generating local debug signing files for smoke flow"
        (
          cd "${CI_PROJECT_DIR}"
          ./scripts/ci/ensure_android_debug_signing_files.sh
        )
        ;;
      release)
        ci_log "Android signing material missing for release-oriented flow"
        ;;
      *)
        ci_log "Android signing material missing"
        ;;
    esac
  fi
}

ci_prepare_android_promotion_job() {
  ci_prepare_android_job
  export GOOGLE_PLAY_JSON_KEY_FILE="${CI_PROJECT_DIR}/google_play_api_key.json"

  (
    cd "${CI_PROJECT_DIR}"
    ./scripts/ci/write_google_play_key.sh "${GOOGLE_PLAY_JSON_KEY_FILE}" >/dev/null
  )
}

ci_cleanup_google_play_key() {
  rm -f "${CI_PROJECT_DIR}/google_play_api_key.json"
}
