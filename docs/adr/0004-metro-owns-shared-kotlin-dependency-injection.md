# ADR 0004: Metro owns shared Kotlin dependency injection

- Status: Accepted
- Date: 2026-04-03

## Context

The project needed a shared DI foundation that:

- stays compile-time validated
- works in Kotlin Multiplatform shared code
- can feed Android, iOS, and shared Compose entry points from the same graph
- remains easy to override in tests
- does not force Swift code to reach into a cross-language service locator

The earlier code path created `PlatformContextProvider` and
`HomeFeatureStateFactory` directly at call sites. That was enough to bootstrap
the first feature, but it did not establish a reusable graph or a repeatable
composition-root pattern.

## Decision

The project uses Metro for shared Kotlin dependency injection.

- `shared-core` and `shared-feature-*` use Metro constructor injection.
- `shared-di` owns Metro dependency graphs and shared composition-root helpers.
- Android and shared Compose entry points request shared feature factories from
  `shared-di` instead of constructing them manually.
- iOS stays explicit: Swift consumes small Kotlin bridge factories produced by
  `shared-di`, then injects those into TCA dependencies and native wrappers.

## Current home flow

```text
PlatformNameProvider
  -> SharedApplicationGraph
  -> PlatformContextProvider
  -> HomeFeatureStateFactory
  -> Android Circuit / iOS TCA / shared Compose adapters
```

## Consequences

- shared Kotlin wiring is validated at compile time
- tests can override graph inputs without changing production constructors
- native composition roots stay visible and platform-appropriate
- Swift depends on small bridge types rather than a Kotlin service locator
