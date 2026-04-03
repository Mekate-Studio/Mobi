# Architecture Decision Records

This directory captures the decisions that shape the current mobile setup so
they stay easy to reference, revisit, and reproduce.

Current ADRs:

- [ADR 0001: Native shells with shared feature state](0001-native-shells-with-shared-feature-state.md)
- [ADR 0002: Shared Compose entry points live in feature UI modules](0002-shared-compose-entry-points-live-in-feature-ui-modules.md)
- [ADR 0003: Xcode owns Swift packages and Gradle builds Kotlin for iOS](0003-xcode-owns-swift-packages-and-gradle-builds-kotlin-for-ios.md)
- [ADR 0004: Metro owns shared Kotlin dependency injection](0004-metro-owns-shared-kotlin-dependency-injection.md)

Use a new ADR when a decision changes one of these:

- module boundaries
- data flow across shared and native layers
- platform build ownership
- dependency injection strategy
- long-lived presentation architecture choices
