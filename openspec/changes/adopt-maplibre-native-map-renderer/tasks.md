## 1. Shared Map Scene Contract

- [x] 1.1 Decide whether the initial provider-neutral map scene lives in
  `shared-core` or remains nearby-vehicle-map local for this change
- [x] 1.2 Add typed map scene/presentation models for camera target, rider
  marker, vehicle markers, and overlay state
- [x] 1.3 Update nearby vehicle map presentation mapping to emit the map scene
  without MapLibre or platform types
- [x] 1.4 Add shared or Android presentation tests covering camera, rider
  marker, vehicle marker, empty snapshot, and blocking overlay mapping

## 2. Android MapLibre Renderer

- [x] 2.1 Add MapLibre Android dependency and required Android configuration
- [x] 2.2 Add Android basemap configuration for the default OpenFreeMap style
  URL
- [x] 2.3 Replace `NearbyVehicleMapDrawing` Canvas usage with a MapLibre-backed
  renderer component
- [x] 2.4 Render rider and vehicle markers from the provider-neutral map scene
- [x] 2.5 Preserve existing refresh, stale, and blocking overlay UI above the
  MapLibre map
- [x] 2.6 Add Android tests for presenter/presentation adapter behavior without
  requiring remote tiles

## 3. iOS MapLibre Renderer

- [x] 3.1 Add MapLibre iOS dependency through the existing Xcode package setup
- [x] 3.2 Add iOS basemap configuration for the default OpenFreeMap style URL
- [x] 3.3 Replace `NearbyVehicleMapView` Canvas map drawing with a
  MapLibre-backed SwiftUI wrapper
- [x] 3.4 Render rider and vehicle markers from the provider-neutral map scene
- [x] 3.5 Preserve existing refresh, stale, and blocking overlay UI above the
  MapLibre map
- [x] 3.6 Add iOS reducer/state tests for map scene mapping without requiring
  remote tiles

## 4. Validation And Cleanup

- [x] 4.1 Remove or quarantine Canvas-specific projection code once MapLibre
  owns geographic positioning
- [x] 4.2 Run shared feature, Android app, and iOS test jobs
- [x] 4.3 Run repo format and lint checks
- [x] 4.4 Manually smoke the nearby vehicle map on Android or iOS enough to
  confirm basemap loading and marker rendering
- [x] 4.5 Update architecture docs only if implementation introduces a reusable
  map scene pattern beyond nearby vehicle map
