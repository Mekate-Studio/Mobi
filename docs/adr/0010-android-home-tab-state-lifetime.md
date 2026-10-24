# ADR 0010: Android Home ready state across native tab switches

Status: Accepted in [PR #65](https://github.com/Mekate-Studio/Mobi/pull/65).

## Decision

Within the same app shell and Home service instance, Native Home keeps its last
ready state when switching to Nearby and back. Initial state, loaded values
(including zero), and typed errors with absent or retained values survive that
transition. Leaving Home cancels its pending refresh. Returning shows the last
ready state and allows another refresh; it does not restore loading or restart
the cancelled request.

For example, `Loaded(8) → Loading(8) → leave Home → return Home` displays
`Loaded(8)`. An existing `Error(8, Unexpected)` returns as that exact error.
A repository response delivered after cancellation cannot replace a newer value.

The production `AppDestinationContent` function owns the existing destination
switch. It remembers the graph's Circuit instance and provides composition locals
outside the destination branches. Metro's generated getter constructs a new
Circuit and Home service on every read; memoizing the lookup keeps the service
input stable across tab recomposition. The remembered Circuit also keeps its
native factories and captured service dependencies stable for this content owner.
Only Home feature values opt into tab retention; Nearby state and jobs remain
composition-owned. Circuit 0.34.0's
[retained state holder](https://github.com/slackhq/circuit/blob/0.34.0/circuit-retained/src/commonMain/kotlin/com/slack/circuit/retained/RetainedStateHolder.kt)
provides a keyed registry for Native Home. Nearby and optional Shared Home keep
their existing state ownership in this change.

## State and work ownership

Home uses two typed values with different lifetimes:

- `readyState` uses Circuit's existing
  [`rememberRetained`](https://github.com/slackhq/circuit/blob/0.34.0/circuit-retained/src/commonMain/kotlin/com/slack/circuit/retained/RememberRetained.kt)
  and contains the initial or latest completed shared state. Its input is the
  service instance, which remains stable across presenter recreation in this shell.
- `featureState` uses ordinary `remember` and renders the visible state, including
  loading. The existing composition-owned coroutine scope owns refresh work.

The retained value updates only after the shared refresh returns and the current
job passes `ensureActive()`. This prevents a cancelled, late-returning provider
from changing retained state after Home has left composition. Cancellation still
propagates. Existing live-feature cancellation recovery remains unchanged.

Only state values are retained. Jobs, callbacks, UI objects and presenters remain
outside the retained value. A new presenter reads the retained ready state on
entry. A newly created state producer is unsuitable as the retention input because
its identity changes on tab return; the service is the stable dependency boundary.

## Costs and alternatives

The extra ready-state cell is intentional: retaining the visible state directly
would also retain `Loading`, despite cancellation of its job when the tab leaves.
Keeping inactive compositions alive would also keep feature work and UI resources
alive. Hoisting jobs or a new coordinator would broaden the lifetime policy.
This change uses the already selected Circuit APIs and adds no dependency,
serializer, shared interface, request registry or loose state flags.

This is ordinary native state ownership, with no interop workaround or new
retirement condition. Circuit/Compose updates must keep the tab-lifetime and
presenter cancellation checks green; AND-01 still governs the host-test harness.

## Evidence and remaining scope

`HomeTabLifetimeTest` renders the production destination-content function through
Circuit with Metro's real Home and Nearby presenter factories. Only UI factories
are replaced by state recorders. The tests supply Android lifecycle/ViewModel
owners, use Circuit's normal lifecycle registry, switch the selected native
destination and control repository completion. Omitting Circuit memoization
recreates services and loses the retained value; the tests exercise that boundary.
They cover ready-state re-entry, cancellation/retry while leaving with pending
work, and a late hidden response after a newer request finishes. Existing
presenter tests continue to run. Host tests use Robolectric/API 36.

Nearby retention needs a separate location/timer decision. Optional Shared Home,
Activity recreation, process restoration, device rendering and navigation-button
interaction remain unqualified here. iOS already owns its native stores at the
scene root; its effect lifetime is not an Android implementation recipe.
