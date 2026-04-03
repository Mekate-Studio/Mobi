# ADR 0001: Native shells with shared feature state

- Status: Accepted
- Date: 2026-04-03

## Context

The app needs:

- shared Kotlin business logic that both platforms can trust
- first-class Android and iOS presentation layers
- the option to reuse Compose UI without forcing it to own the whole app shell

The initial starter shape mixed a small shared greeting demo with a shared UI
wrapper module. That was useful for bootstrapping, but it blurred the actual
target architecture.

## Decision

The app uses native presentation shells with shared feature state:

- `shared-core` owns platform-agnostic primitives and cross-platform inputs
- `shared-di` owns shared dependency graphs and composition-root helpers
- `shared-feature-*` modules own feature state factories, events, and reducers
- Android adapts shared feature state through Circuit presenters and screens
- iOS adapts shared feature state through TCA dependencies, reducers, and
  SwiftUI views
- shared Compose UI is optional and consumes the same shared feature contract

Shared modules must not expose Circuit or TCA types.

## Data flow

```text
shared-core -> shared-feature-home -> platform adapters -> platform UI
```

Current home feature flow:

```text
PlatformNameProvider
  -> SharedApplicationGraph
  -> PlatformContextProvider
  -> HomeFeatureStateFactory
  -> HomePresenter / HomeFeatureClient / SharedHomeScreen
  -> Android Compose UI / SwiftUI / shared Compose UI
```

## Consequences

- feature behavior stays in shared Kotlin
- navigation and presentation stay native
- shared state remains durable feature truth, not final platform UI state
- the same shared feature can back native UI and shared Compose UI
- new features should follow the same contract before adding platform-specific
  embellishments
