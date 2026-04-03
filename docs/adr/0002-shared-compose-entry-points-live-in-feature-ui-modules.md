# ADR 0002: Shared Compose entry points live in feature UI modules

- Status: Accepted
- Date: 2026-04-03

## Context

The repository originally kept a `shared/` compatibility module that wrapped
the home feature UI behind a generic `Screen()` function. That made the shared
Compose path harder to reason about because the entry point lived outside the
feature UI module that actually owned the screen.

## Decision

Shared Compose entry points live in the feature UI modules that own them.

For the home feature:

- `shared-ui-home` owns the reusable `HomeContent`
- `shared-ui-home` also owns the optional `SharedHomeScreen` entry point
- `ios-app/src/ViewController.kt` exposes `SharedHomeViewController` as the iOS
  embedding path for that optional shared Compose screen
- the old `shared/` compatibility bridge is removed

## Consequences

- feature UI stays discoverable in one place
- optional shared Compose embedding remains available without pretending to be
  the app root
- new shared screens should be added directly in their `shared-ui-*` module
- future cleanup no longer needs to preserve a fake compatibility package
