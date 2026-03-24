# Kotlin Multiplatform + Amper

This repository is now an [Amper](https://www.amper.org/) project with a small
Kotlin Multiplatform setup:

- `shared`: common Compose UI and shared Kotlin logic
- `android-app`: Android application target
- `ios-app`: iOS application target

The sample app still renders a simple greeting, but the UI now comes from shared
multiplatform code instead of an Android-only XML layout.

# Project layout

```text
project.yaml
shared/
android-app/
ios-app/
```

- `project.yaml` is the Amper entrypoint for the workspace.
- Each module has its own `module.yaml`.
- The checked-in `amper` and `amper.bat` scripts are the project wrapper.

# Requirements

- JDK 17+
- Android SDK for Android builds
- Xcode for iOS builds

Amper will download additional toolchains on first build if they are missing.
In sandboxed or CI environments, set `AMPER_BOOTSTRAP_CACHE_DIR` to a writable
project-local path such as `.amper-cache`.

# Common commands

Build everything:

```bash
AMPER_BOOTSTRAP_CACHE_DIR=$PWD/.amper-cache ./amper build
```

Build just the Android app:

```bash
AMPER_BOOTSTRAP_CACHE_DIR=$PWD/.amper-cache ./amper build -m android-app -p android -v debug
```

Run tests:

```bash
AMPER_BOOTSTRAP_CACHE_DIR=$PWD/.amper-cache ./amper test -m shared -p android
```

Open or generate the iOS Xcode project:

```bash
AMPER_BOOTSTRAP_CACHE_DIR=$PWD/.amper-cache ./amper build -m ios-app
```

After the first iOS build, Amper manages `ios-app/module.xcodeproj`.

# CI and release tooling

GitLab CI and fastlane now invoke Amper instead of Gradle. They use a
project-local Amper cache (`.amper-cache`), and the Play Store lanes still
expect Android signing and Google Play credentials to be configured before
publishing will work.

The active CI path for this repository is now a self-hosted macOS GitLab runner.
That is the right long-term shape for the project because Android already works
there and future iOS CI will require macOS and Xcode anyway.

# Reference links

- [GitLab CI Documentation](https://docs.gitlab.com/ee/ci/)
- [GitLab Runner Docker executor](https://docs.gitlab.com/runner/executors/docker/)
- [Fastlane Android release deployment](https://docs.fastlane.tools/getting-started/android/release-deployment/)
- [fastlane `upload_to_play_store` setup](https://docs.fastlane.tools/actions/upload_to_play_store/)
- [GitLab blog post: Android publishing with GitLab and fastlane](https://about.gitlab.com/2019/01/28/android-publishing-with-gitlab-and-fastlane/)

# How The Pipeline Works

## GitLab CI

GitLab orchestrates the pipeline from `.gitlab-ci.yml`:

- `build`: run `fastlane buildDebug` and `fastlane buildRelease`
- `test`: run `fastlane test`
- `internal`, `alpha`, `beta`, `production`: manual Play Store deployment and
  promotion lanes

The Android jobs are tagged to run on a `macos` runner. Production promotion is
limited to the default branch.

## Docker

The root `Dockerfile` is still useful for reproducing Android builds locally in a
Linux container, but it is no longer the primary CI execution path.

It defines a reusable Android/fastlane environment with:

- JDK 17
- Android command-line tools and SDK packages matching `android-app/module.yaml`
- Ruby, Bundler, and the gems from `Gemfile.lock`

This is mainly helpful for local debugging and parity checks. The GitLab mobile
jobs themselves now run directly on macOS.

## Fastlane

Fastlane is the command layer between GitLab and Amper:

- `buildDebug` and `buildRelease` call `./amper build`
- `test` calls `./amper test`
- `internal` uploads the latest release artifact to the Play internal track
- the promotion lanes move an already-uploaded build across Play tracks

The Play configuration lives in `fastlane/Appfile` and is now driven by
environment variables so the same setup works both in CI and locally.

# CI Configuration

## Versioning

Before Android builds run, CI applies version values to
`android-app/module.yaml`:

- `VERSION_CODE` defaults to `CI_PIPELINE_IID`
- `VERSION_NAME` defaults to `1.0-<CI_COMMIT_SHORT_SHA>`

This is handled by `scripts/ci/apply_android_version.sh`. It keeps
`versionCode` increasing for Play Store uploads without requiring manual edits to
the module file.

## Required GitLab variables

Set these in GitLab CI/CD before using the publish jobs:

- `GOOGLE_PLAY_JSON_KEY`: either the raw service-account JSON content or a
  GitLab file variable pointing to that JSON file
- `ANDROID_PACKAGE_NAME`: optional override if you changed the package name from
  `studio.mekate.b3`
- `ANDROID_KEYSTORE_FILE` or `ANDROID_KEYSTORE_BASE64`: the Android release
  keystore as either a file variable or a base64-encoded value
- `ANDROID_KEYSTORE_PASSWORD`: the keystore password
- `ANDROID_KEY_ALIAS`: the alias of the upload key inside the keystore
- `ANDROID_KEY_PASSWORD`: the password for that key alias

During branch-based setup and testing, these variables must not be protected if
you want non-protected branches to receive them. Once your release flow moves to
protected branches, protect the signing and Play secrets again.

For iOS archive and TestFlight jobs, set these as well:

- `IOS_BUNDLE_IDENTIFIER`: the iOS bundle identifier, currently
  `studio.mekate.b3`
- `IOS_DEVELOPMENT_TEAM`: your Apple team ID
- `IOS_PROVISIONING_PROFILE_SPECIFIER`: the exact App Store provisioning profile
  name used for Release signing, for example `b3 app store`
- `APP_STORE_CONNECT_KEY_ID`: the App Store Connect API key ID
- `APP_STORE_CONNECT_ISSUER_ID`: the App Store Connect issuer ID
- `APP_STORE_CONNECT_API_KEY_FILE` or `APP_STORE_CONNECT_API_KEY_BASE64`: the
  `.p8` App Store Connect API key as either a GitLab file variable or a
  base64-encoded value

The iOS signing material itself remains on the macOS runner host through Xcode
and your installed certificates/profiles. GitLab only supplies the App Store
Connect API key used for upload.

## Variables to protect again

Once you are done testing from non-protected branches, protect these GitLab
variables again:

- `ANDROID_KEYSTORE_FILE` or `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `GOOGLE_PLAY_JSON_KEY`
- `IOS_BUNDLE_IDENTIFIER`
- `IOS_DEVELOPMENT_TEAM`
- `IOS_PROVISIONING_PROFILE_SPECIFIER`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_FILE` or `APP_STORE_CONNECT_API_KEY_BASE64`

The simplest release posture is:

- keep the secrets above protected
- keep `iosArchiveRelease`, `iosTestFlight`, `publishInternal`, and production
  promotion jobs on the default branch
- use unprotected variables only temporarily when you are actively debugging
  branch pipelines

## GitLab provisioning checklist

Use this checklist to make the CI pipeline fully operational:

1. Enable a GitLab Runner that can run Docker jobs.
2. For this repository, prefer a self-hosted macOS runner with the `shell`
   executor and a `macos` tag.
3. Confirm the project container registry is enabled if you also want the Linux
   Docker image path available for local or experimental use.
4. Add `GOOGLE_PLAY_JSON_KEY` in GitLab CI/CD settings.
5. Add `ANDROID_PACKAGE_NAME` if your app no longer uses
   `studio.mekate.b3`.
6. Add the Android signing variables:
   `ANDROID_KEYSTORE_FILE` or `ANDROID_KEYSTORE_BASE64`,
   `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and
   `ANDROID_KEY_PASSWORD`.
7. Protect production secrets if you only want them available on the default
   branch.

For Google Play itself, provision these items first:

1. Create the app in Google Play Console.
2. Create a Google Cloud service account with Android Publisher access.
3. Grant that service account access to the app in Play Console.
4. Download the service-account JSON key and store it in
   `GOOGLE_PLAY_JSON_KEY`.

For Android release signing, the repository now uses Amper's official
`settings.android.signing` support with `android-app/keystore.properties`. In
CI, the keystore and properties file are generated by
`scripts/ci/write_android_signing_files.sh` from the signing variables above.
An example properties file is committed at
`android-app/keystore.properties.example`.

## Current runner model

The repository is set up around a macOS runner now:

- Android jobs run directly on the host machine with Bundler, Fastlane, the
  Android SDK, and Amper available on the Mac
- This avoids the Linux shared-runner incompatibilities encountered during setup
- The same runner model can later host iOS jobs that need Xcode
- `iosBuildDebug` and `iosBuildRelease` are unsigned simulator-only Xcode sanity
  builds for CI
- `iosArchiveRelease` is the manual CI checkpoint for generating the signed IPA
- `iosTestFlight` is the manual CI job that uploads the archived IPA artifact to
  TestFlight on the default branch

If you later add more mobile repositories, consider a group runner instead of a
project-only runner.

# Running Locally

You can run the same build and test steps locally without GitLab:

```bash
bundle install
export AMPER_BOOTSTRAP_CACHE_DIR="$PWD/.amper-cache"
export VERSION_CODE=1
export VERSION_NAME="1.0-local"
./scripts/ci/apply_android_version.sh
bundle exec fastlane buildDebug
bundle exec fastlane test
bundle exec fastlane buildRelease
```

To approximate CI more closely, run the commands inside the repo Docker image:

```bash
docker build --platform linux/amd64 -t b3-ci .
docker run --rm -it -v "$PWD:/work" -w /work b3-ci bundle exec fastlane buildDebug
```

On Apple Silicon Macs, use an `amd64` container for Android builds. The Android
toolchain inside the image can fail under `arm64` with AAPT2 startup errors even
when the image itself builds successfully.

For local Play uploads, set one of the following first:

- `GOOGLE_PLAY_JSON_KEY_FILE=/absolute/path/to/google-play-key.json`
- `GOOGLE_PLAY_JSON_KEY='{"type":"service_account",...}'`

If you use `GOOGLE_PLAY_JSON_KEY`, you can materialize it with:

```bash
./scripts/ci/write_google_play_key.sh "$PWD/google_play_api_key.json"
export GOOGLE_PLAY_JSON_KEY_FILE="$PWD/google_play_api_key.json"
```

# Final iOS Flow

The working iOS flow is now split into two layers:

- `iosBuildDebug` and `iosBuildRelease`: unsigned simulator-only CI sanity
  builds
- `iosArchiveRelease` and `iosTestFlight`: signed device archive and upload
  jobs

That separation is intentional. Normal CI feedback does not depend on Apple
provisioning, while real release delivery still uses the signed Release path.

## Local iOS release flow

1. Make sure Xcode on the macOS machine has:
   - your Apple Distribution certificate
   - the App Store provisioning profile for `studio.mekate.b3`
2. Export:
   - `IOS_BUNDLE_IDENTIFIER`
   - `IOS_DEVELOPMENT_TEAM`
   - `IOS_PROVISIONING_PROFILE_SPECIFIER`
   - `APP_STORE_CONNECT_KEY_ID`
   - `APP_STORE_CONNECT_ISSUER_ID`
   - `APP_STORE_CONNECT_API_KEY_FILE`
3. Run:

```bash
bundle exec fastlane ios buildRelease
bundle exec fastlane ios uploadTestFlight
```

## GitLab iOS release flow

1. Keep `iosBuildDebug` and `iosBuildRelease` green.
2. Trigger `iosArchiveRelease` manually on the default branch.
3. Confirm the archive job publishes `build/ios/ios-app.ipa` as an artifact.
4. Trigger `iosTestFlight`.
5. Confirm the build appears in App Store Connect and finishes TestFlight
   processing.

The `iosTestFlight` job uploads the archived IPA artifact directly, so it does
not need to rebuild the app if `iosArchiveRelease` already succeeded.

## Local provisioning checklist

To run the pipeline steps locally, provision this machine with:

1. JDK 17 or newer.
2. Ruby and Bundler.
3. Docker Desktop or another working Docker Engine install if you want to mimic
   CI with the repo image.
4. Android SDK command-line tools and the SDK packages needed by the project if
   you want to build outside Docker.
5. Xcode if you also want to build the iOS app.

Recommended local setup flow:

1. Install gems with `bundle install`.
2. Export `AMPER_BOOTSTRAP_CACHE_DIR="$PWD/.amper-cache"`.
3. Run `./scripts/ci/apply_android_version.sh` after setting `VERSION_CODE` and
   `VERSION_NAME`.
4. Run `bundle exec fastlane buildDebug`.
5. Run `bundle exec fastlane test`.
6. Materialize signing files with `./scripts/ci/write_android_signing_files.sh`.
7. Run `bundle exec fastlane buildRelease`.

For local iOS archive and TestFlight flows, also set:

- `IOS_BUNDLE_IDENTIFIER`
- `IOS_DEVELOPMENT_TEAM`
- `IOS_PROVISIONING_PROFILE_SPECIFIER`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_FILE` or `APP_STORE_CONNECT_API_KEY_BASE64`

Recommended local iOS commands:

```bash
export IOS_BUNDLE_IDENTIFIER="studio.mekate.b3"
export IOS_DEVELOPMENT_TEAM="YOUR_TEAM_ID"
export IOS_PROVISIONING_PROFILE_SPECIFIER="YOUR_APP_STORE_PROFILE"
export IOS_VERSION="1.0"
export IOS_BUILD_NUMBER="1"
bundle exec fastlane ios buildRelease
bundle exec fastlane ios uploadTestFlight
```

If you want to exercise publishing locally, also provision:

1. A Google Play service-account JSON key.
2. `GOOGLE_PLAY_JSON_KEY_FILE` or `GOOGLE_PLAY_JSON_KEY`.
3. Android release signing values:
   `ANDROID_KEYSTORE_FILE` or `ANDROID_KEYSTORE_BASE64`,
   `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and
   `ANDROID_KEY_PASSWORD`.

The fastest way to approximate CI locally is:

1. Install Docker.
2. On Apple Silicon, run `docker build --platform linux/amd64 -t b3-ci .`.
3. Run the fastlane lanes inside that image.

If you want to validate the GitLab YAML itself, use GitLab CI Lint in the
project UI after committing changes.

## Local signing example

If you already have a keystore on disk, this is the simplest local setup:

```bash
export ANDROID_KEYSTORE_FILE="$PWD/secrets/upload-keystore.jks"
export ANDROID_KEYSTORE_PASSWORD="your-keystore-password"
export ANDROID_KEY_ALIAS="upload"
export ANDROID_KEY_PASSWORD="your-key-password"
./scripts/ci/write_android_signing_files.sh
bundle exec fastlane buildRelease
```

If you prefer not to keep the keystore as a file path in your shell, you can
base64-encode it and use `ANDROID_KEYSTORE_BASE64` instead.

# Future iOS CI

The current runner choice already prepares the repo for iOS CI:

- iOS jobs should run on the same `macos` runner
- Xcode and `xcodebuild` will be required on the runner host
- Fastlane can later be extended with iOS lanes for build, test, TestFlight, or
  App Store delivery
- Apple signing, certificates, and provisioning profiles should be added only
  when the iOS target is ready for CI

The current iOS sanity jobs are `iosBuildDebug` and `iosBuildRelease`, which run
unsigned simulator-only `xcodebuild` invocations on the macOS runner and store
the generated logs and derived data as artifacts.

A reasonable future job layout is:

- `iosTest`
- `iosArchive`
- `iosTestFlight`

Those should remain separate from the Android jobs even if they share the same
runner.

# Finish Play Setup Later

When Google Play Console verification and package registration are complete, the
remaining steps are:

1. Confirm the app exists in Play Console as `studio.mekate.b3`.
2. Add `GOOGLE_PLAY_JSON_KEY` to GitLab if it is not already present.
3. Keep release secrets protected if you switch to protected-branch releases.
4. Run `buildRelease` successfully in CI.
5. Trigger `publishInternal` manually.
6. Verify the upload in the internal testing track.
7. Only after that, use the promotion jobs for alpha, beta, and production.

The recommended first successful publishing milestone is `publishInternal`, not
production.

# iOS Signing And TestFlight

The repository now includes the first TestFlight-oriented scaffolding:

- fastlane iOS lanes for `buildRelease` and `uploadTestFlight`
- a manual `iosTestFlight` GitLab job on the macOS runner
- a CI helper script that materializes the App Store Connect API key file

Before `iosTestFlight` can actually upload a build, you still need to provide:

- `IOS_BUNDLE_IDENTIFIER`
- `IOS_DEVELOPMENT_TEAM`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_FILE` or `APP_STORE_CONNECT_API_KEY_BASE64`

In addition, the macOS runner must have a working Apple signing setup for the
app's release build. The current repository does not yet commit Apple signing
configuration or provisioning assets.

The CI path is now split into two manual iOS release steps:

- `iosArchiveRelease`: builds and exports the signed release `.ipa`
- `iosTestFlight`: uploads the exported `.ipa` to TestFlight

That keeps signing/export validation separate from the actual upload.

The release/TestFlight flow expects these build-time values:

- `IOS_BUNDLE_IDENTIFIER`: the real App Store bundle ID, for example
  `studio.mekate.b3`
- `IOS_DEVELOPMENT_TEAM`: your Apple Developer team ID
- `IOS_PROVISIONING_PROFILE_SPECIFIER`: the exact Xcode provisioning profile
  name used for the App Store release build, for example `b3 app store`
- `IOS_VERSION`: optional marketing version, defaults to `1.0`
- `IOS_BUILD_NUMBER`: optional build number, defaults to `CI_PIPELINE_IID`

Fastlane now injects the bundle identifier, team ID, version, and build number
at build time instead of relying on the generated Xcode project defaults.

To make signing work on the macOS runner, provision the host itself with:

1. Xcode installed and selected with `xcode-select`.
2. The Apple account added in Xcode if you want Xcode-managed automatic signing.
3. Access to the target bundle identifier inside the Apple Developer team.
4. Any required signing certificates and provisioning profiles installed if you
   prefer manual signing later.
5. An App Store Connect API key with permission to upload builds.

The most practical release setup on this self-hosted Mac is a manual
distribution-signing path for Release/TestFlight:

1. Create the App ID in Apple Developer for `IOS_BUNDLE_IDENTIFIER`.
2. Open the generated Xcode project once on the runner host.
3. Select the `app` target and confirm Release signing resolves with your
   Apple Distribution certificate and App Store provisioning profile.
4. Run `bundle exec fastlane ios buildRelease` locally on the runner host.
5. When that works, trigger `iosArchiveRelease` in GitLab.
6. After the archive job succeeds, trigger `iosTestFlight`.

The recommended order for iOS delivery is:

1. Keep `iosBuildDebug` and `iosBuildRelease` green.
2. Add Apple signing to the macOS runner.
3. Add the App Store Connect API key variables.
4. Trigger `iosArchiveRelease` manually on the default branch.
5. Trigger `iosTestFlight` after the archive job succeeds.
6. Verify the build appears in TestFlight before automating anything further.
