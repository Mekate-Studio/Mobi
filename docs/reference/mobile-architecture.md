# Mobile Architecture

This project currently uses an early split of the target structure:

- [`shared-core/`](../../shared-core): shared Kotlin domain and platform logic
- [`shared-feature-home/`](../../shared-feature-home): first shared feature
  contract and state module
- [`shared-ui-home/`](../../shared-ui-home): reusable Compose Multiplatform
  UI for the home feature, including the optional `SharedHomeScreen` entry
  point
- [`android-app/`](../../android-app): Android app host
- [`ios-app/`](../../ios-app): iOS app host

The target architecture keeps that simple base, but grows it into a
native-first app shell with shared business logic and selective shared UI.

The key architecture decisions are also captured in ADRs:

- [ADR 0001: Native shells with shared feature state](../adr/0001-native-shells-with-shared-feature-state.md)
- [ADR 0002: Shared Compose entry points live in feature UI modules](../adr/0002-shared-compose-entry-points-live-in-feature-ui-modules.md)
- [ADR 0003: Xcode owns Swift packages while the Gradle bridge builds Kotlin for iOS](../adr/0003-xcode-owns-swift-packages-and-gradle-builds-kotlin-for-ios.md)

## Goals

- Keep Kotlin Multiplatform as the source of truth for domain, data, and
  feature workflows.
- Keep Android and iOS presentation architecture native and first-class.
- Use Compose Multiplatform where shared UI materially reduces duplication.
- Preserve the ability to build richer platform-specific experiences in
  Jetpack Compose and SwiftUI without fighting the shared layer.

## Architecture summary

The app is split into three cooperating layers:

### 1. Shared KMP core

This layer owns:

- domain models
- repository interfaces and implementations
- persistence and networking
- use cases
- cross-platform business rules
- feature-level state producers and mappers

This is the long-lived source of truth for app behavior.

### 2. Native presentation shells

Each platform keeps its own presentation architecture:

- Android/Compose uses Slack Circuit
- iOS/SwiftUI uses The Composable Architecture (TCA)

These layers own:

- screen composition
- platform navigation
- presentation-specific reducers/presenters
- lifecycle integration
- platform services and permissions

Shared code should not expose Circuit or TCA types.

### 3. Optional shared Compose UI

Compose Multiplatform UI is available as a reusable feature layer, not a
mandatory rendering path for the whole application.

Use shared Compose UI when:

- the feature is visually similar on both platforms
- the shared UI is cheaper to maintain than two native views
- platform-native navigation and app shell still remain in control

Use native UI when:

- the feature needs strong platform idioms
- the interaction model differs by platform
- the screen is part of the platform shell or navigation chrome

## Platform stack

### Android

- Jetpack Compose for Android UI
- Slack Circuit for screen routing, presenters, and UI composition
- Koin for dependency injection

Circuit should stay inside Android-facing presentation modules. Shared KMP
code can expose feature contracts and state, but not Circuit `Screen`,
`Presenter`, or `Ui` implementations.

### iOS

- SwiftUI for native UI
- TCA for reducers, stores, and navigation state
- Explicit dependency injection into stores and dependencies

Koin may power the shared Kotlin graph, but Swift should depend on small KMP
facades or adapters instead of reaching deeply into a Kotlin DI container.

The current home flow follows this rule by using a native SwiftUI shell in
[`ios-app/src/`](../../ios-app/src) that consumes the shared Kotlin
`HomeFeatureStateFactory` rather than rendering the shared Compose route as the
main app root.

The home flow now uses that next step: a native TCA reducer and store in
[`ios-app/src/Features/Home/`](../../ios-app/src/Features/Home) that adapt the
shared Kotlin `HomeFeatureStateFactory` into SwiftUI state.

One implementation detail matters for automation: Xcode GUI builds work with
the current TCA package setup, and the CLI path is stable when two conditions
are met:

- `SWIFT_ENABLE_EXPLICIT_MODULES=NO` is passed to `xcodebuild`
- the CLI build does not force `-sdk iphonesimulator`, `ONLY_ACTIVE_ARCH`, or
  `ARCHS`

Those simulator-specific overrides caused TCA's macro executables to be built
under `Debug-iphonesimulator` instead of the macOS host products directory,
which broke `@Reducer` and `@ObservableState` expansion from the CLI. The
repo's iOS CI and Fastlane entrypoints therefore disable explicit Swift modules
by default while also letting Xcode choose the simulator architectures itself.
There is one tooling split to keep in mind: the low-level CI wrapper uses the
workspace path for raw `xcodebuild`, while Fastlane archives against the plain
`.xcodeproj` because Fastlane's Xcodeproj-based scheme discovery does not
reliably detect shared schemes from the nested workspace path in this repo.

### Shared

- Kotlin Multiplatform for domain, data, and feature workflows
- Compose Multiplatform for reusable UI where it earns its place
- Koin with compiler-plugin-based configuration for shared dependency wiring

## Current home data flow

The current home feature is intentionally small, but it already follows the
target contract:

```text
shared-core.PlatformContextProvider
  -> shared-feature-home.HomeFeatureStateFactory
  -> android Circuit presenter / iOS TCA dependency client / shared Compose route
  -> Android Compose UI / SwiftUI / SharedHomeScreen
```

Concretely:

- [`shared-core/src/PlatformContext.kt`](../../shared-core/src/PlatformContext.kt)
  exposes platform context as a shared input primitive.
- [`shared-feature-home/src/HomeFeature.kt`](../../shared-feature-home/src/HomeFeature.kt)
  turns that core input into feature state and a small shared reducer.
- [`android-app/src/MainActivity.kt`](../../android-app/src/MainActivity.kt)
  adapts the shared feature state into a Circuit screen.
- [`ios-app/src/Features/Home/HomeFeatureClient.swift`](../../ios-app/src/Features/Home/HomeFeatureClient.swift)
  adapts the shared feature factory into TCA dependencies.
- [`shared-ui-home/src/HomeContent.kt`](../../shared-ui-home/src/HomeContent.kt)
  exposes `SharedHomeScreen` for the optional shared Compose rendering path.

## Dependency rules

The key rule is that dependencies point inward toward shared business logic.

```text
android-app -> android feature/presentation -> shared feature -> shared core
ios-app     -> ios feature/presentation     -> shared feature -> shared core
shared compose ui -------------------------> shared feature -> shared core
```

Allowed:

- native presentation modules depend on shared feature and shared core modules
- shared Compose UI depends on shared feature and shared core modules
- platform app modules depend on their own native presentation modules

Not allowed:

- shared modules depending on Android or iOS presentation frameworks
- shared modules depending on Circuit or TCA
- iOS modules depending on Android modules, or vice versa
- native shells depending on shared UI for app-wide navigation or root chrome

## Recommended target module map

This repository can grow toward the following layout over time:

```text
shared-core/
  model/
  util/

shared-domain/
  usecase/
  repository/

shared-data/
  local/
  remote/
  repository/

shared-feature-home/
  contract/
  workflow/
  mapper/

shared-ui-home/
  Compose Multiplatform UI for reusable feature screens

android-app/
android-core/
android-feature-home/

ios-app/
ios-native/
ios-feature-home/
```

The exact folder names can stay flexible, but the separation of concerns should
remain stable.

## Feature slice contract

Each feature should have a shared contract that native and shared UI can both
consume.

Recommended shared feature responsibilities:

- feature input and output models
- business events and intents
- long-lived state production
- use case orchestration
- mapping domain models into feature-friendly state

Recommended native presentation responsibilities:

- view state derived for a specific platform
- transient UI behavior
- platform navigation actions
- platform effects such as alerts, sheets, permissions, haptics, and deep links

This means the shared layer can say "the user submitted a note" or "loading
failed", while Android and iOS decide how that is rendered and navigated.

## State management model

Treat shared state as app logic state, not final UI state.

### Shared KMP state

Shared state should model durable feature truth:

- loaded data
- domain validation
- loading and refresh status
- business errors
- feature workflows

### Android state

Circuit presenters adapt shared feature state into Compose-facing UI state and
drive platform navigation through Circuit navigators.

### iOS state

TCA reducers adapt shared feature state into SwiftUI-facing state and drive
platform navigation through TCA state and actions.

This avoids making SwiftUI and Compose conform to the same final state model
when the platforms naturally differ.

## Dependency injection

Use Koin as the shared DI solution for Kotlin code with the compiler-plugin
approach enabled.

Recommended DI ownership:

- shared modules define and register shared services
- Android uses Koin directly in app startup and feature wiring
- iOS receives shared dependencies through explicit factories or bridge types

Recommended iOS bridge pattern:

- define a small Kotlin `AppGraph` or `FeatureGraph`
- expose feature factories needed by Swift
- inject those factories into TCA dependencies or store initializers

This keeps Swift code testable and avoids hiding dependencies behind a
cross-language service locator.

## Navigation strategy

Navigation should remain native.

### Android

- Circuit back stack and navigator own Android navigation
- shared modules emit intents or outputs, not navigation framework objects

### iOS

- TCA owns navigation path, destinations, sheets, and alerts
- shared modules emit intents or outputs, not Swift navigation types

### Shared Compose screens

Shared Compose screens should be hosted inside native navigation shells rather
than replacing the shell itself.

## UI strategy

Use a tiered UI approach:

### Tier 1: Native shell

Always native:

- app startup
- root tabs
- root navigation
- modal presentation policies
- platform settings and permission flows

### Tier 2: Shared feature UI

Shared when beneficial:

- forms
- feeds
- detail screens
- settings sections
- reusable design-system-driven surfaces

### Tier 3: Native specialization

Native when the platform experience matters:

- platform-rich animations
- Apple- or Android-specific interaction patterns
- widgets, live activities, shortcuts, app clips, watch features, and similar

## Migration plan for this repo

The current repository already contains the first shared split:

- [`shared-core/`](../../shared-core)
- [`shared-feature-home/`](../../shared-feature-home)
- [`shared-ui-home/`](../../shared-ui-home)

The recommended implementation order is:

1. Expand `shared-core` into domain, data, and dependency wiring modules as
   the app grows.
2. Add more `shared-feature-*` modules with explicit feature contracts and
   state producers.
3. Add Android presentation wiring with Circuit around each feature.
4. Add iOS presentation wiring with TCA around the same feature contracts.
5. Keep shared Compose UI only where the reuse remains clearly worth it.

For the temporary case where iOS needs a traditional Xcode plus Gradle bridge
before the Amper iOS path is ready, use the dedicated rollout guide:

- [iOS Gradle Bridge Migration](ios-gradle-bridge.md)

## Default engineering rules

- Prefer shared business logic over duplicated business logic.
- Prefer native presentation over forced cross-platform presentation.
- Prefer shared Compose for leaf features before using it for the whole app.
- Keep framework types at the edges.
- Keep feature contracts small and explicit.
- Make iOS dependencies explicit even when backed by Koin on the Kotlin side.

## Practical rule of thumb

When deciding where new code belongs:

- if it changes what the app means, it probably belongs in shared KMP
- if it changes how Android presents the feature, it belongs in Circuit modules
- if it changes how iOS presents the feature, it belongs in TCA/SwiftUI modules
- if it is identical enough on both platforms to stay pleasant to maintain, it
  can live in shared Compose UI
