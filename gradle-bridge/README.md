# Gradle Bridge

This folder contains the temporary Gradle bridge used to build the Kotlin
framework consumed by the iOS app.

It exists to support a traditional Xcode plus Swift Package Manager iOS flow
without moving Android off Amper.

## Ownership

This bridge should own only:

- the Kotlin framework consumed by Xcode
- iOS-facing Kotlin compiler configuration
- the Gradle direct integration task used by Xcode

This bridge should not own:

- Android application builds
- Android packaging or testing
- Swift Package Manager dependencies
- iOS application signing or distribution

## Current status

The bridge skeleton and Gradle wrapper are checked in so the repository
structure, source-set mapping, and dependency boundaries are visible in review
and usable in automation.

Verified so far:

1. `:shared-kit:assemble`
2. `bridgeDoctor`

The next bootstrap step is to wire Xcode to the bridge through a switchable
build phase, then verify:

1. `:shared-kit:embedAndSignAppleFrameworkForXcode`
2. iOS app builds from Xcode with `KOTLIN_IOS_BUILDER=gradle`

## Source ownership

`shared-kit` compiles directly from the existing shared source folders:

- [`../shared-core`](../shared-core)
- [`../shared-feature-home`](../shared-feature-home)
- [`../shared-ui-home`](../shared-ui-home)

Do not create a second Kotlin source tree under this folder.
