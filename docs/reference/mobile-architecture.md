# Mobile Architecture

This project currently uses an early split of the target structure:

- [`shared-core/`](../../shared-core): shared Kotlin domain and platform logic
- [`shared-feature-home/`](../../shared-feature-home): first shared feature
  contract and state module
- [`shared-di/`](../../shared-di): shared Metro graph and Kotlin
  composition-root helpers
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
- [ADR 0004: Metro owns shared Kotlin dependency injection](../adr/0004-metro-owns-shared-kotlin-dependency-injection.md)
- [ADR 0005: iOS uses TCA dependencies with a lightweight app composition root](../adr/0005-ios-uses-tca-dependencies-with-a-lightweight-app-composition-root.md)
- [ADR 0006: Shared feature state uses sealed value types and SKIE](../adr/0006-shared-async-feature-state-uses-sealed-loadable-and-skie.md)

For a practical implementation blueprint, see
[How To Add A Feature](./how-to-add-a-feature.md).

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
- Metro-backed shared Kotlin factories consumed from an Android composition
  root

Circuit should stay inside Android-facing presentation modules. Shared KMP
code can expose feature contracts and state, but not Circuit `Screen`,
`Presenter`, or `Ui` implementations.

The current Android home flow follows a Metro-backed `AndroidAppGraph` pattern:
the shared Metro graph owns shared feature factories, and the Android graph
owns Circuit-specific factories and the `Circuit` instance itself. Circuit
codegen is intentionally deferred for now; the official codegen docs focus on
Anvil, Hilt, and kotlin-inject-anvil flows, so this repo keeps Metro plus
Circuit on explicit factories until the Metro path is more clearly documented
for this toolchain.

### iOS

- SwiftUI for native UI
- TCA for reducers, stores, and navigation state
- Explicit dependency injection into stores and dependencies
- A small app composition root instead of a separate Swift DI container
- SKIE on the Gradle bridge for shared sealed-state ergonomics in Swift

Metro powers the shared Kotlin graph, but Swift should still depend on small
KMP facades or adapters instead of reaching into a Kotlin DI container
directly.

The app currently keeps that Swift boundary intentionally lightweight. The app
root owns an `AppServices` composition root that creates the shared
`HomeFeatureService` once, adapts it into TCA dependencies, and reuses the
same shared service for the optional shared Compose tab. That keeps iOS aligned
with native Swift patterns while avoiding overlapping DI systems between TCA
and a second Swift container. A library like Factory can still be a good fit if
the iOS-native service graph grows meaningfully, but it is not needed for the
current feature set.
The repo now enforces that direction more strictly: `DependencyValues` keys are
injection seams, not hidden fallback composition roots. Stores are expected to
be created through `AppServices`.

The current home flow follows this rule by using a native SwiftUI shell in
[`ios-app/src/`](../../ios-app/src) that consumes the shared Kotlin
`HomeFeatureService` rather than rendering the shared Compose route as the
main app root.

The home flow now uses that next step: a native TCA reducer and store in
[`ios-app/src/Features/Home/`](../../ios-app/src/Features/Home) that adapt the
shared Kotlin `HomeFeatureService` and its sealed async state into SwiftUI
state.

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
SKIE is enabled on the Gradle bridge specifically for sealed hierarchy
ergonomics, while SKIE coroutine and Flow interop are currently disabled. This
repo still uses the standard Kotlin suspend bridge for async calls and only
leans on SKIE for the shared sealed-state experience.

### Shared

- Kotlin Multiplatform for domain, data, and feature workflows
- Compose Multiplatform for reusable UI where it earns its place
- Metro for compile-time shared dependency injection

## Current home data flow

The current home feature is intentionally small, but it already follows the
target contract and now includes an asynchronous shared data source:

```text
shared-di.SharedApplicationGraph
  -> shared-core.CounterRepository
  -> shared-feature-home.HomeFeatureService
  -> android Circuit presenter / iOS TCA dependency client / shared Compose route
  -> Android Compose UI / SwiftUI / SharedHomeScreen
```

Concretely:

- [`shared-core/src/CounterRepository.kt`](../../shared-core/src/CounterRepository.kt)
  exposes an asynchronous shared repository contract and a fake implementation
  that simulates a web API delay before returning the next fibonacci counter
  value or randomly throwing a fake repository error.
- [`shared-feature-home/src/CounterLoadable.kt`](../../shared-feature-home/src/CounterLoadable.kt)
  models the feature's async lifecycle as explicit sealed states: initial,
  loading, loaded, and error.
- [`shared-feature-home/src/HomeFeatureService.kt`](../../shared-feature-home/src/HomeFeatureService.kt)
  is the shared feature-level async seam that coordinates repository work and
  produces sealed async feature state for all platform shells while also
  normalizing repository failures into a shared error contract.
- [`shared-di/src/SharedDependencies.kt`](../../shared-di/src/SharedDependencies.kt)
  owns the Metro graph and shared Kotlin composition-root helpers.
- [`android-app/src/MainActivity.kt`](../../android-app/src/MainActivity.kt)
  stays small and delegates to Android composition-root wiring.
- [`android-app/src/AndroidAppGraph.kt`](../../android-app/src/AndroidAppGraph.kt)
  owns the Android Metro graph, Circuit instance, and Circuit-specific
  factories.
- [`android-app/src/home/`](../../android-app/src/home)
  contains split Circuit screen, presenter, and UI files for the home feature.
- [`android-app/src/AppShell.kt`](../../android-app/src/AppShell.kt)
  composes the shared graph and Android graph, then routes between the native
  and shared Compose demos.
- [`ios-app/src/AppServices.swift`](../../ios-app/src/AppServices.swift)
  creates the native iOS composition root and injects shared Kotlin factories
  into TCA and shared Compose wrappers.
- [`ios-app/src/Features/Home/HomeFeatureClient.swift`](../../ios-app/src/Features/Home/HomeFeatureClient.swift)
  adapts the shared feature service into TCA dependencies.
- [`ios-app/src/Features/Home/HomeCounterLoadable.swift`](../../ios-app/src/Features/Home/HomeCounterLoadable.swift)
  maps the shared Kotlin sealed async state into a native Swift enum for TCA
  and SwiftUI rendering.
- [`ios-app/src/Features/Home/SharedHomeDemoView.swift`](../../ios-app/src/Features/Home/SharedHomeDemoView.swift)
  embeds the shared Compose entry point in a SwiftUI tab.
- [`shared-ui-home/src/HomeContent.kt`](../../shared-ui-home/src/HomeContent.kt)
  exposes `SharedHomeScreen` for the optional shared Compose rendering path.
- [`shared-ui-home/src@ios/ViewController.kt`](../../shared-ui-home/src@ios/ViewController.kt)
  exports an iOS view-controller factory for that shared Compose screen.

## Current nearby vehicle map flow

The nearby vehicle map feature is the first map-centric product slice. It keeps
the map SDK decision deliberately lightweight: Android and iOS render native
coordinate maps from shared latitude/longitude state instead of depending on a
third-party map SDK or API key.

```text
shared-di.SharedApplicationGraph
  -> shared-core.NearbyFleetRepository
  -> shared-feature-nearby-vehicle-map.NearbyVehicleMapFeatureService
  -> android Circuit presenter / iOS TCA dependency client
  -> Android Compose Canvas / SwiftUI Canvas
```

Concretely:

- [`shared-core/src/NearbyVehicleModels.kt`](../../shared-core/src/NearbyVehicleModels.kt)
  defines rider location, vehicle identity, vehicle location, nearby vehicle,
  and fleet snapshot domain types.
- [`shared-core/src/NearbyFleetRepository.kt`](../../shared-core/src/NearbyFleetRepository.kt)
  exposes a simulated rider-centered repository that can return empty,
  changing, or failed snapshots while preserving stable vehicle identities.
- [`shared-feature-nearby-vehicle-map/src/NearbyVehicleMapFeatureService.kt`](../../shared-feature-nearby-vehicle-map/src/NearbyVehicleMapFeatureService.kt)
  owns rider-location transitions, snapshot refresh, stale-window, and overlay
  rules.
- [`android-app/src/nearbyvehiclemap/`](../../android-app/src/nearbyvehiclemap)
  adapts the shared feature state into Circuit and renders a functional
  rider-centered coordinate map in Compose.
- [`ios-app/src/Features/NearbyVehicleMap/`](../../ios-app/src/Features/NearbyVehicleMap)
  adapts the shared feature state into TCA and renders the same product state
  with SwiftUI.

This is intentionally a product-state map rather than a vendor map integration.
It proves the shared behavior, permission handoff, refresh cadence, stale
overlay, and marker rendering seams while keeping public setup runnable from a
clean clone.

## Testing bootstrap

The current testing foundation focuses on state transitions at the native
presentation seams and the shared async workflow.

- Android keeps Circuit presentation logic testable through
  [`android-app/src/home/HomePresenterStateProducer.kt`](../../android-app/src/home/HomePresenterStateProducer.kt).
  The presenter delegates state creation and event transitions to that small
  seam, and
  [`android-app/test/home/HomePresenterStateProducerTest.kt`](../../android-app/test/home/HomePresenterStateProducerTest.kt)
  verifies the shared-state-to-presenter-state mapping plus the async refresh
  transition.
- The nearby vehicle map follows the same native-shell testing shape:
  [`android-app/test/nearbyvehiclemap/NearbyVehicleMapPresenterStateProducerTest.kt`](../../android-app/test/nearbyvehiclemap/NearbyVehicleMapPresenterStateProducerTest.kt)
  covers Android permission, refresh, and overlay presentation seams, while
  [`ios-app/tests/Features/NearbyVehicleMap/NearbyVehicleMapFeatureTests.swift`](../../ios-app/tests/Features/NearbyVehicleMap/NearbyVehicleMapFeatureTests.swift)
  verifies the iOS TCA reducer transitions for permission, refresh, stale
  overlay, and temporary location degradation.
- Shared repositories and feature services are tested directly in Kotlin.
  [`shared-core/test/FakeCounterRepositoryTest.kt`](../../shared-core/test/FakeCounterRepositoryTest.kt)
  verifies the fake async repository contract, and
  [`shared-feature-home/test/HomeFeatureServiceTest.kt`](../../shared-feature-home/test/HomeFeatureServiceTest.kt)
  verifies that feature-level initial, loading, loaded, and error states are
  produced from that repository.
- iOS keeps TCA state transitions testable through
  [`ios-app/tests/Features/Home/HomeFeatureTests.swift`](../../ios-app/tests/Features/Home/HomeFeatureTests.swift).
  Those tests use `TestStore` against the real reducer while stubbing the
  `HomeFeatureClient` dependency, so reducer behavior is verified without
  needing the full Kotlin bridge at test time.

This gives both platforms a stable bootstrap for feature-state tests today
while leaving room to add deeper UI, navigation, and integration tests later.

## Dependency rules

The key rule is that dependencies point inward toward shared business logic.

```text
android-app -> android feature/presentation -> shared-di -> shared feature -> shared core
ios-app     -> ios feature/presentation     -> shared-di bridge helpers -> shared feature -> shared core
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

shared-di/
  Metro graphs
  shared composition roots

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

Use Metro as the shared DI solution for Kotlin code.

Recommended DI ownership:

- shared modules define injectable constructors and shared graphs
- `shared-di` owns graph creation and graph-facing helper functions
- Android requests shared feature factories from `shared-di` in app startup and
  screen composition
- iOS receives shared dependencies through explicit factories or bridge types

Recommended iOS bridge pattern:

- define a small Kotlin `AppGraph` or `FeatureGraph`
- expose feature factories needed by Swift through tiny Kotlin bridge helpers
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
- [`shared-di/`](../../shared-di)
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
- Make iOS dependencies explicit even when backed by Metro on the Kotlin side.

## Practical rule of thumb

When deciding where new code belongs:

- if it changes what the app means, it probably belongs in shared KMP
- if it changes how Android presents the feature, it belongs in Circuit modules
- if it changes how iOS presents the feature, it belongs in TCA/SwiftUI modules
- if it is identical enough on both platforms to stay pleasant to maintain, it
  can live in shared Compose UI
