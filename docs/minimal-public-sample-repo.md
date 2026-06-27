# Legacy Minimal Public Sample Repo Blueprint

This document is kept as a legacy sample blueprint for the public mobile CI
example repository. It still describes the historical sample shape we used to
explain the CI pattern, but it is not intended to mirror the current `Mobi`
module layout one-to-one.

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

Start from a Kotlin Toolchain project instead of hand-assembling the app.
If you are migrating an older Amper scaffold, create the new wrappers first:

```bash
kotlin update --create
```

That writes `kotlin` and `kotlin.bat` to the project root. Future wrapper
updates can use `./kotlin update`.

The published sample keeps its app layer intentionally small so the CI pattern
stays visible.

## What to keep from the project scaffold

Keep these generated pieces:

- `kotlin`
- `kotlin.bat`
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
kotlin
kotlin.bat
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
- `scripts/ci/run_kotlin_with_logs.sh`
- `scripts/ci/run_fastlane_with_kotlin_logs.sh`
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
- generated `build/`, `.kotlin-cache/`, `.kotlin-user-home/`, `.gradle/`,
  `.idea/`, and
  `local.properties`

You can always add some of those back later if you want a broader template.

## Project-specific edits after generation

After creating or migrating the Kotlin Toolchain project, I would make these
edits before publishing the separate sample repo.

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
- platform-specific entrypoints generated by the project scaffold

The blog post is about CI architecture, not app design.

### 4. Keep iOS build assumptions stable

The current CI scripts assume:

- Xcode project path: `ios-app/module.xcodeproj`
- scheme name: `app`

Keep those paths stable so the shared CI scripts do not need project-specific
branching.

## What the sample repo README should contain

I would keep the separate repo README extremely focused:

1. Generate or migrate the project with Kotlin Toolchain wrappers.
2. Explain the few edits made after generation.
3. Show the shared CI job names.
4. Show the local smoke-test commands.
5. List the required GitHub Actions secrets.
6. Link back to the longer blog post for the architectural explanation.

The sample repo should feel like a runnable companion to the article, not a
second article.

## Validation notes

After narrowing the sample to Android, iOS, and shared modules, these commands
should be the baseline smoke path:

```bash
./kotlin build -m android-app -p android -v debug
./kotlin test -m shared -p android
./scripts/ci/run_job.sh ios-build-debug
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
2. Create or migrate the Kotlin Toolchain project wrappers.
3. Remove `jvm-app/` and the JVM references from the project.
4. Add the CI files and Fastlane files.
5. Add `.gitignore`.
6. Adjust Android package and iOS identifiers.
7. Run local smoke tests:

```bash
bundle install
export KOTLIN_CLI_BOOTSTRAP_CACHE_DIR="$PWD/.kotlin-cache"
export KOTLIN_CLI_USER_HOME="$PWD/.kotlin-user-home"
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
- one generated or migrated Kotlin Toolchain starting point
- one shared app screen
- one shared test
- one clean repo structure

The article can explain the pattern. The sample repo should prove that the
pattern is reproducible.
