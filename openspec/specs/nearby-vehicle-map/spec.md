## Purpose

Define the first narrow mobile discovery capability for the car-sharing
platform: a rider can open a nearby vehicle map, see their location context,
and view a refreshable rider-centered map snapshot of nearby vehicles under
realistic loading and failure conditions.

## Requirements

### Requirement: Show rider position on the nearby vehicle map

The app MUST establish a rider position context for the nearby vehicle map
before claiming that nearby vehicles are being shown. For this capability, the
rider location flow MUST distinguish between resolving the rider's position, a
resolved current location, denied location access, and temporary location
unavailability. This capability only requires location access while the app is
in use for nearby map discovery and does not yet require location access for
vehicle interactions beyond the map itself.

#### Scenario: Rider location is still being resolved
- **GIVEN** the rider opens the nearby vehicle map
- **WHEN** the app has started resolving the rider's current location but has
  not finished yet
- **THEN** the app indicates that the rider location is still being resolved
- **AND** the app does not imply that nearby vehicles are already positioned
  relative to the rider

#### Scenario: Rider location is available
- **GIVEN** the rider opens the nearby vehicle map
- **WHEN** the app resolves a current rider location
- **THEN** the map shows the rider's current position as the reference point
  for nearby vehicle discovery

#### Scenario: Initial map framing uses the rider position
- **GIVEN** the rider opens the nearby vehicle map
- **WHEN** the app resolves a current rider location
- **THEN** the initial map framing centers on the rider position
- **AND** the map is presented at a zoom level intended for nearby vehicle
  discovery

#### Scenario: Location access is denied
- **GIVEN** the rider opens the nearby vehicle map
- **WHEN** the app cannot access rider location because location permission has
  been denied
- **THEN** the map explains that location access is required to position nearby
  vehicles relative to the rider
- **AND** the app does not present proximity-ranked discovery results as if
  location were known

#### Scenario: Rider location is temporarily unavailable
- **GIVEN** the rider opens the nearby vehicle map
- **WHEN** the app cannot currently determine rider location even though
  location access is allowed
- **THEN** the map explains that nearby vehicles cannot yet be positioned
  relative to the rider
- **AND** the app does not present proximity-ranked discovery results as if
  location were known

#### Scenario: Live rider location degrades after a successful resolution
- **GIVEN** the map has already resolved a current rider location
- **WHEN** live rider location becomes temporarily unavailable while the map
  remains open
- **THEN** the map keeps using the last resolved rider location as the rider
  position context
- **AND** the capability does not require new vehicle interaction rules based
  on continuous live location updates

### Requirement: Render a rider-centered nearby vehicle snapshot

The app MUST render a snapshot of nearby vehicles on the map using the current
known fleet state and a rider-centered discovery radius rather than requiring
viewport-driven fetching behavior. The exact discovery radius is a design
parameter of the capability and does not need to be fixed by this spec. For
this capability, the minimum required snapshot contents are stable vehicle
identities and vehicle locations.

#### Scenario: Initial fleet snapshot loads successfully
- **GIVEN** the rider has a known location
- **WHEN** the initial nearby vehicle snapshot loads successfully
- **THEN** the map shows the vehicles included in that snapshot at their
  corresponding locations
- **AND** the snapshot is treated as the current known fleet state until a
  newer snapshot replaces it

#### Scenario: Vehicle markers are rendered individually
- **GIVEN** the map is showing a nearby vehicle snapshot
- **WHEN** vehicles are rendered on the map
- **THEN** each visible vehicle in the snapshot is represented as an
  individual vehicle marker
- **AND** clustering or density aggregation behavior is not required by this
  capability

#### Scenario: Vehicles keep stable identities across snapshots
- **GIVEN** a vehicle appears in more than one nearby vehicle snapshot
- **WHEN** the app processes successive snapshots
- **THEN** the vehicle is represented by the same stable vehicle identity
  across those snapshots
- **AND** this capability does not require richer vehicle details beyond
  identity and location

#### Scenario: Successive snapshots may add, remove, or reposition vehicles
- **GIVEN** the map has already shown a nearby vehicle snapshot
- **WHEN** a later snapshot is loaded successfully
- **THEN** vehicles may appear, disappear, or change position between the two
  snapshots
- **AND** the capability does not require animated transitions for those
  snapshot changes

#### Scenario: No nearby vehicles are available in the discovery radius
- **GIVEN** the rider has a known location
- **WHEN** the nearby vehicle snapshot loads successfully with no vehicles in
  the rider-centered discovery radius
- **THEN** the map treats the result as a successful empty discovery state
- **AND** the app does not present the absence of vehicles as a loading or
  failure condition

### Requirement: Refresh the nearby vehicle snapshot

The app MUST support refreshing the nearby vehicle map snapshot after the
initial load while the nearby vehicle map remains visible.

#### Scenario: A successful refresh replaces the previous snapshot
- **GIVEN** the map is showing a previously loaded nearby vehicle snapshot
- **WHEN** a refresh succeeds
- **THEN** the newly loaded snapshot replaces the previous snapshot as the
  current known fleet state

#### Scenario: The map refreshes automatically while visible
- **GIVEN** the map is visible and showing a previously loaded nearby vehicle
  snapshot
- **WHEN** 10 seconds have elapsed since the last successful load or refresh
- **THEN** the app starts a new refresh attempt for the nearby vehicle
  snapshot

#### Scenario: The previous snapshot remains visible during refresh
- **GIVEN** the map is showing a previously loaded nearby vehicle snapshot
- **WHEN** a refresh is in progress
- **THEN** the previous snapshot remains visible until the new snapshot is
  ready
  - **AND** the app indicates that refresh is in progress

### Requirement: Preserve the last successful snapshot within a bounded stale window

The app MUST preserve the last successful nearby vehicle snapshot when a later
refresh attempt fails, but only within a bounded freshness window of 30
seconds.

#### Scenario: Refresh fails after a successful snapshot exists
- **GIVEN** the map is showing a previously loaded nearby vehicle snapshot
- **WHEN** a later refresh attempt fails
- **THEN** the last successful snapshot remains visible
- **AND** the app indicates that the visible snapshot may be stale

#### Scenario: Repeated refresh failure exceeds the freshness window
- **GIVEN** the map is showing the last successful nearby vehicle snapshot
- **WHEN** refresh attempts continue failing until the snapshot exceeds the
  allowed freshness window of 30 seconds
- **THEN** the app stops treating the stale snapshot as a current nearby
  vehicle view
- **AND** the app blocks the map with a failure overlay and indicator that
  makes the outdated snapshot status clear

#### Scenario: Initial snapshot fails before any successful load
- **GIVEN** the rider opens the nearby vehicle map
- **WHEN** the initial nearby vehicle snapshot fails before any successful load
- **THEN** the app blocks the map with a failure overlay and indicator
- **AND** the app does not imply that an unavailable snapshot is current
