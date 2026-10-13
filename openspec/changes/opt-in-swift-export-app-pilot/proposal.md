## Why

The maintained Swift export candidate has completed 28/28 tasks with four locally qualified profile/policy combinations, but the shipping app still uses direct projections. A separate opt-in real-app pilot can evaluate architecture, lifetimes and operational costs without selecting production defaults.

## What Changes

- Add an alternate app configuration and explicit repo-owned build/test command for real Native Home and Nearby Map, with optional Shared UI.
- Recommend `coroutine-swift5` with `main-confined` for initial pilot review; preserve `generated-swift5`, `shared-operation-mutex` and compiled Swift 5 support consumed from Swift 6 as alternatives.
- Promote reusable facade, transport and lifetime code from rehearsal fixtures into maintained app-facing sources; keep scripted scenarios and injected failures in test fixtures.
- Use one Kotlin delivery and composition root per app configuration, audit every caller of the exact repository cohort, and measure runtime limits before accepting pilot settings.
- Require explicit diagnostic dispositions, source-bound integrated qualification and a fresh complete rollback snapshot containing the approved macro repair.
- Keep hosted, published clean clone, device, minimum runtime, Android, advisory and signed-release evidence independent.

## Capabilities

### New Capabilities

- `swift-export-app-pilot`: Opt-in real-app composition, build isolation, measured lifetime/concurrency contracts and reviewable qualification/rollback.

### Modified Capabilities

None. Existing Home and Nearby behavior contracts remain; the pilot changes their delivery and native integration.

## Impact

Expected areas: `ios-app/` alternate project configuration, shared iOS-facing facade sources, `scripts/maintenance/` producer inputs, `scripts/ci/` dispatcher adapter, app tests and maintenance documentation. Jorge Castro remains accountable for exporter/compiler coupling and recovery. SwiftSyntax 603.0.2, Perception 2.0.10 and the matching Xcode constraint are approved/applied inputs, not new dependency selections.

The current uncommitted implementation and ignored evidence remain intact. This proposal does not implement a production switch, commit, push, sign, create a scheduler or archive any change. Public identity stays `studio.mekate.mobi`, CI stays thin, Android delegated Toolchain Gradle/AGP bootstrap remains and the retired iOS Gradle bridge stays retired.
