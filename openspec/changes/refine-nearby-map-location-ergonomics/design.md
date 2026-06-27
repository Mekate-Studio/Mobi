## Context

The nearby vehicle map already models rider location, fleet snapshots, refresh
cadence, stale overlays, and blocking failures in shared Kotlin. Android and
iOS currently adapt that shared state into native map screens, but both
platforms still use a manual "Use rider location" path that feeds a fixed
Copenhagen coordinate into the shared feature.

This change turns the nearby vehicle map into the default app destination and
makes native precise while-in-use location resolution part of entering that
screen. It should preserve the repository's ownership rule:

```text
native shell
  -> permission prompt, platform location APIs, lifecycle, accuracy checks

shared Kotlin
  -> product meaning of rider location, map blocking, snapshots, refresh,
     stale state, and future action eligibility
```

The current shared map state already has useful building blocks:

```text
NearbyVehicleMapFeatureState
├── riderLocationState
│   ├── Resolving
│   ├── Available(location)
│   ├── Denied
│   ├── TemporarilyUnavailable(lastResolvedLocation)
│   └── Unavailable
├── snapshotState
└── mapOverlayState
```

The missing piece is not a new shared location provider. It is a native adapter
that turns platform permission and accuracy outcomes into this shared product
state.

## Goals / Non-Goals

**Goals:**

- Make the nearby vehicle map the selected destination when the app opens.
- Request while-in-use location automatically when the nearby map first appears.
- Require precise location before the map is considered actionable.
- Keep denied, restricted, disabled, approximate-only, and unresolved location
  states visibly blocked for discovery and future vehicle actions.
- Keep platform location APIs out of shared Kotlin.
- Preserve the last precise rider location when live location later becomes
  temporarily unavailable.

**Non-Goals:**

- Add reservation, unlock, booking, or vehicle-detail behavior.
- Add background location.
- Add continuous turn-by-turn tracking or high-frequency map camera updates.
- Introduce a shared Compose map path.
- Replace the current shared fleet simulation with a real backend.

## Decisions

### Nearby map is the default app destination

Android should initialize the app destination to the nearby vehicle map.
iOS should select the nearby vehicle map tab by default.

Alternative considered: keep Native Home first and deep-link into the map. That
would keep the sample-home framing prominent, but it would make the product map
feel secondary and would not exercise the permission-on-entry behavior as the
normal app path.

### Native shells own precise location resolution

Android and iOS should each own a small location adapter that converts platform
outcomes into feature events:

```text
Entered nearby map
  -> request while-in-use authorization if needed
  -> require precise accuracy
  -> resolve current coordinate
  -> send Available(location) or blocked/unavailable outcome
```

Android should request the permissions needed to distinguish precise from
approximate location on modern Android. A grant that only allows approximate
location should not be treated as a usable rider coordinate for this feature.
iOS should use Core Location, add a while-in-use usage description, and treat
reduced accuracy as insufficient for nearby vehicle discovery.

Alternative considered: put a shared location facade in Kotlin. That would make
the feature look more symmetrical, but it would blur platform permission
lifecycle, Info.plist, Android permission, and accuracy behavior into shared
code that cannot own those concerns well.

### Permission granted is not the feature event

The shared feature should respond to rider-location outcomes, not raw permission
outcomes. "Permission granted" is only useful if the platform also resolves a
precise coordinate.

The platform-facing event shape can evolve from:

```text
LocationPermissionGranted
LocationPermissionDenied
LocationTemporarilyUnavailable
```

to a more product-shaped boundary:

```text
PreciseLocationResolved(location)
LocationAccessBlocked(reason)
LocationTemporarilyUnavailable
```

The exact names can follow local Android and iOS conventions during
implementation. The important boundary is that shared Kotlin receives a precise
`RiderLocation` only after the platform adapter has verified permission,
services, and accuracy.

Alternative considered: keep the existing "permission granted" event and let
the presenter/client use a default coordinate. That keeps tests small, but it
preserves the simulation seam in the production path and hides the new precise
location rule.

### Blocking overlay also blocks future vehicle actions

The current map has a `BlockingFailure` overlay for denied location and
unavailable trustworthy snapshots. This design extends the meaning of that
blocked state: if rider location is not precise and trustworthy, any present or
future vehicle action affordance must be disabled or absent.

The first implementation does not need to add vehicle actions. It should create
or preserve a platform presentation contract such as `isActionable`,
`canInteractWithVehicles`, or equivalent so later marker taps, reservation
buttons, and unlock flows cannot bypass location trust.

Alternative considered: leave action blocking to future vehicle-action work.
That would defer complexity, but it would make this change weaker because the
location rule is the reason future actions are safe.

### Preserve degraded use of the last precise location

If a precise rider location has already been resolved and live location later
becomes temporarily unavailable, the shared feature may keep using the last
precise coordinate and show degraded messaging. This preserves the existing map
behavior while keeping the initial-entry rule strict.

Approximate-only location is different from temporary loss after a precise
resolution. It must not seed the map with a rider-centered vehicle snapshot.

## Risks / Trade-offs

- Native location behavior differs by OS version -> keep platform adapters
  small, test their state mapping, and keep shared tests focused on product
  state transitions.
- Android approximate permission can look like partial success -> request and
  inspect fine/coarse grants explicitly, and treat coarse-only as blocked for
  this feature.
- iOS reduced accuracy can return a coordinate -> check accuracy authorization
  before treating a coordinate as usable.
- Automatic permission prompts can feel abrupt -> trigger only when the map
  becomes visible, show resolving copy behind the system prompt, and keep the
  denied state explanatory.
- Tests should not require real GPS -> inject platform location clients or test
  reducers/presenters with deterministic outcomes.

## Migration Plan

1. Add OpenSpec deltas for default entry, precise location, and blocked action
   behavior.
2. Update shared feature state or presentation mapping if a richer blocked
   reason/actionability flag is needed.
3. Add Android location adapter wiring and default destination selection.
4. Add iOS Core Location adapter wiring, Info.plist usage copy, and default tab
   selection.
5. Update Android and iOS tests to cover automatic request outcomes, precise
   success, denied/restricted handling, approximate-only handling, and blocked
   action presentation.

Rollback is straightforward because this does not require data migration:
restore the prior default destination and manual simulation path if the native
location adapter proves unstable.
