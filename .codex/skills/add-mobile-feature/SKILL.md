---
name: add-mobile-feature
description: Use when adding, scaffolding, refactoring, or reviewing a feature in this mobile KMP reference architecture so the work follows the repo blueprint across shared-core, shared-feature-*, shared-ui-*, Android Circuit, iOS TCA, Metro DI, and tests. Trigger on requests like "add a feature", "scaffold a new feature", "follow the home pattern", "wire a new shared feature", or "port this feature structure to another module".
---

# Add Mobile Feature

Use this skill when the task is to add or reshape a feature so it follows this
repo's native-first shell plus shared-business-logic architecture.

This skill is intentionally lean. The canonical blueprint lives in
[`docs/reference/how-to-add-a-feature.md`](/Users/pragmatickeoz/StudioProjects/Mobi/docs/reference/how-to-add-a-feature.md).
Read that file first.

Read
[`docs/reference/mobile-architecture.md`](/Users/pragmatickeoz/StudioProjects/Mobi/docs/reference/mobile-architecture.md)
only when the task changes architecture, not when it just applies the
existing pattern.

## What this skill is for

- adding a new feature that should follow the `home` blueprint
- splitting feature work across `shared-core`, `shared-feature-*`,
  `shared-ui-*`, `android-app`, and `ios-app`
- checking whether code landed in the right ownership layer
- scaffolding tests for shared behavior, Android presentation, and iOS reducer
  state transitions
- reviewing feature work for architecture drift

## What this skill is not for

- tiny single-file fixes that do not affect feature boundaries
- platform-only tasks that do not need the shared blueprint

## Default workflow

1. Read the feature blueprint doc.
2. Identify the feature's ownership split:
   shared business logic, Android presentation, iOS presentation, and whether
   shared Compose UI is actually worth adding.
3. Before writing implementation code, sketch the shared state algebra:
   sealed states, value-bearing variants, nullable boundaries, refresh/error
   policy seams, and native presentation adapters.
4. Start in `shared-core` for repository and data seams.
5. Add or update `shared-feature-*` for typed feature state and orchestration.
6. Wire shared Metro DI in `shared-di`.
7. Add the Android Circuit shell in `android-app`.
8. Add the iOS TCA and SwiftUI shell in `ios-app`.
9. Add `shared-ui-*` only if the feature benefits from a reusable shared
   Compose path.
10. Add tests at the shared seam and native presentation seams.
11. Update docs only if the architecture changed or the blueprint needs a new
    reusable lesson.

## Guardrails

- Shared Kotlin owns domain, data, business rules, and typed feature state.
- Shared Kotlin must not expose Circuit or TCA types.
- Android owns Circuit screens, presenters, navigation, and Android UI.
- iOS owns TCA reducers, Swift-native mapping, navigation, and SwiftUI views.
- Shared Compose UI is optional, not the mandatory app shell.
- Prefer typed async state over loose booleans like `isLoading`.
- Prefer value-bearing state variants over nullable payloads. If a nullable
  appears in feature state, decide whether it is a real domain absence or a
  missing sealed case.
- Extract business policy seams, such as freshness, retry, eligibility, and
  failure interpretation, out of orchestration services when they become
  independently nameable.
- Keep shared sealed hierarchies friendly to Swift interop. Use concrete
  sealed cases for platform adapters, and marker contracts only when they do
  not hide useful cases from Swift.
- Tests should reflect state transitions with clear `given`, `when`, `then`
  structure.

## Execution notes

- Use the diagrams and ownership map in
  [`docs/reference/how-to-add-a-feature.md`](/Users/pragmatickeoz/StudioProjects/Mobi/docs/reference/how-to-add-a-feature.md)
  as the first placement check before creating files.
- During OpenSpec/design work, include a short "state and policy design"
  section before task implementation starts.
- Reuse the `home` feature as the concrete reference implementation unless the
  user asks for a deliberate architectural departure.
- If the task adds a new pattern rather than following the current one, update
  the architecture docs and add an ADR.
