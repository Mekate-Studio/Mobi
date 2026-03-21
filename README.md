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

The pipeline uses the root `Dockerfile` to build a reusable Android/fastlane
image and then runs the fastlane lanes from `.gitlab-ci.yml` inside that image.

# Reference links

- [GitLab CI Documentation](https://docs.gitlab.com/ee/ci/)
- [GitLab Runner Docker executor](https://docs.gitlab.com/runner/executors/docker/)
- [Fastlane Android release deployment](https://docs.fastlane.tools/getting-started/android/release-deployment/)
- [fastlane `upload_to_play_store` setup](https://docs.fastlane.tools/actions/upload_to_play_store/)
- [GitLab blog post: Android publishing with GitLab and fastlane](https://about.gitlab.com/2019/01/28/android-publishing-with-gitlab-and-fastlane/)

# How The Pipeline Works

## GitLab CI

GitLab orchestrates the pipeline from `.gitlab-ci.yml`:

- `environment`: build or refresh the branch-specific Docker image used by the
  rest of the jobs
- `build`: run `fastlane buildDebug` and `fastlane buildRelease`
- `test`: run `fastlane test`
- `internal`, `alpha`, `beta`, `production`: manual Play Store deployment and
  promotion lanes

The production promotion job is limited to the default branch.

## Docker

The root `Dockerfile` defines the CI build environment:

- JDK 17
- Android command-line tools and SDK packages matching `android-app/module.yaml`
- Ruby, Bundler, and the gems from `Gemfile.lock`

Using a custom image keeps Android SDK installation out of every job and makes
the build environment more repeatable.

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

You still need Android signing configured for release builds if you plan to
publish to Google Play.

## GitLab provisioning checklist

Use this checklist to make the CI pipeline fully operational:

1. Enable a GitLab Runner that can run Docker jobs.
2. Make sure the runner allows Docker-in-Docker for the `environment` stage.
3. Confirm the project container registry is enabled, because the pipeline
   pushes the CI image to `$CI_REGISTRY_IMAGE`.
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
