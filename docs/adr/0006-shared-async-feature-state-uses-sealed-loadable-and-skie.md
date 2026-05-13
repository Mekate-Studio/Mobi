# ADR 0006: Shared Feature State Uses Sealed Value Types and SKIE

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

The nearby vehicle map feature expands the same lesson beyond a single async
loadable. It has rider-location state, fleet-snapshot state, freshness policy,
and overlay state. Some states can carry useful values, such as a last resolved
rider location or a previous fleet snapshot, while other states explicitly
mean that no trustworthy value exists. Modeling those differences with
nullable payloads would push business meaning into repeated `thingOrNull()`
helpers and platform-specific inference.

At the same time, the shared state is consumed from Swift. A full Kotlin sealed
screen state would normally be awkward there, but the Gradle bridge now uses
SKIE so Swift can switch exhaustively over shared sealed hierarchies.

## Decision

We model shared feature state as:

- a top-level shared data class for the overall screen state
- sealed value-bearing states for mutually exclusive feature modes
- named policy seams when business rules become independently testable

For feature state:

- prefer explicit sealed cases over boolean flags
- prefer value-bearing variants over nullable payloads when variants behave
  differently
- use nullable payloads only when absence is itself the domain concept
- keep native presentation strings and platform UI state outside shared
  business state

For the home feature, that sealed async state is `CounterLoadable` with:

- `Initial`
- `Loading(previousValue)`
- `Loaded(value)`
- `Error(previousValue, reason)`

The shared Kotlin service catches repository failures and returns an error
state instead of letting expected repository failures leak into platform
reducers or presenters.
User-facing error copy is not carried by the shared feature state. Shared
Kotlin now exposes a typed failure reason, and platform rendering layers map
that reason into localized strings.

For the nearby vehicle map feature, the same decision means states such as:

- `Available(location)` and `TemporarilyUnavailable(location)` instead of a
  temporary state with an optional last location
- `Loaded(snapshot)`, `Refreshing(snapshot)`, `FailedWithSnapshot(snapshot)`,
  and `FailedWithoutSnapshot` instead of one failed state with an optional
  previous snapshot

When multiple concrete states share behavior, Kotlin may use small marker
contracts, such as "has visible rider location" or "has retained snapshot".
Those contracts should not hide useful concrete sealed cases from Swift. Swift
adapters should still be able to switch on cases like `.available`, `.loaded`,
and `.failedWithSnapshot`.

Business policies that become nameable, such as freshness windows, refresh
eligibility, retry interpretation, or failure-to-overlay mapping, should be
extracted from orchestration services into focused shared policy objects.

On iOS, Swift maps the shared sealed async state into a native Swift enum for
TCA state and SwiftUI rendering. SKIE is enabled on the Gradle bridge for
sealed hierarchy ergonomics, but SKIE coroutine and Flow interop are
intentionally disabled for now because this repository only needs sealed
interop from SKIE at the moment.

## Consequences

Positive:

- feature modes are explicit and exhaustive in Kotlin
- invalid combinations like `isLoading=true` plus an unrelated success payload
  disappear
- invalid nullable combinations are reduced when different values imply
  different behavior
- Android Circuit, shared Compose, and iOS TCA all render from the same shared
  feature lifecycle
- error handling is exercised end to end from shared repository to both
  platforms
- Swift can still consume the sealed hierarchy ergonomically through SKIE
- shared services stay focused when policy rules are extracted

Trade-offs:

- there is a bit more type surface than a single boolean flag
- sealed case design needs extra care because Swift interop is part of the
  public feature contract
- Swift tests need explicit Kotlin wrapper construction for some shared values
- the Gradle bridge now owns one more piece of iOS-facing Kotlin compiler
  configuration

## Notes

This ADR does not adopt a fully generic `Loadable<T>` yet. The current feature
uses a feature-local sealed type first so the pattern stays easy to evolve and
validate before we generalize it.

This ADR also does not require every shared state to be sealed. Plain data
classes are still appropriate for coherent value objects. Sealed types earn
their place when they prevent invalid combinations or make state transitions
clearer.
