# native-map-rendering Specification

## Purpose
TBD - created by archiving change adopt-maplibre-native-map-renderer. Update Purpose after archive.
## Requirements
### Requirement: Render maps with native MapLibre

The app MUST use native MapLibre rendering for map surfaces covered by this
capability, while keeping shared Kotlin state free of MapLibre-specific types.

#### Scenario: Nearby vehicle map uses native renderer
- **WHEN** the nearby vehicle map is displayed with a usable rider-centered map
  state
- **THEN** Android renders the map with MapLibre Native
- **AND** iOS renders the map with MapLibre Native

#### Scenario: Shared state remains provider neutral
- **WHEN** shared Kotlin emits map-related state for native rendering
- **THEN** that state does not expose MapLibre classes, style-layer classes, or
  platform map view types
- **AND** Android and iOS adapt the shared state into their native MapLibre
  renderer implementations

### Requirement: Load a configurable basemap style

The app MUST load its basemap from platform configuration so the map style and
source can be changed without changing shared feature logic.

#### Scenario: Default basemap is configured
- **WHEN** the map renderer is created without an environment-specific
  override
- **THEN** the renderer uses the default OpenFreeMap style configured by the
  app
- **AND** the shared nearby vehicle map feature does not know the concrete
  basemap URL

#### Scenario: Basemap source changes
- **WHEN** the configured basemap style URL changes
- **THEN** the native map renderer uses the new style source
- **AND** shared map feature state and tests do not require product behavior
  changes

### Requirement: Render product overlays separately from the basemap

The app MUST treat rider position and vehicle markers as product overlays
derived from shared feature state, not as part of the basemap source.

#### Scenario: Rider marker is rendered as product overlay
- **WHEN** shared state contains a visible rider location
- **THEN** the native map renderer displays the rider marker at that location
- **AND** the marker does not depend on basemap tile contents

#### Scenario: Vehicle markers are rendered as product overlays
- **WHEN** shared state contains a current fleet snapshot
- **THEN** the native map renderer displays a marker for each vehicle in that
  snapshot
- **AND** the markers use stable vehicle identities from shared state

### Requirement: Preserve existing nearby map behavior

The native renderer MUST preserve the existing nearby vehicle map behavior for
rider context, fleet snapshots, refresh indicators, stale indicators, and
blocking failure overlays.

#### Scenario: Existing overlay state is preserved
- **WHEN** shared nearby vehicle map state emits refreshing, stale, or blocking
  failure overlay state
- **THEN** the native map screen presents the corresponding overlay behavior
  above the MapLibre map

#### Scenario: Tests do not depend on live tiles
- **WHEN** automated tests verify native map rendering behavior
- **THEN** they validate shared state and native adapter mapping
- **AND** they do not require OpenFreeMap or any remote tile source to be
  reachable

