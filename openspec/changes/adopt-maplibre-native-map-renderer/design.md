## Context

The nearby vehicle map has a functional rider-centered map rendered with
Canvas on Android and SwiftUI. That kept the first implementation lightweight,
but it leaves the app without real map gestures, basemap context, attribution,
style layers, or a scalable path for future map features.

The next map slice needs a real native renderer without moving product rules
out of shared Kotlin. MapLibre Native fits that split: Android and iOS own
native map SDK integration, while shared Kotlin continues to own rider
location, fleet snapshot, freshness, and future map scene semantics.

This change should stay public-repo friendly. The implementation can use
OpenFreeMap as the initial basemap source, but basemap style/source selection
must remain configuration rather than shared business state.

## Goals / Non-Goals

**Goals:**

- Replace the nearby vehicle Canvas renderer with MapLibre Native on Android
  and iOS.
- Use OpenFreeMap as the initial configurable basemap style/source.
- Keep shared Kotlin provider-neutral: no MapLibre types in shared feature or
  core state.
- Introduce a small map scene/presentation contract that future map features
  can extend for overlays such as parking zones and charging stations.
- Preserve the type-driven shared feature-state model already established for
  nearby vehicle map.
- Keep tests deterministic by validating state-to-map adapter output, not live
  tile downloads.

**Non-Goals:**

- Building or operating tile infrastructure.
- Adding parking zones, charging stations, clustering, route overlays, or
  selection details in this change.
- Choosing long-term basemap infrastructure beyond the initial configurable
  source.
- Implementing offline maps.

## Decisions

### Use MapLibre Native as the renderer

Android and iOS will integrate MapLibre Native directly in their native shells.
The existing Canvas renderer should be treated as a temporary implementation,
not the long-term map surface.

Alternatives considered:

- Keep Canvas: too limited for gestures, basemap context, and future layers.
- Use platform-specific maps: good native feel, but lower parity and weaker
  shared layer vocabulary for future map overlays.
- Use a closed-provider SDK: strong UX, but a worse fit for a public reference
  repo and clean-clone onboarding.

### Keep shared state provider-neutral

Shared Kotlin should expose map scene meaning, not SDK instructions. It can own
coordinates, stable IDs, camera intent, and logical layers. Platform code maps
that scene into MapLibre sources, layers, annotations, or camera operations.

Conceptually:

```text
shared-feature-nearby-vehicle-map
  -> NearbyVehicleMapFeatureState
  -> provider-neutral presentation / map scene

android-app
  -> MapLibre composable/view adapter

ios-app
  -> MapLibre view adapter
```

This protects future provider changes and keeps Circuit/TCA/MapLibre types out
of shared Kotlin.

### Use OpenFreeMap as configurable basemap source

The first implementation should load an OpenFreeMap style URL through platform
configuration. The concrete style URL, attribution behavior, and any fallback
display should live in native app configuration, not shared feature state.

The important public decision is that the basemap source is replaceable. The
repo should not hard-code provider assumptions into shared business logic.

### Separate basemap from product overlays

The basemap provides roads, labels, water, parks, and surrounding context.
Product overlays provide rider position, vehicle markers, and later parking
zones or charging POIs.

For this change:

- rider position and vehicles remain app-managed product overlays.
- basemap style/source is loaded by MapLibre.
- future custom layers should be able to attach as separate product overlay
  sources rather than being merged into the basemap.

### Start with marker overlays, not custom vector tile overlays

Nearby vehicles are small, session-specific, and refresh frequently. They
should remain app-managed marker/annotation data derived from shared feature
state.

Parking zones and charging stations are intentionally deferred. When they land,
they can choose between app-managed GeoJSON, platform annotations, or vector
tile sources based on size and update frequency.

### Test adapter boundaries instead of live maps

Shared tests should continue to verify feature-state transitions. Android and
iOS tests should verify that map presentation/adapters receive the expected
camera target, rider marker, vehicle marker data, and overlay state.

Tests should not depend on OpenFreeMap availability or remote tile rendering.

## Risks / Trade-offs

- External SDK setup adds build complexity → Keep the first integration narrow
  and validate Android/iOS build paths early.
- Remote basemap availability can affect manual QA → Keep automated tests away
  from live tile availability and provide a loading/fallback surface.
- MapLibre APIs differ across Android and iOS → Keep adapters platform-owned
  and map from the same shared scene contract.
- OpenFreeMap has no SLA → Treat it as initial public-friendly infrastructure,
  not a shared product dependency.
- Native map views inside Compose/SwiftUI can have lifecycle quirks → Isolate
  MapLibre setup/update logic behind small dedicated renderer components.

## Migration Plan

1. Add MapLibre dependencies and basic renderer scaffolding on Android and iOS.
2. Add platform basemap configuration for the OpenFreeMap style URL.
3. Replace Canvas rendering with MapLibre rendering for rider and vehicle
   markers.
4. Preserve existing nearby vehicle map feature state and refresh behavior.
5. Add adapter tests around map scene/presentation mapping.
6. Remove or quarantine Canvas-specific projection code once MapLibre owns
   geographic positioning.

Rollback is straightforward while this is a local feature change: restore the
Canvas renderer and remove MapLibre platform dependencies.

## Open Questions

- Which exact OpenFreeMap style should be the initial default?
- Should the Canvas renderer remain behind a debug fallback during the first
  MapLibre pass, or should it be removed immediately after validation?
- Should a reusable shared `MapSceneState` live in `shared-core`, a new
  shared map feature module, or remain local to nearby vehicle map until the
  second map feature appears?
