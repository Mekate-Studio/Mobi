#!/usr/bin/env bash

set -euo pipefail

ci_configure_ios_kotlin_builder() {
  export KOTLIN_IOS_BUILDER="${KOTLIN_IOS_BUILDER:-amper}"

  if [[ -n "${GITLAB_CI:-}" ]]; then
    local gitlab_gradle_base="${CI_BUILDS_DIR:-${HOME:-${CI_PROJECT_DIR}}}"
    local gitlab_gradle_home="${gitlab_gradle_base}/.gradle-user-home/${CI_PROJECT_PATH_SLUG:-b3}"

    if [[ -z "${GRADLE_USER_HOME:-}" || "${GRADLE_USER_HOME}" == "/.gradle-user-home/"* ]]; then
      export GRADLE_USER_HOME="${gitlab_gradle_home}"
    fi
  fi

  if [[ -z "${GRADLE_USER_HOME:-}" ]]; then
    if [[ -n "${GITLAB_CI:-}" ]]; then
      export GRADLE_USER_HOME="${CI_BUILDS_DIR:-${HOME:-${CI_PROJECT_DIR}}}/.gradle-user-home/${CI_PROJECT_PATH_SLUG:-b3}"
    else
      export GRADLE_USER_HOME="${CI_PROJECT_DIR}/.gradle-user-home"
    fi
  fi

  case "${KOTLIN_IOS_BUILDER}" in
    amper|gradle)
      ;;
    *)
      printf 'Unsupported KOTLIN_IOS_BUILDER: %s\n' "${KOTLIN_IOS_BUILDER}" >&2
      printf 'Supported values: amper, gradle\n' >&2
      exit 1
      ;;
  esac

  printf 'Using iOS Kotlin builder: %s\n' "${KOTLIN_IOS_BUILDER}"
  printf 'Using GRADLE_USER_HOME: %s\n' "${GRADLE_USER_HOME}"
}

ci_prepare_ios_job() {
  ci_detect_context
  ci_prepare_workspace
  ci_set_java_home
  ci_resolve_android_sdk_root || true
  ci_configure_path
  ci_configure_ios_kotlin_builder
  ci_require_cmd xcodebuild
  xcodebuild -version
  ci_log_android_sdk_env
}

ci_prepare_ios_fastlane_job() {
  ci_prepare_ios_job
  ci_bundle_install
}

ci_prepare_ios_testflight_job() {
  ci_prepare_ios_fastlane_job

  (
    cd "${CI_PROJECT_DIR}"
    ./scripts/ci/write_app_store_connect_api_key.sh "${CI_PROJECT_DIR}/fastlane/AuthKey.p8" >/dev/null
  )
}

ci_cleanup_app_store_connect_key() {
  rm -f "${CI_PROJECT_DIR}/fastlane/AuthKey.p8"
}
