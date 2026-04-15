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
- [Legacy Public Write-Up Blueprint](docs/public-writeup.md)
- [Blog Post Version](https://github.com/Mekate-Studio/Portable-KMP-CI/blob/main/docs/portable-kmp-ci.md)
- [Legacy Minimal Public Sample Repo Blueprint](docs/minimal-public-sample-repo.md)

There is also a published companion sample repository:

- [Portable KMP CI Sample](https://github.com/Mekate-Studio/Portable-KMP-CI)

Reference material lives here:

- [CI Architecture](docs/reference/architecture.md)
- [Mobile Architecture](docs/reference/mobile-architecture.md)
- [How To Add A Feature](docs/reference/how-to-add-a-feature.md)
- [Architecture Decisions](docs/adr/README.md)
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
- [`shared-di/`](shared-di): shared Metro graph
  and Kotlin composition-root helpers for app code and tests
- [`shared-ui-home/`](shared-ui-home): reusable
  Compose Multiplatform home feature UI, including the optional
  `SharedHomeScreen` entry point
- [`android-app/`](android-app): Android
  app target
- [`ios-app/`](ios-app): iOS app target
  with native SwiftUI shell and shared Kotlin feature backing
- [`docs/adr/`](docs/adr): architecture decision records
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

The app now exposes two visible home demos on both platforms:

- `Native Home`: native shell consuming `shared-feature-home`
- `Shared UI`: Compose Multiplatform screen consuming the same shared feature
  state through `shared-ui-home`

That shared home feature now goes beyond static state: both platforms consume a
shared asynchronous repository flow from Kotlin. Pressing the counter action
loads the next fibonacci value through a fake repository/web-API seam. That
shared state is modeled as a type-driven async lifecycle instead of booleans:
initial, loading, loaded, and error all flow from the shared layer into the
native shells and the shared Compose screen. The fake repository now also
fails randomly so both platforms exercise the full state spectrum.

## Supported CI jobs

The shared dispatcher accepts these portable job names:

- `android-build-debug`
- `android-build-release`
- `android-test`
- `ios-build-debug`
- `ios-test`
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
./scripts/ci/run_job.sh ios-test
```

You can also use the repo [`Justfile`](Justfile):

```bash
just android-build-debug
just android-test
just ios-build-debug
just ios-test
```

The iOS build jobs target a generic iOS Simulator destination, disable explicit
Swift modules for the CLI path, and prefer the Xcode workspace when the Swift
package graph is present. The remaining host requirement is that Xcode has an
iOS Simulator runtime installed.

The current test bootstrap covers state transitions on both native shells:

- Shared Kotlin tests cover the async repository and feature service directly,
  including success and error transitions.
- Android tests the Circuit-facing transition seam through
  [`HomePresenterStateProducer`](android-app/src/home/HomePresenterStateProducer.kt),
  which adapts the shared sealed async state into the presenter/UI contract.
- iOS tests the TCA reducer with a real `TestStore` in
  [`HomeFeatureTests.swift`](ios-app/tests/Features/Home/HomeFeatureTests.swift),
  stubbing the shared client to verify reducer-driven state transitions.

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

- `GITLAB_MAINTENANCE_TOKEN`: preferred token with API and repository write
  access
- `GITLAB_TOKEN`, `GITLAB_API_TOKEN`, or `GL_TOKEN`: accepted fallback names
  for the same token if your GitLab setup already uses one of those conventions
- `GITLAB_MAINTENANCE_USERNAME`: optional push username, defaults to `oauth2`
- `GITLAB_MAINTENANCE_GIT_NAME`: optional Git author name for maintenance
  commits
- `GITLAB_MAINTENANCE_GIT_EMAIL`: optional Git author email for maintenance
  commits

`CI_JOB_TOKEN` is not sufficient here because GitLab only permits read access to
the Merge Requests API for job tokens, while this maintenance script creates a
new merge request.

The Amper refresh job also accepts `ACTIVITY_COMPOSE_VERSION` if you want to
override the discovered latest version during a manual or scheduled pipeline.
