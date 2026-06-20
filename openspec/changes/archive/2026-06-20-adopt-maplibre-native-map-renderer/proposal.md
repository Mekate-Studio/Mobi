## Why

The nearby vehicle map currently uses lightweight Canvas rendering, which is
useful for proving shared state but is not a strong enough foundation for
future map-heavy capabilities. Before adding parking zones, charging stations,
and richer map interactions, the app should move to a real native map renderer
while preserving shared Kotlin ownership of product state.

## What Changes

- Add MapLibre Native as the native map renderer on Android and iOS.
- Use OpenFreeMap as the initial public-friendly basemap style/source for this
  feature.
- Introduce a provider-neutral map scene contract that shared feature state can
  drive without depending on MapLibre types.
- Adapt the nearby vehicle map to render rider location and vehicle markers on
  MapLibre instead of custom Canvas drawing.
- Keep basemap configuration outside shared business state so the renderer can
  change style sources later without changing feature logic.
- Keep tests focused on shared state and native adapter mapping rather than
  live tile availability.

## Capabilities

### New Capabilities

- `native-map-rendering`: Native Android and iOS map rendering driven by shared
  map scene state, with configurable basemap source and product overlays.

### Modified Capabilities

- None.

## Impact

- Android app adds MapLibre Native dependency and replaces nearby vehicle
  Canvas drawing with a MapLibre-backed view/composable.
- iOS app adds MapLibre Native dependency and replaces nearby vehicle SwiftUI
  Canvas drawing with a MapLibre-backed view.
- Shared Kotlin gains provider-neutral map scene/presentation state only where
  it improves reuse across future map features.
- App configuration gains a public basemap style/source setting for
  OpenFreeMap.
- CI and tests may need lightweight map-renderer adapter seams to avoid
  depending on network tile loading.
