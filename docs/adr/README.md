# Architecture Decision Records

This directory captures the decisions that shape the current mobile setup so
they stay easy to reference, revisit, and reproduce.

Current ADRs:

- [ADR 0001: Native shells with shared feature state](0001-native-shells-with-shared-feature-state.md)
- [ADR 0002: Shared Compose entry points live in feature UI modules](0002-shared-compose-entry-points-live-in-feature-ui-modules.md)
- [ADR 0003: Xcode owns Swift packages and Gradle builds Kotlin for iOS](0003-xcode-owns-swift-packages-and-gradle-builds-kotlin-for-ios.md)
- [ADR 0004: Metro owns shared Kotlin dependency injection](0004-metro-owns-shared-kotlin-dependency-injection.md)
- [ADR 0005: iOS uses TCA dependencies with a lightweight app composition root](0005-ios-uses-tca-dependencies-with-a-lightweight-app-composition-root.md)
- [ADR 0006: Shared feature state uses sealed value types and SKIE](0006-shared-async-feature-state-uses-sealed-loadable-and-skie.md)

- [ADR 0010: Android Home ready state across native tab switches](0010-android-home-tab-state-lifetime.md)

- [ADR 0011: Android Nearby state across native tab switches](0011-android-nearby-tab-state-lifetime.md)

- [ADR 0012: iOS Nearby location revalidation on view entry](0012-ios-nearby-location-revalidation.md)

Proposed, without changing the accepted decisions:

- [ADR 0007: Direct iOS transition requires measured capability evidence](0007-direct-ios-transition-requires-capability-evidence.md)
- [ADR 0008: Explicit iOS projections and direct development builds](0008-explicit-ios-projections-and-direct-development-builds.md)
- [ADR 0009: Generated Swift export for native features](0009-generated-swift-export-for-native-features.md)

- [ADR 0013: Android Home request ownership while the host is visible](0013-android-home-visible-work-lifetime.md)

Use a new ADR when a decision changes one of these:

- module boundaries
- data flow across shared and native layers
- platform build ownership
- dependency injection strategy
- long-lived presentation architecture choices
