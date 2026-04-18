set shell := ["zsh", "-lic"]

default:
  @just --list

format:
  ./scripts/dev/format.sh

lint:
  ./scripts/dev/lint.sh

check:
  ./scripts/dev/check.sh

doctor:
  ./scripts/dev/doctor.sh

android-emulators:
  ./scripts/dev/android_emulators.sh

android-build-debug:
  ./scripts/ci/run_job.sh android-build-debug

android-run:
  ./scripts/dev/android_run.sh

android-run-debug:
  ./scripts/dev/android_run_wait_for_debugger.sh

android-start avd:
  ./scripts/dev/android_start_emulator.sh "{{avd}}"

android-build-release:
  ./scripts/ci/run_job.sh android-build-release

android-test:
  ./scripts/dev/android_test.sh

ios-build-debug:
  ./scripts/ci/run_job.sh ios-build-debug

ios-test:
  ./scripts/ci/run_job.sh ios-test

ios-open:
  ./scripts/dev/ios_open.sh

ios-build-release:
  ./scripts/ci/run_job.sh ios-build-release

ios-archive-release:
  ./scripts/ci/run_job.sh ios-archive-release

ios-testflight:
  ./scripts/ci/run_job.sh ios-testflight

publish-internal:
  ./scripts/ci/run_job.sh publish-internal

promote-alpha:
  ./scripts/ci/run_job.sh promote-alpha

promote-beta:
  ./scripts/ci/run_job.sh promote-beta

promote-production:
  ./scripts/ci/run_job.sh promote-production
