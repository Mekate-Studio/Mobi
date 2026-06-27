## Why

The nearby vehicle map is becoming the primary product surface, so riders should
land there immediately and the app should request the location context it needs
without requiring a manual simulation button. Because future vehicle actions
depend on trustworthy proximity, the map must require precise while-in-use
location and block action affordances when location access is denied,
restricted, approximate-only, or temporarily unavailable before any precise
position has been resolved.

## What Changes

- Make the nearby vehicle map the default screen when entering the app on both
  Android and iOS.
- Request while-in-use location by default when the rider enters the nearby
  vehicle map, instead of requiring a manual "Use rider location" action.
- Require precise rider location for rider-centered nearby vehicle discovery.
- Treat denied access, restricted access, disabled services, and approximate-only
  location as blocked map states for discovery and future vehicle actions.
- Preserve graceful degraded behavior when a precise rider location was already
  resolved and live location later becomes temporarily unavailable.
- Replace simulated location-grant paths with native platform location
  adapters, while keeping shared Kotlin free of platform location APIs.

## Capabilities

### New Capabilities

- `app-entry-navigation`: Defines which app destination is selected when the
  app first opens.

### Modified Capabilities

- `nearby-vehicle-map`: Refines rider location requirements so the map requests
  precise while-in-use location on entry, treats non-precise or blocked location
  outcomes as non-actionable, and keeps vehicle action affordances disabled when
  rider location is not trustworthy.

## Impact

- `android-app/`: default destination selection, Android location permission
  request, precise location resolution, denied/restricted/approximate handling,
  and map action blocking presentation.
- `ios-app/`: default tab selection, Core Location authorization request,
  precise location resolution, Info.plist usage description, reduced-accuracy
  handling, denied/restricted handling, and map action blocking presentation.
- `shared-feature-nearby-vehicle-map/`: shared state and overlay semantics may
  need a more explicit blocked-location reason so native shells do not invent
  product rules locally.
- `openspec/`: adds the app entry capability and updates nearby vehicle map
  requirements for precise location and non-actionable blocked states.
