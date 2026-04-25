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

`FleetSnapshot` should include enough data for replacement and freshness
decisions, such as a capture timestamp plus the current set of nearby vehicles.

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

### Timing and freshness

The capability timing rules are shared product rules:

- refresh interval: 10 seconds while the screen is visible
- stale window: 30 seconds since the last successful snapshot

The native shell decides when the screen is visible enough to trigger work.
The shared feature decides whether the current snapshot is fresh, stale, or no
longer trustworthy enough to display without a blocking overlay.

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
