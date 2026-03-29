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

## IDE flow without Gradle sync

Because this repository uses Amper instead of Gradle as the project model,
Android Studio will not generate the normal Android run configurations for the
app module. The supported low-friction workflow is:

- use the checked-in shell run configurations under `.run/`
- use repo-owned scripts under `scripts/dev/`
- treat Xcode as the primary runner/debugger for iOS

If your JetBrains IDE does not show the shared `.run` configurations, make sure
the Shell Script plugin is enabled.

Recommended daily entry points:

```bash
just doctor
just android-emulators
just android-start <avd-name>
just android-run
just android-run-debug
just android-test
just android-build-debug
just ios-open
just ios-build-debug
```

`just android-run` builds the debug APK with the same repo-owned flow used by
CI, installs it with `adb`, and launches `studio.mekate.b3.MainActivity`. If
multiple Android devices are connected, set `ANDROID_SERIAL` first.

`just android-run-debug` does the same install flow, but launches the app with
`am start -D`, so the process waits for a debugger. After that, use `Run >
Attach debugger to Android process` in Android Studio or IntelliJ IDEA and
select `studio.mekate.b3`.

`just android-test` runs `./amper test -m shared -p android` directly, stores
JUnit XML under `build/reports/shared/android`, and prints a compact test
summary with failure details. This is the recommended local and IDE-friendly
test entry point.

`just android-emulators` lists the locally available Android Virtual Devices.

`just android-start <avd-name>` starts a named emulator in the background and
writes its output to `build/logs/android-emulator-<avd-name>.log`.

`just ios-open` opens [`ios-app/module.xcodeproj`](../../ios-app/module.xcodeproj)
in Xcode, where you can use the standard iOS run/debug loop against a simulator
or device.

`just doctor` checks the expected local toolchain and shows whether an Android
device or emulator is already available for `just android-run`.

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
Use `just android-test` instead when you want cleaner local test output in the
terminal or through the shared `.run/Android Test` configuration in IntelliJ
IDEA / Android Studio.

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
