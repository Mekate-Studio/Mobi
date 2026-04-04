# ADR 0006: Shared Async Feature State Uses Sealed Loadable and SKIE

## Status

Accepted

## Context

The original home feature modeled async work with a plain `HomeFeatureState`
data class plus an `isLoading` boolean. That worked for a single loading case,
but it did not scale well once we wanted to represent richer async outcomes:

- initial state before any counter value is loaded
- loading state while a refresh is in flight
- loaded state with a fibonacci value
- error state when the fake repository fails

Using booleans for this kind of state makes invalid combinations easier to
create and forces platform code to infer async mode from loosely-related
fields.

At the same time, the shared state is consumed from Swift. A full Kotlin sealed
screen state would normally be awkward there, but the Gradle bridge now uses
SKIE so Swift can switch exhaustively over shared sealed hierarchies.

## Decision

We model shared async feature state as:

- a top-level shared data class for the overall screen state
- a nested sealed async state for the counter lifecycle

For the home feature, that sealed async state is `CounterLoadable` with:

- `Initial`
- `Loading(previousValue)`
- `Loaded(value)`
- `Error(previousValue, message)`

The shared Kotlin service catches repository failures and returns an error
state instead of letting expected repository failures leak into platform
reducers or presenters.

On iOS, Swift maps the shared sealed async state into a native Swift enum for
TCA state and SwiftUI rendering. SKIE is enabled on the Gradle bridge for
sealed hierarchy ergonomics, but SKIE coroutine and Flow interop are
intentionally disabled for now because this repository only needs sealed
interop from SKIE at the moment.

## Consequences

Positive:

- async modes are explicit and exhaustive in Kotlin
- invalid combinations like `isLoading=true` plus an unrelated success payload
  disappear
- Android Circuit, shared Compose, and iOS TCA all render from the same shared
  async lifecycle
- error handling is exercised end to end from shared repository to both
  platforms
- Swift can still consume the sealed hierarchy ergonomically through SKIE

Trade-offs:

- there is a bit more type surface than a single boolean flag
- Swift tests need explicit Kotlin wrapper construction for some shared values
- the Gradle bridge now owns one more piece of iOS-facing Kotlin compiler
  configuration

## Notes

This ADR does not adopt a fully generic `Loadable<T>` yet. The current feature
uses a feature-local sealed type first so the pattern stays easy to evolve and
validate before we generalize it.
