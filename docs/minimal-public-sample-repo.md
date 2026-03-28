# Minimal Public Sample Repo Blueprint

This document defines the smallest separate repository I would create to
demonstrate the CI pattern from this project in a clean, reproducible way.

A concrete version of this plan now lives in the published sample repository:
[Portable KMP CI Sample](https://github.com/Mekate-Studio/Portable-KMP-CI).

The goal is not to publish a polished app. The goal is to publish the minimum
Kotlin Multiplatform project that still exercises:

- Android debug and release builds
- Android tests
- iOS debug and release builds
- optional iOS archive and TestFlight flows
- shared CI job dispatch
- runtime secret materialization

## Recommended starting point

Start from a fresh Amper scaffold instead of hand-assembling the app:

```bash
mkdir my-kmp-ci-app
cd my-kmp-ci-app
amper init compose-multiplatform
```

I verified locally on March 27, 2026 that the current Amper CLI supports
`amper init compose-multiplatform` non-interactively.

The published sample includes its own `./scripts/regenerate_from_amper.sh`
command so it can delete and recreate its Amper-generated app layer in place.

## What to keep from the Amper scaffold

Keep these generated pieces:

- `amper`
- `amper.bat`
- `project.yaml`
- `android-app/`
- `ios-app/`
- `shared/`

Those are the app files that prove the CI can build a real multiplatform
project.

## What to remove for the public sample

To keep the repo focused on mobile CI, remove the JVM app from the generated
template:

- remove `jvm-app/`
- remove `jvm-app` from `project.yaml`
- remove `shared/src@jvm/`
- remove `shared/test@jvm/`
- remove `jvm` from the explicit `platforms` list in `shared/module.yaml` if
  that list is present

That leaves a cleaner public story:

- `android-app`
- `ios-app`
- `shared`

## Minimal repo contents

This is the structure I would aim for:

```text
.github/workflows/mobile-ci.yml
.gitignore
Gemfile
Gemfile.lock
README.md
amper
amper.bat
project.yaml
android-app/
ios-app/
shared/
fastlane/
scripts/ci/
```

### Required app files

These are the minimum app files I would keep under version control:

- `project.yaml`
- `android-app/module.yaml`
- `android-app/src/AndroidManifest.xml`
- `android-app/src/MainActivity.kt`
- `ios-app/module.yaml`
- `ios-app/module.xcodeproj/project.pbxproj`
- `ios-app/src/Info.plist`
- `ios-app/src/ViewController.kt`
- `ios-app/src/iosApp.swift`
- `shared/module.yaml`
- `shared/src/Screen.kt`
- `shared/src/World.kt` or equivalent shared sample code
- `shared/src@android/`
- `shared/src@ios/`
- `shared/test/CommonTest.kt`

### Required CI files

Copy these from the CI-enabled sample:

- `.github/workflows/mobile-ci.yml`
- `Gemfile`
- `fastlane/Appfile`
- `fastlane/Fastfile`
- `scripts/ci/run_job.sh`
- `scripts/ci/lib.sh`
- `scripts/ci/lib/common.sh`
- `scripts/ci/lib/context.sh`
- `scripts/ci/lib/env.sh`
- `scripts/ci/lib/android.sh`
- `scripts/ci/lib/ios.sh`
- `scripts/ci/apply_android_version.sh`
- `scripts/ci/build_android_aab.sh`
- `scripts/ci/run_amper_with_logs.sh`
- `scripts/ci/run_fastlane_with_amper_logs.sh`
- `scripts/ci/run_xcodebuild_with_logs.sh`
- `scripts/ci/print_recent_logs.sh`
- `scripts/ci/write_android_signing_files.sh`
- `scripts/ci/write_google_play_key.sh`
- `scripts/ci/write_app_store_connect_api_key.sh`

## Files I would not include in the public sample

To keep the repository small and reduce distractions, I would leave these out at
first:

- `.gitlab-ci.yml`
- `Dockerfile`
- `Justfile`
- `CONTRIBUTING.md`
- `docs/reference/`
- `fastlane/README.md`
- local `secrets/` files
- generated `build/`, `.amper-cache/`, `.gradle/`, `.idea/`, and
  `local.properties`

You can always add some of those back later if you want a broader template.

## Project-specific edits after generation

After `amper init compose-multiplatform`, I would make these edits before
publishing the separate sample repo.

### 1. Narrow the project to mobile

Update `project.yaml` so it only lists:

```yaml
modules:
  - android-app
  - ios-app
  - shared
```

If `shared/module.yaml` explicitly lists `jvm`, remove it.

### 2. Add Android app settings needed by CI

The generated `android-app/module.yaml` is a good start, but the CI flow here
expects explicit Android settings for namespace, application ID, SDK levels, and
versioning.

At minimum, add:

```yaml
settings:
  compose: enabled
  junit: junit-4
  android:
    namespace: com.example.kmpci
    applicationId: com.example.kmpci
    minSdk: 23
    compileSdk: 36
    targetSdk: 36
    signing:
      enabled: true
      propertiesFile: ./keystore.properties
    versionCode: 1
    versionName: "1.0-local"
```

That matches the assumptions in
[`scripts/ci/apply_android_version.sh`](../scripts/ci/apply_android_version.sh)
and
[`scripts/ci/write_android_signing_files.sh`](../scripts/ci/write_android_signing_files.sh).

### 3. Keep the app code intentionally boring

The sample app should be visually simple.

Good enough is:

- one shared screen
- one shared test
- platform-specific entrypoints generated by Amper

The blog post is about CI architecture, not app design.

### 4. Keep iOS build assumptions stable

The current CI scripts assume:

- Xcode project path: `ios-app/module.xcodeproj`
- scheme name: `app`

The generated Amper template already matches that, which is another reason it is
the right starting point.

## What the sample repo README should contain

I would keep the separate repo README extremely focused:

1. Generate the project with Amper.
2. Explain the few edits made after generation.
3. Show the shared CI job names.
4. Show the local smoke-test commands.
5. List the required GitHub Actions secrets.
6. Link back to the longer blog post for the architectural explanation.

The sample repo should feel like a runnable companion to the article, not a
second article.

## Validation notes

I verified this direction locally on March 27, 2026 using a temporary project
generated from:

```bash
amper init compose-multiplatform
```

After removing `jvm-app/` and the JVM references, these commands still
succeeded:

```bash
./amper build -m android-app -p android -v debug
./amper test -m shared -p android
./amper build -m ios-app
```

That is a good signal that the public sample repo can stay mobile-focused
without keeping the generated JVM app around.

I also scaffolded the concrete companion sample and validated its documented
local smoke-test path sequentially with:

```bash
./scripts/ci/run_job.sh android-build-debug
./scripts/ci/run_job.sh android-test
./scripts/ci/run_job.sh android-build-release
./scripts/ci/run_job.sh ios-build-debug
```

The iOS build jobs now target a generic iOS Simulator destination and force a
single simulator architecture matching the host. That removes the dependency on
a precreated simulator device. The remaining host requirement is that Xcode has
an iOS Simulator runtime installed, so `ios-build-debug` remains the safer
local baseline check.

## Suggested bootstrap sequence for the separate repo

This is the sequence I would actually follow:

1. Create a new repo directory.
2. Run `amper init compose-multiplatform`.
3. Remove `jvm-app/` and the JVM references from the project.
4. Add the CI files and Fastlane files.
5. Add `.gitignore`.
6. Adjust Android package and iOS identifiers.
7. Run local smoke tests:

```bash
bundle install
export AMPER_BOOTSTRAP_CACHE_DIR="$PWD/.amper-cache"
./scripts/ci/run_job.sh android-build-debug
./scripts/ci/run_job.sh android-test
./scripts/ci/run_job.sh ios-build-debug
```

8. Commit that baseline before adding release secrets.

## My recommendation

If the purpose of the separate repo is to support the blog post, optimize it for
clarity over completeness.

That means:

- one CI provider first, not two
- one generated Amper starting point
- one shared app screen
- one shared test
- one clean repo structure

The article can explain the pattern. The sample repo should prove that the
pattern is reproducible.
