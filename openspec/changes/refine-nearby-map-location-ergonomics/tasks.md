## 1. Shared Contract

- [x] 1.1 Review `NearbyVehicleMapFeatureState` and presentation mapping for an explicit action-blocked or blocked-location reason that can cover denied, restricted, disabled, approximate-only, and temporarily unavailable-before-fix outcomes.
- [x] 1.2 Replace platform-facing "permission granted" semantics with a product-shaped precise-location outcome that carries a `RiderLocation`.
- [x] 1.3 Preserve existing behavior that keeps the last precise rider location when live location becomes temporarily unavailable after a successful fix.
- [x] 1.4 Add or update shared feature tests for blocked location states and future vehicle action eligibility.

## 2. Android Shell

- [x] 2.1 Make `NearbyVehicleMap` the default Android app destination while preserving restored destination behavior.
- [x] 2.2 Add an Android location adapter that requests while-in-use location when the map becomes visible.
- [x] 2.3 Request and inspect Android precise versus approximate location permission outcomes.
- [x] 2.4 Resolve a current precise rider coordinate and pass it into the nearby map presenter state path.
- [x] 2.5 Map denied, restricted, disabled, approximate-only, and temporary-unavailable outcomes into blocking or degraded shared state.
- [x] 2.6 Remove or demote the manual simulated "Use rider location" production path.
- [x] 2.7 Add Android presenter/UI tests for default destination, precise success, approximate-only blocking, denied blocking, and action-disabled presentation.

## 3. iOS Shell

- [x] 3.1 Make the nearby vehicle map tab the default iOS tab while preserving restored tab behavior.
- [x] 3.2 Add the while-in-use location usage description to `Info.plist`.
- [x] 3.3 Add an iOS Core Location adapter that requests authorization when the map becomes visible.
- [x] 3.4 Require full-accuracy authorization before resolving the rider coordinate as usable for nearby discovery.
- [x] 3.5 Resolve a current precise rider coordinate and pass it into the nearby map TCA feature path.
- [x] 3.6 Map denied, restricted, reduced-accuracy, disabled, and temporary-unavailable outcomes into blocking or degraded shared state.
- [x] 3.7 Remove or demote the manual simulated "Use rider location" production path.
- [x] 3.8 Add iOS reducer/view-model tests for default tab, precise success, reduced-accuracy blocking, denied or restricted blocking, and action-disabled presentation.

## 4. Validation

- [ ] 4.1 Run the nearby vehicle map shared feature tests.
- [ ] 4.2 Run the Android test job that covers the nearby map presenter and app shell behavior.
- [ ] 4.3 Run the iOS test job that covers the nearby map reducer and tab behavior.
- [ ] 4.4 Run the README smoke path jobs affected by Android and iOS shell changes.
- [x] 4.5 Validate the OpenSpec change before implementation is considered complete.
