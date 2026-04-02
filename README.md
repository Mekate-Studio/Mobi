# Kotlin Multiplatform CI Blueprint

This repository is a small Kotlin Multiplatform project built with
[Amper](https://www.amper.org/), but the more interesting part is the CI setup
around it.

The project demonstrates a reproducible pattern for mobile CI:

- keep GitHub Actions and GitLab CI thin
- keep build and release logic in repository-owned scripts
- use Fastlane as the command layer
- let Amper handle the multiplatform build

If you want to reuse this setup in another project, start with the GitHub
Actions guide:

- [GitHub Actions Quickstart](docs/quickstart-github-actions.md)
- [Public Write-Up](docs/public-writeup.md)
- [Blog Post Version](https://github.com/Mekate-Studio/Portable-KMP-CI/blob/main/docs/portable-kmp-ci.md)
- [Minimal Public Sample Repo Blueprint](docs/minimal-public-sample-repo.md)

There is also a published companion sample repository:

- [Portable KMP CI Sample](https://github.com/Mekate-Studio/Portable-KMP-CI)

Reference material lives here:

- [CI Architecture](docs/reference/architecture.md)
- [Mobile Architecture](docs/reference/mobile-architecture.md)
- [iOS Gradle Bridge Migration](docs/reference/ios-gradle-bridge.md)
- [Secrets Reference](docs/reference/secrets.md)
- [Local Development](docs/reference/local-development.md)
- [Troubleshooting](docs/reference/troubleshooting.md)

## What this repo contains

- [`project.yaml`](project.yaml): Amper
  workspace entrypoint
- [`shared-core/`](shared-core): shared
  domain and platform-agnostic Kotlin logic
- [`shared-feature-home/`](shared-feature-home): first
  shared feature contract and state module
- [`shared-ui-home/`](shared-ui-home): reusable
  Compose Multiplatform home feature UI
- [`shared/`](shared): compatibility
  bridge while the old shared module is being phased out
- [`android-app/`](android-app): Android
  app target
- [`ios-app/`](ios-app): iOS app target
  with native SwiftUI shell and shared Kotlin feature backing
- [`.github/workflows/mobile-ci.yml`](.github/workflows/mobile-ci.yml):
  GitHub Actions adapter
- [`.gitlab-ci.yml`](.gitlab-ci.yml):
  GitLab adapter
- [`scripts/ci/run_job.sh`](scripts/ci/run_job.sh):
  shared CI entrypoint
- [`scripts/ci/lib.sh`](scripts/ci/lib.sh):
  shared CI helper loader
- [`fastlane/Fastfile`](fastlane/Fastfile):
  build and release lanes

## Supported CI jobs

The shared dispatcher accepts these portable job names:

- `android-build-debug`
- `android-build-release`
- `android-test`
- `ios-build-debug`
- `ios-build-release`
- `ios-archive-release`
- `ios-testflight`
- `publish-internal`
- `promote-alpha`
- `promote-beta`
- `promote-production`

That job list is the contract. CI providers decide when to run a job, but the
repository decides what each job actually does.

## Local smoke test

Install dependencies:

```bash
bundle install
```

Set a writable Amper cache:

```bash
export AMPER_BOOTSTRAP_CACHE_DIR="$PWD/.amper-cache"
```

Run a few shared jobs locally:

```bash
./scripts/ci/run_job.sh android-build-debug
./scripts/ci/run_job.sh android-test
./scripts/ci/run_job.sh ios-build-debug
```

You can also use the repo [`Justfile`](Justfile):

```bash
just android-build-debug
just android-test
just ios-build-debug
```

The iOS build jobs target a generic iOS Simulator destination and force a
single simulator architecture matching the host. That removes the dependency on
a precreated simulator device. The remaining host requirement is that Xcode has
an iOS Simulator runtime installed.

## Why this layout works

The main idea is to keep orchestration separate from implementation:

- GitHub Actions and GitLab CI only define triggers, runners, environments, and
  artifacts
- [`scripts/ci/run_job.sh`](scripts/ci/run_job.sh)
  maps portable job names to concrete actions
- the scripts under
  [`scripts/ci/lib/`](scripts/ci/lib)
  normalize environment variables, prepare toolchains, and materialize secrets
- Fastlane wraps the Amper and store-delivery commands in a familiar release
  interface

This makes the setup easier to test locally, easier to port between CI
platforms, and easier to explain to other teams.

## Scheduled maintenance

This repository can refresh tracked dependency state through scheduled GitLab
pipelines:

- `refreshBundlerLockfile` updates [`Gemfile.lock`](Gemfile.lock) with
  `bundle update fastlane`, runs
  [`./scripts/ci/run_job.sh android-build-debug`](scripts/ci/run_job.sh), and
  opens a merge request if the lockfile changed.
- `refreshAmperDependencies` updates the explicit Amper-managed Android
  dependency versions in
  [`android-app/module.yaml`](android-app/module.yaml), runs the same smoke
  test, and opens a merge request if a tracked version changed.

To enable merge request creation from scheduled pipelines, configure these
GitLab CI variables:

- `GITLAB_MAINTENANCE_TOKEN`: token with API and repository write access
- `GITLAB_MAINTENANCE_USERNAME`: optional push username, defaults to `oauth2`
- `GITLAB_MAINTENANCE_GIT_NAME`: optional Git author name for maintenance
  commits
- `GITLAB_MAINTENANCE_GIT_EMAIL`: optional Git author email for maintenance
  commits

The Amper refresh job also accepts `ACTIVITY_COMPOSE_VERSION` if you want to
override the discovered latest version during a manual or scheduled pipeline.
