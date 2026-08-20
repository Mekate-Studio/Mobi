# CI Validation And Release Candidates

Mobi uses different validation scopes for pull requests, scheduled candidate
builds, and credentialed releases. The workflow files stay thin; executable
behavior remains behind [`scripts/ci/run_job.sh`](../../scripts/ci/run_job.sh)
and the changed-path policy lives in
[`scripts/ci/classify_changes.sh`](../../scripts/ci/classify_changes.sh).

## Validation tiers

| Tier | Trigger | Purpose |
| --- | --- | --- |
| Pull request | Every pull request and push to `main` | Fast affected-surface feedback with one aggregate gate |
| Nightly candidate | Daily schedule or manual dispatch | Full tests and release-configuration builds for one exact `main` SHA |
| Release | Manual dispatch from the default branch | Credentialed archive, store upload, and promotion |

The pull-request workflow is always triggered. It does not use top-level path
filters because a skipped required workflow can remain pending in GitHub branch
protection. Individual jobs use classifier outputs, and the final
`Pull request gate` fails if any selected job fails or is cancelled.

Configure branch protection to require only `Pull request gate` after the new
workflow has completed successfully at least once.

## Changed-path policy

The classifier accumulates the impact of every changed path:

| Change | Selected work |
| --- | --- |
| Documentation and OpenSpec artifacts | Classifier fixtures and aggregate gate only |
| Shared core or feature behavior | Shared/Android host tests and iOS native behavior tests |
| Android presenter/state behavior | Android host tests |
| iOS reducer/client/state behavior | iOS pull-request test plan |
| Native views, resources, or project files | Affected tests plus the affected app build |
| Shared UI or shared composition | Both platform tests and builds |
| CI, release tooling, dependencies, or module manifests | Full validation |
| Unknown path | Full validation |

UI changes are therefore only one kind of build-affecting change. Project
files, dependency declarations, shared composition, resources, and operational
scripts can also break a native build.

Run the classifier fixtures locally:

```bash
./scripts/ci/test_classify_changes.sh
```

Inspect a real revision range locally:

```bash
./scripts/ci/classify_changes.sh origin/main HEAD
```

Classification fails open: an unknown path selects full validation.

## Pull-request tests

The Android/shared test job executes every module that currently contains host
tests:

- `shared-core`
- `shared-feature-home`
- `shared-feature-nearby-vehicle-map`
- `shared-di`
- `android-app`

Run that contract locally with:

```bash
./scripts/ci/run_job.sh android-test
```

This compiles the production code needed by the tests but does not explicitly
assemble an APK or AAB. App builds remain separate and run only when selected.

The macOS quality job bootstraps only missing lint tools through the repo-owned
`scripts/ci/install_quality_tools.sh` helper. Homebrew download caching avoids
assuming developer-machine tools exist on a clean hosted runner.

## Apple test plans

Apple recommends using [test plans](https://developer.apple.com/documentation/xcode/organizing-tests-to-improve-feedback)
to run affected targets for review feedback and a broader set of tests on a
schedule. Mobi's shared `app` scheme exposes:

- `PullRequest`: deterministic native reducer and adapter tests used by
  affected pull requests
- `Nightly`: the complete scheduled test surface and the extension point for
  future integration, UI, localization, and device-configuration tests

Run the plans locally with:

```bash
IOS_TEST_PLAN=PullRequest ./scripts/ci/run_job.sh ios-test
IOS_TEST_PLAN=Nightly ./scripts/ci/run_job.sh ios-test
```

Each run writes an Xcode result bundle under `build/test-results/`. Xcode app
tests still compile their test host and dependencies; "test-only" in this
policy means that CI does not run an additional standalone app-build job first.
If a hosted macOS image has an iOS runtime but no pre-created iPhone device, the
repo-owned Xcode helper creates one with `simctl` before selecting its stable
identifier as the test destination.

When UI tests are introduced, start with one stable critical-flow smoke test in
the Nightly plan. Add focused UI checks to PullRequest only for UI-affecting
changes after their reliability is demonstrated. A wider device, locale, and
OS matrix belongs in a less frequent workflow rather than every pull request.

## Nightly candidate semantics

[`nightly-mobile-candidate.yml`](../../.github/workflows/nightly-mobile-candidate.yml)
runs at 02:17 UTC, away from the busiest top-of-hour scheduling window. It runs
all current host/native tests, builds both apps in release configuration, and
publishes artifacts whose names contain the full source SHA.

The Android candidate builds only the generated `android-app` bundle, uses the
Gradle version selected by the Kotlin toolchain, and copies the result to
`build/releases/android/android-app-release.aab`. Its Gradle invocation is
bounded to two workers and a 4 GB heap by default. The iOS simulator candidate
builds only the runner-native architecture; a store archive still uses the
device/archive settings in the credentialed release lane.

The candidate manifest records:

- exact source SHA
- repository and workflow run
- expected artifact names
- whether the artifacts are release-ready binaries

A later commit on `main` is not certified by an earlier successful nightly run.
For an urgent check, manually dispatch the same nightly workflow against the
current default branch.

## Current signing boundary

The nightly Android candidate uses non-production debug signing, and the
nightly iOS candidate is a code-signing-disabled simulator build. They prove
release-configuration compilation, but they are deliberately marked
`releasable_binary: false` and must not be shipped.

Credentialed release operations live only in
[`mobile-release.yml`](../../.github/workflows/mobile-release.yml) and use
GitHub environments. Before enabling build-once/promote-later nightly releases:

1. Configure protected signing environments and their secrets.
2. Decide artifact retention and build-number policy.
3. Upload signed Android candidates to Play Internal and signed iOS candidates
   to TestFlight from the nightly workflow.
4. Make later release jobs promote or select those exact store builds instead
   of rebuilding source.
5. Update the candidate manifest to set `releasable_binary: true` only after
   those controls are validated.

Until then, the release workflow creates the signed store artifact manually
from the default branch, and the nightly workflow supplies broader health and
release-configuration evidence rather than a production binary.

Run the unsigned release-configuration checks locally with:

```bash
./scripts/ci/run_job.sh android-build-release-candidate
./scripts/ci/run_job.sh ios-build-release
```

## Measuring the next optimization

After this structure has accumulated enough hosted runs, record p50 and p95
duration for classification, quality, Android tests, iOS tests, and native
builds. Use those measurements before moving Android tests to Linux, caching
DerivedData, or extracting iOS behavior into a separate Swift package. Those
changes trade architecture and cache reliability for speed and should not be
made from intuition alone.
