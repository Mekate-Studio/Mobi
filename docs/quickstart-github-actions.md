# GitHub Actions Quickstart

This guide is the shortest path for reproducing the CI setup in another Kotlin
Multiplatform project.

It assumes you want the same overall model as this repository:

- GitHub Actions for orchestration
- repository-owned shell scripts for shared logic
- Fastlane for build and release commands
- Kotlin Toolchain for Kotlin Multiplatform builds
- macOS runners so Android and iOS can live in one pipeline

## 0. Start from a Kotlin Toolchain project

If you are migrating an older Amper project, create the Kotlin Toolchain wrapper
first and then layer the CI files on top.

From the project root, run:

```bash
kotlin update --create
```

That creates the checked-in `kotlin` and `kotlin.bat` wrappers used by this
repository. Future wrapper updates can use `./kotlin update`.

A good baseline for this CI setup has:

- `android-app/`
- `ios-app/`
- `shared/`
- `project.yaml`
- checked-in `kotlin` wrappers

Additional desktop or JVM modules can stay in the repository if you want them,
but the smoke path documented here focuses on Android, iOS, and shared Kotlin
code.

If you want to see what that trimmed mobile-only result looks like, the
published sample repository is:
[Portable KMP CI Sample](https://github.com/Mekate-Studio/Portable-KMP-CI).
That sample has also moved to Kotlin Toolchain wrappers.

## 1. Copy the core files

The minimum reusable pieces are:

- [`.github/workflows/mobile-ci.yml`](../.github/workflows/mobile-ci.yml)
- [`scripts/ci/run_job.sh`](../scripts/ci/run_job.sh)
- [`scripts/ci/lib.sh`](../scripts/ci/lib.sh)
- [`scripts/ci/lib/common.sh`](../scripts/ci/lib/common.sh)
- [`scripts/ci/lib/context.sh`](../scripts/ci/lib/context.sh)
- [`scripts/ci/lib/env.sh`](../scripts/ci/lib/env.sh)
- [`scripts/ci/lib/android.sh`](../scripts/ci/lib/android.sh)
- [`scripts/ci/lib/ios.sh`](../scripts/ci/lib/ios.sh)
- [`scripts/ci/apply_android_version.sh`](../scripts/ci/apply_android_version.sh)
- [`scripts/ci/build_android_aab.sh`](../scripts/ci/build_android_aab.sh)
- [`scripts/ci/write_android_signing_files.sh`](../scripts/ci/write_android_signing_files.sh)
- [`scripts/ci/write_google_play_key.sh`](../scripts/ci/write_google_play_key.sh)
- [`scripts/ci/write_app_store_connect_api_key.sh`](../scripts/ci/write_app_store_connect_api_key.sh)
- [`scripts/ci/run_fastlane_with_kotlin_logs.sh`](../scripts/ci/run_fastlane_with_kotlin_logs.sh)
- [`scripts/ci/run_xcodebuild_with_logs.sh`](../scripts/ci/run_xcodebuild_with_logs.sh)
- [`scripts/ci/run_kotlin_with_logs.sh`](../scripts/ci/run_kotlin_with_logs.sh)
- [`scripts/ci/print_recent_logs.sh`](../scripts/ci/print_recent_logs.sh)
- [`fastlane/Fastfile`](../fastlane/Fastfile)
- [`fastlane/Appfile`](../fastlane/Appfile)
- [`Gemfile`](../Gemfile)

If your project structure differs, update paths in those files before wiring up
the workflow.

If your generated structure is close to the Android, iOS, and shared-module
shape above, the path adjustments should be small.

## 2. Understand the job contract

Everything centers on [`scripts/ci/run_job.sh`](../scripts/ci/run_job.sh).
It accepts portable job names and hides CI-provider differences.

Use this set as the baseline contract:

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

If you keep those names stable, it becomes much easier to:

- run the same jobs locally
- explain the pipeline to other people

## 3. Verify the scripts locally first

Before debugging GitHub Actions, make sure the shared job layer works on a Mac.

Install gems:

```bash
bundle install
```

Set writable Kotlin Toolchain caches:

```bash
export KOTLIN_CLI_BOOTSTRAP_CACHE_DIR="$PWD/.kotlin-cache"
export KOTLIN_CLI_USER_HOME="$PWD/.kotlin-user-home"
```

Run the lowest-risk jobs first:

```bash
./scripts/ci/run_job.sh android-build-debug
./scripts/ci/run_job.sh android-test
./scripts/ci/run_job.sh ios-build-debug
./scripts/ci/run_job.sh ios-test
```

If those work locally, most later CI issues will be environment or secrets
problems, not pipeline design problems.

## 4. Add the GitHub Actions workflow

This repository uses [`.github/workflows/mobile-ci.yml`](../.github/workflows/mobile-ci.yml)
as a thin adapter.

It handles:

- `push` and `pull_request` validation
- manual `workflow_dispatch` release targets
- job dependencies
- artifact upload and download
- environment gates for sensitive release jobs

It does not contain the real build logic. Each job just installs the minimum
tooling and calls `./scripts/ci/run_job.sh <job-name>`.

That separation is worth preserving.

## 5. Start with hosted macOS, then switch if needed

The workflow currently uses `runs-on: macos-15`.

That is the easiest way to reproduce the setup because:

- Android builds already work there
- iOS builds need Xcode anyway
- one runner type can eventually host both platforms

If you want parity with a self-managed mobile CI machine, replace `runs-on` with
your self-hosted labels, for example:

```yaml
runs-on: [self-hosted, macOS]
```

## 6. Configure GitHub environments and secrets

Use environments to keep release secrets scoped and reviewable.

Suggested environments:

- `play-internal`
- `play-alpha`
- `play-beta`
- `play-production`
- `ios-release`
- `testflight`

### Android release secrets

Add these to the appropriate Play environments:

- `GOOGLE_PLAY_JSON_KEY`
- `ANDROID_KEYSTORE_FILE` or `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_PACKAGE_NAME` if your package is not `studio.mekate.mobi`
- `ANDROID_PLAY_RELEASE_STATUS` if you need a non-default Play status

### iOS release secrets

Add these to `ios-release` and `testflight`:

- `IOS_BUNDLE_IDENTIFIER`
- `IOS_DEVELOPMENT_TEAM`
- `IOS_PROVISIONING_PROFILE_SPECIFIER`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_FILE` or `APP_STORE_CONNECT_API_KEY_BASE64`

Important: the Apple signing certificate and provisioning profile still need to
exist on the macOS runner itself. The workflow only materializes the App Store
Connect API key file for upload.

## 7. Keep the release flow manual at first

This setup intentionally makes release jobs manual.

Recommended rollout order:

1. Get `android-build-debug`, `android-build-release`, `android-test`,
   `ios-build-debug`, `ios-test`, and `ios-build-release` green on pull
   requests.
2. Run `publishInternal` manually and confirm the Android artifact reaches Play
   internal testing.
3. Run `iosArchiveRelease` manually and confirm an `.ipa` is produced.
4. Run `iosTestFlight` manually and confirm the build appears in TestFlight.
5. Only after that, use `promote-alpha`, `promote-beta`, and
   `promote-production`.

That sequence keeps CI validation independent from store delivery and signing.

## 8. Adapt the project-specific values

These files usually need small edits in a new project:

- [`android-app/module.yaml`](../android-app/module.yaml)
  for `namespace`, `applicationId`, and Android SDK settings
- [`fastlane/Appfile`](../fastlane/Appfile)
  for package name and iOS identifiers
- [`fastlane/Fastfile`](../fastlane/Fastfile)
  if your iOS scheme, output paths, or artifact patterns differ
- [`.github/workflows/mobile-ci.yml`](../.github/workflows/mobile-ci.yml)
  if you want different triggers, environment names, or runner labels

## 9. What to explain when you share this publicly

If you turn this into a blog post, template repo, or conference talk, lead with
the pattern instead of the vendor details:

- CI YAML is only orchestration
- repo scripts own the build contract
- secrets are materialized at runtime
- release steps are intentionally separate from validation steps
- the same job names work locally and in CI

That is the part other teams can copy even if their project details differ.

## 10. Next docs to read

- [CI Architecture](reference/architecture.md)
- [Secrets Reference](reference/secrets.md)
- [Local Development](reference/local-development.md)
- [Troubleshooting](reference/troubleshooting.md)
