## 1. Shared Domain Tests First

- [x] 1.1 Add shared tests for vehicle identity, vehicle location, rider
  location, and fleet snapshot behavior
- [x] 1.2 Add shared tests for empty-success snapshots, changing successive
  snapshots, and transient repository failure behavior

## 2. Shared Domain And Simulation Implementation

- [x] 2.1 Add shared domain types for vehicle identity, vehicle location,
  nearby vehicles, fleet snapshots, and rider location
- [x] 2.2 Add a simulated fleet repository seam that can produce rider-centered
  snapshots with stable vehicle identities and changing vehicle positions

## 3. Shared Feature Tests First

- [x] 3.1 Add shared tests for rider location transitions, snapshot refresh,
  stale-window behavior, and blocking failure overlays
- [x] 3.2 Add shared tests for keeping the last resolved rider location when
  live location temporarily degrades

## 4. Shared Feature Implementation

- [x] 4.1 Create the `shared-feature-nearby-vehicle-map` module
- [x] 4.2 Implement typed rider location, snapshot, and overlay states
- [x] 4.3 Implement shared timing and stale-window rules for refresh every 10
  seconds and blocking failure after 30 seconds of staleness

## 5. Android Native Shell TDD

- [x] 5.1 Add Android tests for permission wiring, visible-screen refresh
  scheduling, and overlay presentation
- [x] 5.2 Add Android map presentation and location permission handling for the
  nearby vehicle map
- [x] 5.3 Wire visible-screen refresh scheduling and overlay rendering on
  Android

## 6. iOS Native Shell TDD

- [x] 6.1 Add iOS tests for permission wiring, visible-screen refresh
  scheduling, and overlay presentation
- [x] 6.2 Add iOS map presentation and location permission handling for the
  nearby vehicle map
- [x] 6.3 Wire visible-screen refresh scheduling and overlay rendering on iOS

## 7. Documentation And Cleanup

- [x] 7.1 Update architecture documentation where needed after the feature
  shape is implemented
