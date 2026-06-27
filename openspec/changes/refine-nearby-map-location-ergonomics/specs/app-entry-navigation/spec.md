## ADDED Requirements

### Requirement: Open the nearby vehicle map by default

The app MUST select the nearby vehicle map as the default destination when a
rider enters the app from a normal launch path.

#### Scenario: Android opens to nearby map
- **WHEN** the Android app is launched without a deep link or restored
  destination
- **THEN** the nearby vehicle map is the selected app destination
- **AND** the native home and shared UI destinations remain reachable through
  app navigation

#### Scenario: iOS opens to nearby map
- **WHEN** the iOS app is launched without a deep link or restored destination
- **THEN** the nearby vehicle map tab is selected
- **AND** the native home and shared UI tabs remain reachable through app
  navigation

#### Scenario: Restored destination is preserved
- **GIVEN** the platform restores a previously selected destination
- **WHEN** the app process is recreated
- **THEN** the platform-restored destination remains selected instead of
  forcing the nearby vehicle map again
