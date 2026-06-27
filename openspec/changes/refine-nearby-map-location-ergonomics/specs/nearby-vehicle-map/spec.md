## MODIFIED Requirements

### Requirement: Show rider position on the nearby vehicle map

The app MUST establish a precise rider position context for the nearby vehicle
map before claiming that nearby vehicles are being shown. For this capability,
the rider location flow MUST distinguish between resolving the rider's
position, a resolved precise current location, denied or restricted location
access, approximate-only location, and temporary location unavailability. This
capability requires precise location access while the app is in use for nearby
map discovery.

#### Scenario: Rider location is requested when the map opens
- **GIVEN** the rider opens the nearby vehicle map
- **WHEN** the app does not yet have a precise while-in-use rider location
- **THEN** the app starts resolving precise while-in-use rider location without
  requiring a manual in-app "use location" action
- **AND** the app indicates that the rider location is still being resolved
- **AND** the app does not imply that nearby vehicles are already positioned
  relative to the rider

#### Scenario: Rider location is still being resolved
- **GIVEN** the rider opens the nearby vehicle map
- **WHEN** the app has started resolving the rider's current location but has
  not finished yet
- **THEN** the app indicates that the rider location is still being resolved
- **AND** the app does not imply that nearby vehicles are already positioned
  relative to the rider

#### Scenario: Precise rider location is available
- **GIVEN** the rider opens the nearby vehicle map
- **WHEN** the app resolves a precise current rider location
- **THEN** the map shows the rider's current position as the reference point
  for nearby vehicle discovery

#### Scenario: Initial map framing uses the precise rider position
- **GIVEN** the rider opens the nearby vehicle map
- **WHEN** the app resolves a precise current rider location
- **THEN** the initial map framing centers on the rider position
- **AND** the map is presented at a zoom level intended for nearby vehicle
  discovery

#### Scenario: Location access is denied
- **GIVEN** the rider opens the nearby vehicle map
- **WHEN** the app cannot access rider location because location permission has
  been denied
- **THEN** the map explains that precise location access is required to position
  nearby vehicles relative to the rider
- **AND** the app does not present proximity-ranked discovery results as if
  location were known

#### Scenario: Location access is restricted
- **GIVEN** the rider opens the nearby vehicle map
- **WHEN** the platform reports that location access is restricted or location
  services are unavailable
- **THEN** the map explains that precise location cannot currently be used for
  nearby vehicle discovery
- **AND** the app does not present proximity-ranked discovery results as if
  location were known

#### Scenario: Only approximate location is available
- **GIVEN** the rider opens the nearby vehicle map
- **WHEN** the platform only allows approximate or reduced-accuracy location
- **THEN** the map explains that precise location is required for nearby vehicle
  discovery
- **AND** the app does not use the approximate coordinate as the rider-centered
  discovery origin

#### Scenario: Rider location is temporarily unavailable before precise resolution
- **GIVEN** the rider opens the nearby vehicle map
- **WHEN** the app cannot currently determine precise rider location even though
  precise while-in-use location access is allowed
- **THEN** the map explains that nearby vehicles cannot yet be positioned
  relative to the rider
- **AND** the app does not present proximity-ranked discovery results as if
  location were known

#### Scenario: Live rider location degrades after a successful precise resolution
- **GIVEN** the map has already resolved a precise current rider location
- **WHEN** live rider location becomes temporarily unavailable while the map
  remains open
- **THEN** the map keeps using the last resolved precise rider location as the
  rider position context
- **AND** the map indicates that live location is temporarily degraded
- **AND** the capability does not require continuous live location updates for
  the already-visible nearby vehicle snapshot

## ADDED Requirements

### Requirement: Block vehicle actions without trustworthy rider location

The nearby vehicle map MUST keep vehicle action affordances non-actionable when
the app does not have a trustworthy precise rider location context. This applies
to current map interactions and future vehicle actions such as selecting,
reserving, unlocking, or otherwise acting on a visible vehicle.

#### Scenario: Denied location blocks vehicle actions
- **GIVEN** the rider opens the nearby vehicle map
- **WHEN** precise location access is denied
- **THEN** the map presents a blocking location overlay
- **AND** vehicle action affordances are disabled or absent

#### Scenario: Restricted location blocks vehicle actions
- **GIVEN** the rider opens the nearby vehicle map
- **WHEN** location access is restricted or location services are unavailable
- **THEN** the map presents a blocking location overlay
- **AND** vehicle action affordances are disabled or absent

#### Scenario: Approximate location blocks vehicle actions
- **GIVEN** the rider opens the nearby vehicle map
- **WHEN** only approximate or reduced-accuracy location is available
- **THEN** the map presents a blocking location overlay explaining that precise
  location is required
- **AND** vehicle action affordances are disabled or absent

#### Scenario: Temporarily unavailable location blocks actions before first precise fix
- **GIVEN** the rider opens the nearby vehicle map
- **WHEN** the app has not yet resolved any precise rider location and current
  precise location is temporarily unavailable
- **THEN** the map presents a blocking location overlay
- **AND** vehicle action affordances are disabled or absent

#### Scenario: Precise location allows vehicle actions to become eligible
- **GIVEN** the rider opens the nearby vehicle map
- **WHEN** the app resolves a precise rider location and has a trustworthy map
  state
- **THEN** vehicle action affordances are eligible for future vehicle
  interaction capabilities to enable
- **AND** this capability does not itself introduce those vehicle actions
