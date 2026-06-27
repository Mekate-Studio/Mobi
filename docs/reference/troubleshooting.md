# Troubleshooting

These are the most common failure modes when reproducing this setup.

## Kotlin Toolchain cannot write its bootstrap cache

Symptom:

- Kotlin Toolchain fails early in CI or a sandboxed environment

Fix:

```bash
export KOTLIN_CLI_BOOTSTRAP_CACHE_DIR="$PWD/.kotlin-cache"
```

The shared CI layer already defaults this to a writable project-local path in
[`scripts/ci/lib.sh`](../../scripts/ci/lib.sh).

## Kotlin Toolchain dependency resolution returns a missing file

Symptom:

- Android CI fails during `resolveDependenciesAndroid`
- the error says a file under `Library/Caches/JetBrains/Kotlin/.m2.cache` was
  returned from dependency resolution but is missing on disk

Fix:

- run Android jobs through [`scripts/ci/run_job.sh`](../../scripts/ci/run_job.sh)
- keep `KOTLIN_CLI_USER_HOME` on a workspace-owned path, such as
  `$PWD/.kotlin-user-home`
- cache only Kotlin Toolchain's `.m2.cache`, not the whole Kotlin user home

The shared CI layer sets `KOTLIN_CLI_USER_HOME`, `KOTLIN_CLI_TMP_DIR`, and
`KOTLIN_CLI_JAVA_OPTIONS`. Android Fastlane lanes call
[`scripts/ci/run_kotlin_with_logs.sh`](../../scripts/ci/run_kotlin_with_logs.sh),
which retries bounded Kotlin Toolchain failures where dependency resolution
returns a cache path before the artifact exists on disk. The wrapper checks
direct command output and current-run build logs, downloads the missing Maven
artifact, and opportunistically downloads related KLIB sibling artifacts for the
same coordinate.

## Maven Central returns 429 during Kotlin dependency resolution

Symptom:

- Android CI fails during dependency resolution or compilation
- logs show `Unexpected response code` with `actual: 429` for Maven Central
  checksum URLs

Fix:

- run Android jobs through [`scripts/ci/run_job.sh`](../../scripts/ci/run_job.sh)
- keep Android Fastlane lanes on
  [`scripts/ci/run_kotlin_with_logs.sh`](../../scripts/ci/run_kotlin_with_logs.sh)
- restore `.kotlin-user-home/Library/Caches/JetBrains/Kotlin/.m2.cache` from
  the GitHub Actions smoke cache

The wrapper detects Maven Central throttling in direct output and current-run
Kotlin Toolchain logs, downloads the reported artifacts sequentially through the
canonical Maven Central host, hydrates the base artifact for checksum URLs,
waits briefly, and retries Kotlin Toolchain with the hydrated cache. The cache
keeps that hydration work from becoming the normal path on every run.

## Android SDK is not detected

Symptom:

- Android commands fail because SDK tools are missing

Fix:

- make sure the SDK exists on the runner
- set `ANDROID_SDK_ROOT` or `ANDROID_HOME`
- confirm the SDK has `platform-tools`, `cmdline-tools`, or `build-tools`

Auto-detection lives in
[`scripts/ci/lib/env.sh`](../../scripts/ci/lib/env.sh).

## Bundler or Fastlane is missing on the runner

Symptom:

- `bundle` or `ruby` is not found

Fix:

- install Ruby and Bundler on the runner
- run `bundle install`
- confirm the PATH setup in
  [`scripts/ci/lib/env.sh`](../../scripts/ci/lib/env.sh)

## Android App Bundle is not produced

Symptom:

- release build succeeds but no `.aab` exists

Fix:

- confirm the generated Gradle project exists under `build/tasks`
- confirm a Gradle binary is available
- inspect
  [`scripts/ci/build_android_aab.sh`](../../scripts/ci/build_android_aab.sh)
  for the expected Gradle distribution and artifact path

This script is specific to the current Kotlin Toolchain-generated Android
release flow.

## Google Play upload fails on a draft app

Symptom:

- upload or promotion jobs fail even though credentials are valid

Fix:

- keep `ANDROID_PLAY_RELEASE_STATUS=draft` until the Play app is ready for a
  different status

The Fastlane default in this repo is already `draft`.

## iOS archive fails because of signing

Symptom:

- `ios-archive-release` or `fastlane ios buildRelease` fails in Xcode

Fix:

- verify `IOS_BUNDLE_IDENTIFIER`
- verify `IOS_DEVELOPMENT_TEAM`
- verify `IOS_PROVISIONING_PROFILE_SPECIFIER`
- confirm the Apple Distribution certificate exists on the runner host
- confirm the provisioning profile exists on the runner host

This is usually a runner provisioning problem, not a Fastlane problem.

## TestFlight upload fails because the API key is missing

Symptom:

- Fastlane cannot authenticate to App Store Connect

Fix:

- set `APP_STORE_CONNECT_KEY_ID`
- set `APP_STORE_CONNECT_ISSUER_ID`
- set `APP_STORE_CONNECT_API_KEY_FILE` or `APP_STORE_CONNECT_API_KEY_BASE64`

The materialization step is handled by
[`scripts/ci/write_app_store_connect_api_key.sh`](../../scripts/ci/write_app_store_connect_api_key.sh).

## CI works locally but fails in GitHub Actions

Symptom:

- `run_job.sh` works on your machine but not in Actions

Usually this means one of these:

- the runner image differs from your local machine
- an environment secret is missing or scoped to the wrong environment
- an artifact is not uploaded or downloaded between dependent jobs
- the workflow trigger conditions do not match the branch or event

When debugging, start from the shared job contract and move outward:

1. Confirm the job name passed to `run_job.sh`.
2. Confirm the required secrets for that job.
3. Confirm the runner has the expected tools.
4. Confirm artifact handoff between jobs.

That order tends to surface the real problem faster than starting in the YAML.
