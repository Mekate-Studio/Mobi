#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
source "${script_dir}/lib.sh"
# shellcheck source=./lib/android_generated_gradle.sh
source "${script_dir}/lib/android_generated_gradle.sh"
cd "${CI_PROJECT_DIR}"

log_dir="${CI_PROJECT_DIR}/build/logs/android-ui-tests"
mkdir -p "${log_dir}"
rm -f "${log_dir}/report.json"
results="${CI_PROJECT_DIR}/build/android-ui-tests/gradle/test-results/testDebugUnitTest"
rm -rf "${log_dir}/results" "${results}"
capture_results() {
  if [[ -d "${results}" ]]; then cp -R "${results}" "${log_dir}/results"; fi
}
trap capture_results EXIT

# AND-03: rebuild actual libraries and resolve the module's declared test graph.
# Toolchain remains the app compiler and owner of the delegated Android bootstrap.
./scripts/ci/run_kotlin_with_logs.sh build -m shared-ui-home -p android
./scripts/ci/run_kotlin_with_logs.sh show dependencies -m shared-ui-home -p android --include-tests --scope runtime >"${log_dir}/dependencies.log" 2>&1
ruby scripts/android/ui_test_inputs.rb
cp build/android-ui-tests/inputs.json "${log_dir}/inputs.json"

./scripts/ci/ensure_android_gradle_distribution.sh
gradle_root="${GRADLE_USER_HOME:?}/wrapper/dists/gradle-${android_generated_gradle_version}-${android_generated_gradle_distribution_type}/$(android_generated_gradle_distribution_id)"
"${gradle_root}/gradle-${android_generated_gradle_version}/bin/gradle" \
  --project-dir tools/android-ui-tests \
  --project-cache-dir "${CI_PROJECT_DIR}/build/android-ui-tests/project-cache" \
  --gradle-user-home "${GRADLE_USER_HOME}" \
  --no-daemon --max-workers=2 --console=plain \
  testDebugUnitTest --rerun "$@" 2>&1 | tee "${log_dir}/runner.log"
