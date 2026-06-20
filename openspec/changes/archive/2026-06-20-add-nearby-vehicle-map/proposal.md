## Why

`Mobi` is moving from a single sample home flow toward a more realistic
car-sharing product framing. The first capability should stay narrow enough to
explain clearly while still proving that the architecture can support a real
mobile product workflow.

`nearby-vehicle-map` is the first slice that does that. It introduces rider
location context, changing fleet snapshots, timed refresh behavior, stale data
handling, and platform-native map rendering without yet expanding into broader
discovery, reservation, or trip flows.

## What Changes

This change introduces the first map-centric discovery capability for the
car-sharing product framing.

It captures:

- the initial `nearby-vehicle-map` capability requirements
- the shared-state and native-shell design direction for the feature
- the implementation task outline for shared models, feature state, platform
  presentation, and tests

It intentionally defers:

- vehicle list discovery
- richer vehicle details
- clustering
- reservations
- animated map transitions

## Capabilities

### New Capabilities

- `nearby-vehicle-map`: let a rider open a nearby vehicle map, establish rider
  location context, and view refreshable rider-centered vehicle snapshots under
  realistic loading and failure conditions

### Modified Capabilities

- None

## Impact

- `shared-core/`: shared vehicle identity, location, and snapshot domain model
- `shared-feature-nearby-vehicle-map/`: shared state and timing rules for the
  capability
- `android-app/`: native Android map rendering, permission handling, and
  visible-screen refresh scheduling
- `ios-app/`: native iOS map rendering, permission handling, and
  visible-screen refresh scheduling
- `openspec/`: change proposal, design, tasks, and capability delta for the
  new feature
