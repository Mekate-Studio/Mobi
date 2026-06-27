# ADR 0003: Xcode owns Swift packages and Gradle builds Kotlin for iOS

- Status: Accepted
- Date: 2026-04-03

## Context

The iOS app needs native Swift dependencies such as TCA, while the shared
Kotlin code still needs to be built into an iOS-consumable framework.

Kotlin Toolchain remains the main project build system, but the current iOS
path still uses a temporary Gradle bridge because that path is the one that
works reliably with Swift Package Manager, the native Xcode app build, the
checked-in app/test target shape, and SKIE-backed sealed-state Swift
ergonomics.

## Decision

The iOS toolchain is split this way:

- `ios-app/Dependencies/Package.swift` owns direct Swift Package Manager
  declarations such as TCA, Point-Free Dependencies, and MapLibre
- Xcode consumes those dependencies through the local `MobiIOSDependencies`
  package product
- the Gradle bridge builds the `KotlinModules` framework for iOS
- Fastlane and CI default to `KOTLIN_IOS_BUILDER=gradle`
- the repo tracks the shared Swift package lockfile at
  `ios-app/module.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
  so package resolution stays reproducible in CI

## Consequences

- iOS can adopt native Swift ecosystem tools while Kotlin Toolchain's direct
  iOS app integration matures for this repository's target shape
- Renovate can extract native iOS dependencies from a standard `Package.swift`
  instead of attempting to parse Xcode project internals
- the local package target only re-exports vendor modules; it does not own app
  behavior, dependency composition, or platform architecture
- archive and TestFlight flows follow the same Kotlin framework path used in CI
- the Gradle bridge stays intentionally temporary and narrowly scoped
- when Kotlin Toolchain can own the iOS Swift package path, app/test Xcode
  target shape, and sealed-state interop cleanly, this decision can be
  revisited and the bridge can be removed
