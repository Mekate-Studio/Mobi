# Local Development

One of the goals of this CI design is that the same job contract works locally.

## Prerequisites

- JDK 21+
- Ruby and Bundler
- Android SDK for Android jobs
- Xcode with an installed iOS Simulator runtime for iOS jobs

Set a writable Amper cache before running build commands:

```bash
export AMPER_BOOTSTRAP_CACHE_DIR="$PWD/.amper-cache"
```

## Shared job dispatcher

The fastest way to exercise the same paths CI uses is through
[`scripts/ci/run_job.sh`](../../scripts/ci/run_job.sh):

```bash
./scripts/ci/run_job.sh android-build-debug
./scripts/ci/run_job.sh android-test
./scripts/ci/run_job.sh android-build-release
./scripts/ci/run_job.sh ios-build-debug
./scripts/ci/run_job.sh ios-build-release
```

This is the best path for reproducing CI behavior without pushing commits.

The iOS build jobs target a generic iOS Simulator destination and force a
single simulator architecture matching the host. That removes the dependency on
a precreated simulator device while still avoiding Amper's current
multi-architecture simulator build limitation.

## Just recipes

The repo also exposes common jobs through [`Justfile`](../../Justfile):

```bash
just android-build-debug
just android-test
just ios-build-debug
just ios-build-release
```

## Fastlane directly

If you want to work one layer lower, you can run Fastlane commands directly.

Install gems:

```bash
bundle install
```

Run Android lanes:

```bash
bundle exec fastlane android buildDebug
bundle exec fastlane android test
bundle exec fastlane android buildRelease
```

Run iOS lanes:

```bash
bundle exec fastlane ios buildRelease
bundle exec fastlane ios uploadTestFlight
```

## Local Android release flow

Set version values:

```bash
export VERSION_CODE=1
export VERSION_NAME="1.0-local"
./scripts/ci/apply_android_version.sh
```

If you want signing:

```bash
export ANDROID_KEYSTORE_FILE="$PWD/secrets/upload-keystore.jks"
export ANDROID_KEYSTORE_PASSWORD="your-keystore-password"
export ANDROID_KEY_ALIAS="upload"
export ANDROID_KEY_PASSWORD="your-key-password"
./scripts/ci/write_android_signing_files.sh
```

Then build:

```bash
bundle exec fastlane android buildRelease
```

## Local iOS release flow

The machine must already have the correct Apple signing assets installed.

Set:

- `IOS_BUNDLE_IDENTIFIER`
- `IOS_DEVELOPMENT_TEAM`
- `IOS_PROVISIONING_PROFILE_SPECIFIER`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_FILE` or `APP_STORE_CONNECT_API_KEY_BASE64`

Then run:

```bash
bundle exec fastlane ios buildRelease
bundle exec fastlane ios uploadTestFlight
```

## What local success tells you

If local runs succeed through `run_job.sh`, then the remaining CI work is
usually one of these:

- runner provisioning
- missing secrets
- environment scoping
- artifact handoff between jobs

That is exactly why the shared job dispatcher is worth keeping.
