## Why

The isolated Swift export route can compile and run Mobi's shared Home, Nearby and Compose behavior, but its assessment scripts do not provide a reproducible, maintained integration for architecture readers. A repository-owned candidate needs explicit generated-package, native ownership and diagnostic contracts before it can be considered for adoption.

## What Changes

- Introduce an opt-in maintenance candidate that describes, generates, publishes and replays a complete source/archive export package from declared inputs in owned workspaces.
- Support two explicitly named language profiles: compiled Swift 5 coroutine support with the other generated modules in Swift 6, and all generated modules in Swift 5; aliases and native consumers remain in Swift 6.
- Define one locked local writer with generation fencing, pinned readers and conservative reader-aware collection of immutable package objects.
- Require closed facade admission, stable versioned wire tags, separately owned cancellation drains and declared repository access/route lifetime policies before app integration.
- Keep unknown diagnostics visible and require tuple-specific review of coroutine inheritance, generated casts/target features and runtime presentation findings.
- Separate isolated candidate construction from production adoption, app/default changes and platform/release qualification.

## Capabilities

### New Capabilities

- `maintained-swift-export-candidate`: Explicit opt-in generation, package publication/replay and review gates for a repository-owned Swift export candidate.

### Modified Capabilities

None. The existing direct development and release contracts remain the baseline.

## Impact

Proposed implementation areas are `scripts/maintenance/`, a reviewed exporter input/profile descriptor, transport adapters, isolated native consumer fixtures and a focused architecture/maintenance guide. Future app wiring belongs to a separately reviewed adoption patch. CI orchestration stays in repository scripts; workflows remain thin. The retired hand-maintained iOS Gradle bridge stays retired, delegated Android Gradle/AGP bootstrap remains, and public identity remains `studio.mekate.mobi`.

This is a review proposal. No profile, repository policy, runtime limit, accountable maintainer or warning risk is selected by artifact completion. Kotlin Swift export is [documented as Alpha](https://kotlinlang.org/docs/native-swift-export.html), and the documented Xcode setup uses a Gradle task. The custom producer is a repository-owned compatibility responsibility; no supported Gradle-free upstream integration is claimed.
