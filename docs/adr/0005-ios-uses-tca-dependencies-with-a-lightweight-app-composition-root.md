# ADR 0005: iOS uses TCA dependencies with a lightweight app composition root

- Status: Accepted
- Date: 2026-04-03

## Context

The project now has:

- Metro as the shared Kotlin dependency injection system
- TCA as the iOS presentation architecture
- small Kotlin bridge types like `HomeFeatureStateFactory` that Swift can
  consume directly

The first iOS pass introduced an `AppDependencies` object to hold shared
factories and native adapters. That worked, but it felt closer to a cross-stack
service graph than to a conventional Swift composition root.

At the same time, TCA already provides a first-class dependency mechanism for
feature code. Adding a second Swift DI system at the feature layer would create
overlapping patterns:

- one system for app-level composition
- another system for TCA feature dependencies

## Decision

The iOS app uses a lightweight app composition root plus TCA dependencies.

- `AppServices` is the native iOS composition root.
- `AppServices` creates shared Kotlin bridge factories once at the app root.
- TCA feature reducers consume those bridges through `DependencyValues`.
- Shared Compose wrappers on iOS reuse the same bridge objects from
  `AppServices`.

The project does not add Factory at this stage.

Factory remains a valid future option if the iOS-native service graph grows far
beyond the current feature set, but it is not the default path while TCA
already covers feature-level injection cleanly.

## Consequences

- iOS keeps a more idiomatic Swift shape at the app root
- TCA stays the single dependency story inside feature reducers
- shared Kotlin dependencies are still created once and reused consistently
- the repo avoids mixing TCA dependency injection with a second Swift container
  before the complexity justifies it
