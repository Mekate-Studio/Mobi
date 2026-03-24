set shell := ["zsh", "-lic"]

default:
  @just --list

android-build-debug:
  ./scripts/ci/run_job.sh android-build-debug

android-build-release:
  ./scripts/ci/run_job.sh android-build-release

android-test:
  ./scripts/ci/run_job.sh android-test

ios-build-debug:
  ./scripts/ci/run_job.sh ios-build-debug

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
