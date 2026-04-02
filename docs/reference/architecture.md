# CI Architecture

This repository uses a layered CI design so the mobile pipeline stays portable
and understandable.

## The layers

### 1. CI adapters

These are the thinnest layer:

- [`.github/workflows/mobile-ci.yml`](../../.github/workflows/mobile-ci.yml)
- [`.gitlab-ci.yml`](../../.gitlab-ci.yml)

They only decide:

- when jobs run
- which runner executes them
- which environments or secrets are available
- which artifacts move between jobs

They should not contain business logic.

### 2. Shared job dispatcher

The real CI contract lives in
[`scripts/ci/run_job.sh`](../../scripts/ci/run_job.sh).

It maps stable job names such as `android-build-release` or
`ios-testflight` to the right implementation path.

This gives you one place to answer the question: "What does this CI job
actually do?"

### 3. Shared shell helpers

[`scripts/ci/lib.sh`](../../scripts/ci/lib.sh) loads helper modules under
[`scripts/ci/lib/`](../../scripts/ci/lib):

- `common.sh`: logging, workspace prep, Java setup
- `context.sh`: normalize GitHub, GitLab, and local environment variables
- `env.sh`: PATH, Bundler, Android SDK detection
- `android.sh`: Android prep, signing files, Play key materialization
- `ios.sh`: Xcode checks, Fastlane prep, App Store Connect key materialization

This is where the portability comes from. GitHub and GitLab expose different
variables, but the rest of the pipeline only sees normalized values like:

- `BUILD_NUMBER`
- `BUILD_SHA`
- `BUILD_BRANCH`
- `DEFAULT_BRANCH`
- `VERSION_CODE`
- `VERSION_NAME`
- `IOS_BUILD_NUMBER`

The iOS helpers also normalize the temporary Kotlin builder selection used by
the Xcode project:

- `KOTLIN_IOS_BUILDER=amper` keeps the current Amper path
- `KOTLIN_IOS_BUILDER=gradle` switches iOS to the Gradle bridge
- `GRADLE_USER_HOME` points the bridge at a repo-local Gradle cache

In the current bridge phase, the iOS CI jobs and Fastlane release lane default
to `KOTLIN_IOS_BUILDER=gradle` so archive and TestFlight flows exercise the
same Kotlin framework path that was validated locally.

GitLab shell runners use an external Gradle home for iOS jobs so checkout
cleanup does not trip over a live `.gradle-user-home` from a previous bridge
run. Android jobs keep their original Amper behavior and do not inherit that
iOS-specific Gradle home setting.

### 4. Platform command layer

[`fastlane/Fastfile`](../../fastlane/Fastfile)
is the command layer above Amper and store delivery APIs.

Examples:

- Android `buildDebug` and `buildRelease` call `./amper build`
- Android release also runs
  [`scripts/ci/build_android_aab.sh`](../../scripts/ci/build_android_aab.sh)
  to produce an `.aab`
- Android `internal` and promotion lanes call Play Store actions
- iOS `buildRelease` creates a signed archive/export
- iOS `uploadTestFlight` uploads the produced `.ipa`

### 5. Build system layer

Amper is the actual project build system.

Relevant files:

- [`project.yaml`](../../project.yaml)
- [`android-app/module.yaml`](../../android-app/module.yaml)
- [`ios-app/module.yaml`](../../ios-app/module.yaml)

The CI docs should treat this as project-specific, while the CI layer above it
is the reusable pattern.

## Example execution flow

### Android release build

1. GitHub Actions starts `android_build_release`.
2. The workflow installs Java, Ruby, Bundler, and Android tooling.
3. The workflow runs `./scripts/ci/run_job.sh android-build-release`.
4. The dispatcher calls the Android prep helpers.
5. The helpers normalize CI context, configure PATH, apply Android versioning,
   and materialize signing files when secrets exist.
6. The dispatcher runs Fastlane `buildRelease`.
7. Fastlane calls Amper for the app build and then builds the Android App
   Bundle.

### iOS TestFlight upload

1. GitHub Actions starts `ios_testflight`.
2. The workflow downloads the archive artifact from the archive job.
3. The workflow runs `./scripts/ci/run_job.sh ios-testflight`.
4. The iOS helpers materialize the App Store Connect API key.
5. Fastlane uploads the archived `.ipa` to TestFlight.

## Why this is easier to share

This layout is public-friendly because it teaches a pattern instead of just a
YAML file:

- people can run the same job names locally
- CI logic is reviewable without opening the Actions UI
- provider migration is easier because the scripts stay stable
- release steps are explicit and intentionally separated

If you share this setup with others, emphasize the stable job contract and the
thin-adapter model first.
