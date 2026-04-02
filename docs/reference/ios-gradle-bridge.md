# iOS Gradle Bridge Migration

This document describes a temporary migration path for this repository when the
native iOS application needs a more traditional Xcode plus Gradle integration,
while the Android application continues to build through Amper.

The goal is not to replace Amper across the whole repository. The goal is to
introduce the smallest possible Gradle bridge that can:

- build a Kotlin framework for iOS from the existing shared sources
- let Xcode own iOS app assembly and Swift Package Manager dependencies
- keep Android development and CI on the current Amper path
- remain easy to remove once the Amper iOS path is ready for the same use case

## Current repo shape

Today the repository is organized around Amper modules:

- [`project.yaml`](../../project.yaml)
- [`shared-core/`](../../shared-core)
- [`shared-feature-home/`](../../shared-feature-home)
- [`shared-ui-home/`](../../shared-ui-home)
- [`android-app/`](../../android-app)
- [`ios-app/`](../../ios-app)

That shape works well for Android and for the current Amper-managed iOS build,
but it makes a Gradle-backed iOS path impossible until Gradle can see the same
shared Kotlin code.

The key decision in this plan is to avoid creating a second full build of the
repository. Instead, Gradle will own only an iOS-facing framework bridge.

## Why use a bridge instead of a full Gradle migration

A full migration would make both Amper and Gradle responsible for:

- shared Kotlin targets
- dependency declarations
- module boundaries
- plugin versions
- compiler settings
- CI entrypoints

That would create two build systems with overlapping ownership, which is
expensive to maintain and difficult to unwind later.

A bridge keeps the temporary ownership narrow:

- Amper owns Android builds and Amper-native shared module development
- Gradle owns only the Kotlin framework consumed by Xcode
- Xcode owns the iOS application, signing, and Swift packages

This is the smallest compromise that still lets the iOS app follow the standard
Kotlin Multiplatform direct integration path.

## Target temporary architecture

The temporary structure should look like this:

```text
android-app -> Amper -> shared Kotlin source folders

ios-app -> Xcode -> Swift Package Manager
                 -> Gradle bridge -> shared Kotlin source folders
```

The important detail is that the shared source folders stay where they are.
Gradle should point at those folders directly instead of introducing copied
source trees.

## Proposed file layout

The Gradle bridge should live in its own disposable folder:

```text
gradle/
  libs.versions.toml

gradle-bridge/
  gradlew
  gradlew.bat
  gradle/wrapper/
  settings.gradle.kts
  build.gradle.kts
  gradle.properties
  README.md
  shared-kit/
    build.gradle.kts
```

This layout keeps all Gradle-specific ownership isolated. When the bridge is no
longer needed, deleting `gradle-bridge/` should remove most of the temporary
infrastructure in one step.

## Shared ownership rules

To keep the bridge manageable, ownership must stay explicit.

### Amper owns

- Android application packaging and execution
- Android build and test jobs
- Android module wiring
- Amper-native module boundaries for day-to-day Kotlin development

### Gradle bridge owns

- the iOS Kotlin framework build only
- Kotlin-to-Xcode integration through `embedAndSignAppleFrameworkForXcode`
- shared Kotlin compiler settings required for the iOS framework

### Xcode owns

- the iOS application target
- Swift Package Manager dependencies such as TCA
- app signing and provisioning
- simulator and device builds
- archive and distribution flows

If a concern does not clearly belong to the bridge, it should stay out of the
bridge.

## Stage 0: Preconditions

Before adding any Gradle files, confirm the following:

1. The iOS app can already run from Xcode with the current native SwiftUI shell.
2. The shared Kotlin APIs consumed by Swift are reasonably stable.
3. The team agrees that this is a temporary bridge, not a permanent dual-build
   strategy.
4. CI can tolerate an extra iOS framework build job during the transition.

This stage matters because the bridge is a tactical move. If the shared Kotlin
surface is still changing drastically every day, the duplicated build metadata
will create noise instead of reducing risk.

## Stage 1: Introduce the Gradle bridge skeleton

Create the `gradle-bridge/` folder and add a single Gradle project named
`shared-kit`.

The bridge should start as one umbrella KMP module, not a mirror of every Amper
module. That single module should compile from the existing source directories:

- `../shared-core/src`
- `../shared-core/src@ios`
- `../shared-feature-home/src`
- `../shared-ui-home/src`

Common tests can also point at:

- `../shared-core/test`
- `../shared-feature-home/test`

This design keeps the bridge simple:

- one framework name
- one Gradle entrypoint
- one set of iOS Kotlin targets
- one place to align Kotlin and Compose versions

The bridge should preserve the existing Swift import surface if possible. If the
current Swift code imports `KotlinModules`, the Gradle-built framework should
use the same base name to minimize app-side changes.

The important output of Stage 1 is the bridge structure itself:

- isolated ownership under `gradle-bridge/`
- one umbrella KMP module instead of a mirrored module graph
- direct source-set mapping to the existing shared Kotlin folders
- explicit version alignment through a shared catalog
- a checked-in Gradle wrapper so CI and local builds use the same bootstrap path

## Stage 2: Centralize temporary version alignment

Introduce a shared version catalog at:

- [`gradle/libs.versions.toml`](../../gradle/libs.versions.toml)

The purpose of this file is to reduce version drift between the Amper and
Gradle worlds.

At minimum, the catalog should capture:

- Kotlin version
- Compose Multiplatform version
- any shared Kotlin libraries that appear in both builds

This does not remove all duplication, but it gives the repository a single
version reference point for the temporary bridge period.

## Stage 3: Keep the Xcode project switchable

Do not replace the Amper Xcode build phase with a one-way Gradle change
immediately. Instead, make the build phase switchable through an environment
variable.

Recommended shape:

```sh
set -eu

if [ "${KOTLIN_IOS_BUILDER:-amper}" = "gradle" ]; then
  "${SRCROOT}/../gradle-bridge/gradlew" :shared-kit:embedAndSignAppleFrameworkForXcode
else
  "${AMPER_WRAPPER_PATH}" tool xcode-integration
fi
```

This gives the team three useful modes:

- Amper remains the default while the bridge is new
- individual developers can opt into the Gradle path locally
- CI can exercise the Gradle path before it becomes the normal iOS route

This switch is also the simplest rollback mechanism during the rollout.

In this repository, the Xcode project now supports exactly that switch through
the `KOTLIN_IOS_BUILDER` environment variable:

- `amper`: current default path
- `gradle`: temporary direct-integration bridge for iOS

When using the Gradle path, set `GRADLE_USER_HOME` to a writable cache such as
`$PWD/.gradle-user-home` in local development and CI.

The debug simulator path is already verified in this repository with:

```bash
KOTLIN_IOS_BUILDER=gradle \
GRADLE_USER_HOME="$PWD/.gradle-user-home" \
./scripts/ci/run_job.sh ios-build-debug
```

The unsigned release simulator path is also verified with:

```bash
KOTLIN_IOS_BUILDER=gradle \
GRADLE_USER_HOME="$PWD/.gradle-user-home" \
./scripts/ci/run_job.sh ios-build-release
```

The signed archive and IPA export path is also verified in this repository with
the Gradle bridge selected:

```bash
PATH=/opt/homebrew/opt/ruby/bin:$PATH \
KOTLIN_IOS_BUILDER=gradle \
IOS_BUNDLE_IDENTIFIER=studio.mekate.b3 \
IOS_DEVELOPMENT_TEAM=6GAE983XW9 \
IOS_PROVISIONING_PROFILE_SPECIFIER="b3 app store" \
bundle exec fastlane ios buildRelease
```

That command produced:

- `build/ios/ios-app.ipa`
- `build/ios/ios-app.app.dSYM.zip`

The remaining unverified step is `ios-testflight`, which still requires App
Store Connect API credentials to be available in the active shell or CI job.

The repository now defaults the Gradle bridge in two places:

- iOS jobs in GitHub Actions and GitLab CI
- the Fastlane `ios buildRelease` lane

This keeps the release path aligned with the bridge even when the shell has not
manually exported `KOTLIN_IOS_BUILDER=gradle`.

## Stage 4: Prove the bridge locally before touching CI

The first local success criteria should be narrow:

1. Gradle can build the iOS Kotlin framework.
2. Xcode can launch the iOS app with `KOTLIN_IOS_BUILDER=gradle`.
3. Swift code can still consume the same Kotlin APIs it consumed before.
4. The app can still fall back to the Amper path if the bridge fails.

Only after those four checks pass should the repository CI be updated.

This stage is important because CI makes debugging slower. A local green path
keeps early troubleshooting focused on one machine, one Xcode installation, and
one Gradle wrapper.

## Stage 5: Split CI by responsibility

When the local bridge works, update CI to reflect the new temporary ownership.

Recommended job split:

### 1. Android Amper job

This job remains unchanged in spirit. It should continue to run the Android app
and Android-facing shared code through Amper.

Typical commands:

```bash
./amper build -m android-app
./amper test -m shared-feature-home -p android
```

### 2. iOS Kotlin framework job

This job validates the bridge independently from app packaging.

Typical commands:

```bash
cd gradle-bridge
./gradlew :shared-kit:assemble
```

This catches Kotlin and Gradle bridge breakage before Xcode app assembly enters
the picture.

### 3. iOS Xcode app job

This job validates the native app and Swift packages using the Gradle bridge.

Typical expectations:

- resolve Swift packages
- build from `ios-app/module.xcodeproj`
- run with `KOTLIN_IOS_BUILDER=gradle`

This separation makes failures easier to reason about:

- if Android fails, the Amper path broke
- if the bridge fails, the Gradle KMP framework path broke
- if Xcode fails but the bridge passes, the native iOS app path broke

## Stage 6: Team workflow during the bridge period

During the bridge period, the team should follow a few explicit rules.

### Rule 1: Shared source changes are still made in the normal source folders

Nobody should edit a duplicated Kotlin source tree under the Gradle bridge.
That would immediately create drift and confusion.

### Rule 2: New shared Kotlin dependencies must be added in both places

If a new shared dependency is introduced, the author must update:

- the Amper module declarations
- the Gradle bridge module dependencies
- the version catalog when applicable

This is the main maintenance tax of the bridge.

### Rule 3: iOS package changes belong to Xcode, not the bridge

TCA and other Swift packages should be managed by the Xcode project. The Gradle
bridge is not the place to solve Swift package concerns.

### Rule 4: Android remains Amper-first

Do not let the bridge become a second Android path. The moment the bridge grows
Android responsibilities, the temporary design loses its value.

## Rollback plan

If the bridge proves too brittle, rollback should be fast.

### Rollback steps

1. Set `KOTLIN_IOS_BUILDER=amper` everywhere.
2. Remove the Gradle bridge job from CI.
3. Keep the documentation for historical context.
4. Leave the SwiftUI native shell in place.

If a full rollback is needed later:

1. restore the Xcode build phase to Amper-only
2. delete `gradle-bridge/`
3. delete any bridge-only CI steps
4. keep the shared Kotlin sources unchanged

Because the shared sources stay in their current folders, rollback should not
require code movement.

## Sunset criteria

The bridge should be removed when the Amper-driven iOS path is good enough for
the same workflow.

Suggested removal criteria:

- Xcode plus Amper can handle the needed Swift package setup reliably
- the iOS app can build in local development without the Gradle bridge
- the iOS CI path is green without the bridge
- the team no longer needs the Gradle direct integration workaround

At that point, removal should happen promptly. Temporary infrastructure becomes
expensive if it stays longer than the temporary problem.

## Known maintenance costs

The bridge is viable, but it is not free.

Expected costs:

- duplicate dependency declarations for shared Kotlin code
- duplicate Kotlin and Compose version alignment work
- extra CI job time and cache usage
- occasional debugging of environment-specific Gradle versus Amper differences
- manual care when adding new shared modules or moving source folders

This is acceptable if:

- the bridge stays small
- the bridge stays temporary
- the team treats it as a workaround with an exit plan

It becomes expensive if:

- more Gradle modules are added to mirror the Amper graph
- the bridge starts owning Android concerns
- version drift is allowed to accumulate

## Recommended implementation order

For this repository, the safest order is:

1. add the bridge skeleton and version catalog
2. get the framework building locally
3. make Xcode switchable between Amper and Gradle
4. verify the iOS app locally with the Gradle path
5. add dedicated CI jobs
6. flip the default builder only after repeated green runs
7. remove the bridge as soon as Amper can replace it cleanly

That sequence keeps every step reversible and keeps the highest-risk change,
the Xcode app path, late in the rollout.
