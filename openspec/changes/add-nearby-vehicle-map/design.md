## Context

`nearby-vehicle-map` is the first narrow car-sharing capability being shaped in
`Mobi`.

It needs to feel like a real product seam without collapsing the repository's
architecture into a platform-specific map proof of concept. The capability
therefore has to do two things at once:

- stay small enough to explain and test clearly
- be realistic enough to carry real product behavior

The current capability decisions are:

- location is required while the app is in use for map discovery
- rider location distinguishes resolving, available, denied, and temporarily
  unavailable states
- after a successful location resolution, the map can keep using the last
  resolved rider location if live location degrades
- vehicle snapshots are rider-centered rather than viewport-driven
- the snapshot minimum is stable vehicle identities plus vehicle locations
- automatic refresh happens every 10 seconds while the map is visible
- stale snapshots can remain visible for up to 30 seconds
- failure after the stale window blocks the map with an overlay and indicator
- clustering and animated transitions are explicitly deferred

## Goals / Non-Goals

**Goals:**

- preserve the native Android and iOS shell ownership described in the repo
- model the feature as shared product state and rules, not only as a map view
- introduce a realistic simulation seam for changing fleet snapshots
- make refresh and stale behavior explicit and testable
- keep the first capability narrow enough to support later discovery and
  reservation features without overcommitting too early

**Non-Goals:**

- choosing a concrete map SDK in this design
- defining vehicle reservation behavior
- introducing shared Compose map UI
- designing cluster behavior
- guaranteeing animated vehicle motion or smooth marker transitions
- defining richer vehicle metadata beyond what the map capability requires

## Decisions

### Shared and native ownership

The capability should follow the repository's existing rule:

```text
shared Kotlin owns business rules and typed state
native shells own platform presentation and lifecycle
```

For this capability, that means:

```text
shared-core
  -> domain models and repository contracts

shared-feature-nearby-vehicle-map
  -> feature state, location/snapshot state transitions, refresh rules,
     stale-window rules, and overlay semantics

android-app
  -> native map rendering, permission prompt UI, lifecycle hooks, and refresh
     scheduling while visible

ios-app
  -> native map rendering, permission prompt UI, lifecycle hooks, and refresh
     scheduling while visible
```

The map itself stays native. The product logic around what the map means stays
shared.

### Shared domain model

The minimum shared model should stay intentionally small:

- `VehicleId`
- `VehicleLocation`
- `NearbyVehicle`
- `FleetSnapshot`
- `RiderLocation`

`NearbyVehicle` only needs stable identity and location in this first
capability. Richer details can be introduced in later capabilities.

`FleetSnapshot` should include enough meaning for replacement and freshness
decisions, but its exact structure should still emerge through TDD.

For this capability, a fleet snapshot should be understood as:

- a coherent point-in-time result for a rider-centered nearby-vehicle query
- the current known set of nearby vehicles for that successful query
- a result that can be empty without being treated as an error
- a result that can later be replaced wholesale by a newer successful snapshot

The design should preserve these behavioral guarantees:

- one successful snapshot becomes the current known fleet state until a newer
  successful snapshot replaces it
- empty-success is still a valid snapshot and should not be conflated with
  failure
- freshness can be evaluated from snapshot information without forcing the
  platform shell to invent product rules
- the feature can compare successive snapshots closely enough to preserve
  stable identity semantics for vehicles that remain present

Conceptually:

```text
FleetSnapshot
  -> "this is the current known nearby fleet state at a specific moment"

Empty FleetSnapshot
  -> "the nearby query succeeded, but no vehicles are currently nearby"

Newer FleetSnapshot
  -> replaces the older current known state
```

The design does not need to lock down whether that freshness comes from a
timestamp, sequence marker, or another equivalent representation yet. The TDD
cycle should still determine the smallest concrete shape that satisfies the
spec behavior.

### Shared repository contracts

The first shared repository boundary should stay narrow.

This capability needs a shared fleet snapshot repository, but it does not need
shared ownership of device location infrastructure.

A good boundary is:

- shared feature receives rider location context as input
- shared repository returns a rider-centered fleet snapshot
- shared repository semantics allow empty success, transient failure, and
  changing successive snapshots

Conceptually:

```text
platform shell
  -> resolves rider location and permission state
  -> passes rider location context into shared feature

shared feature
  -> requests nearby fleet snapshot for that rider context

shared repository
  -> returns FleetSnapshot or failure
```

This keeps location permission prompts, live device location APIs, and
lifecycle-specific location mechanics in the native shells where they belong.

The shared repository should focus on the product-facing contract:

- input: rider-centered discovery request
- output: fleet snapshot with stable vehicle identities and locations
- behavior: successive requests may add, remove, or reposition vehicles

At this stage, "contract" should be read as capability semantics, not a fixed
implementation API. The TDD cycle should still drive the exact repository
interface, helper types, and naming.

The design only needs the repository boundary to preserve these meanings:

- the request is anchored in rider location context rather than raw map
  viewport mechanics
- the response can represent a successful snapshot, including an empty-success
  result when no nearby vehicles exist
- the repository can surface transient failure without forcing the shared
  feature to erase the last successful snapshot immediately
- repeated successful requests are allowed to return changed fleet state while
  preserving stable vehicle identity for vehicles that remain present

This suggests a conceptual shape like:

```text
Discovery request
  -> enough rider-centered context to ask "what vehicles are nearby?"

Discovery result
  -> success with a fleet snapshot
  -> or failure that the feature can interpret as transient
```

The exact representation of these concepts should stay intentionally open until
tests start pulling the design into concrete forms.

### Shared feature state

The feature state should not collapse everything into one loadable.

An intended shape is:

```text
NearbyVehicleMapFeatureState
├── riderLocationState
│   ├── Resolving
│   ├── Available(currentOrLastResolved)
│   ├── Denied
│   └── TemporarilyUnavailable
├── snapshotState
│   ├── Initial
│   ├── Loading
│   ├── Loaded(snapshot)
│   ├── Refreshing(snapshot)
│   └── Failed(previousSnapshot?)
└── mapOverlayState
    ├── None
    ├── RefreshingIndicator
    ├── StaleIndicator
    └── BlockingFailure
```

This lets the feature preserve useful state in realistic ways:

- location can degrade without destroying the last resolved position
- refresh can fail without immediately erasing the last good snapshot
- the platform shell can render overlays without owning the underlying
  business rules

At this stage, the important thing is the meaning of these states, not their
exact implementation form.

`snapshotState` should answer:

- has the feature never successfully loaded a nearby fleet snapshot yet?
- is the feature currently attempting its first load?
- is there a current known successful snapshot?
- is a refresh happening while a current known snapshot remains visible?
- has loading or refreshing failed, and if so, is there still a last known
  successful snapshot available?

`mapOverlayState` should answer:

- should the map currently show no overlay?
- should the map show a non-blocking indicator for refresh activity?
- should the map show a non-blocking stale indicator because the current
  snapshot is still within the tolerated stale window?
- should the map be blocked by a failure overlay because no trustworthy nearby
  fleet view is currently available?

These two state areas are related but should not be conflated.

Conceptually:

```text
snapshotState
  -> what the current nearby fleet data situation is

mapOverlayState
  -> how the map should surface that situation to the rider
```

That distinction is important for this capability because the same underlying
snapshot state can lead to different presentation obligations over time:

- a successful snapshot with a refresh in progress should remain visible with a
  non-blocking refresh indicator
- a successful snapshot after transient failure can remain visible with a
  non-blocking stale indicator while still inside the 30 second stale window
- once the stale window is exceeded, the feature should no longer treat the
  last snapshot as trustworthy enough for normal map interaction, so the map
  transitions to a blocking failure overlay

The design should preserve these semantics:

- first-load failure and post-stale-window failure both lead to a blocking map
  overlay
- refresh activity does not erase the last successful snapshot
- stale indication is a temporary degraded-success state, not a distinct kind
  of successful snapshot
- blocking failure is about trustworthiness of the current nearby map view, not
  only about whether the repository most recently returned an error

The TDD cycle should still decide whether these meanings are best represented
with one composed state tree, multiple smaller state types, or a different
equivalent structure.

### Rider location and snapshot interaction rules

The rider location states are already part of the capability contract, but the
important design question is how they constrain nearby fleet discovery over
time.

The design should preserve these interaction rules:

- while rider location is still resolving, the feature may prepare for
  discovery but should not claim that a rider-centered nearby fleet snapshot is
  already available
- when rider location becomes available for the first time, the feature is
  allowed to begin rider-centered nearby fleet loading
- if location access is denied before any successful location resolution, the
  feature should not proceed as if rider-centered discovery can succeed
- if rider location is temporarily unavailable before any successful location
  resolution, the feature should remain blocked from truthful rider-centered
  discovery
- once a rider location has been successfully resolved, temporary loss of live
  location should not automatically invalidate the last resolved rider context
  or the current nearby fleet snapshot

Conceptually:

```text
Resolving location
  -> no truthful nearby snapshot yet

Available location
  -> rider-centered discovery may load or refresh

Denied or temporarily unavailable before first success
  -> nearby discovery remains blocked

Temporarily unavailable after first success
  -> keep the last resolved rider context
  -> allow existing nearby snapshot rules to continue
```

This keeps the model honest in two ways:

- the app does not pretend to know what is nearby before it has a rider
  position context
- the app also does not overreact to temporary live-location degradation once
  the rider context has already been established

The shared feature therefore should not treat location state and snapshot state
as a single synchronized ladder. They influence each other, but they are not
the same progression.

For example:

- rider location may already be `Available` while snapshot state is still
  `Initial` or `Loading`
- snapshot state may remain `Loaded` or `Refreshing` while live location has
  degraded to temporary unavailability after an earlier success
- rider location may be `Denied` while no truthful snapshot can exist at all

The exact mechanics for when refresh attempts are suppressed, resumed, or
reinterpreted should still be left to the TDD cycle, as long as the behavioral
rules above remain intact.

### Timing and freshness

The capability timing rules are shared product rules:

- refresh interval: 10 seconds while the screen is visible
- stale window: 30 seconds since the last successful snapshot

The native shell decides when the screen is visible enough to trigger work.
The shared feature decides whether the current snapshot is fresh, stale, or no
longer trustworthy enough to display without a blocking overlay.

At this stage, the design should preserve the timing semantics without locking
down the scheduling mechanics.

The important meanings are:

- refresh cadence only matters while the nearby vehicle map is meaningfully
  visible to the rider
- the 10 second interval is the normal cadence for attempting to keep the
  current known snapshot fresh
- the 30 second window is not another refresh cadence; it is the limit for how
  long the feature may continue treating the last successful snapshot as
  trustworthy enough to remain visible without a blocking failure overlay

Conceptually:

```text
Map visible
  -> feature is allowed to participate in refresh cadence

Refresh succeeds
  -> snapshot becomes current known state again
  -> stale clock effectively resets

Refresh fails temporarily
  -> last successful snapshot may remain visible
  -> stale clock keeps advancing

Stale window exceeded
  -> map is no longer trustworthy enough for normal interaction
  -> blocking failure overlay takes over
```

This means refresh timing and stale timing should be understood as two related
but different concerns:

- refresh timing answers "when should the feature try again while visible?"
- stale timing answers "how long can the rider keep trusting the last known
  nearby map state after refresh stops succeeding?"

The design should also preserve these boundaries:

- visibility determines whether routine refresh participation is expected
- a successful refresh reestablishes trust in the nearby snapshot
- transient failure does not immediately erase useful state
- stale expiration is about loss of trustworthiness, not only about whether a
  timer happened to fire

The exact implementation choices for clocks, timers, suspension while not
visible, and restart behavior when visibility resumes should still be shaped by
the TDD cycle.

### Simulation seam

The simulated fleet repository should already behave like a changing system.

Successive snapshots may:

- retain vehicles with the same identity at new positions
- remove vehicles entirely
- introduce new vehicles

The capability does not guarantee animation, so replacing one snapshot with
another is sufficient for the first implementation.

### Testing direction

Most behavioral confidence should come from shared tests.

The intended implementation style is TDD, especially for shared domain and
shared feature logic. Domain tests and shared state tests should be written
before the corresponding implementation work rather than collected at the end.

The shared layer should be able to verify:

- rider location state transitions
- snapshot loading and replacement
- empty-success behavior
- refresh every 10 seconds while visible
- stale behavior up to 30 seconds
- blocking failure after the stale window
- stable vehicle identities across snapshots

Platform tests should stay thinner and focus on:

- permission request wiring
- visible-screen refresh scheduling
- overlay presentation for refresh, stale, and blocking failure states

## Risks / Trade-offs

- Native map ownership means duplicated presentation work across Android and
  iOS, but that is aligned with the repo's architecture goals.
- The composed state model is more complex than the current sample feature, but
  this is the right place in the repo's evolution to introduce that complexity.
- Leaving the rider-centered radius configurable preserves flexibility, but the
  eventual implementation will still need a concrete default.
- Stable vehicle identity adds a little conceptual rigor now and avoids later
  rework when reservation and detail flows arrive.
