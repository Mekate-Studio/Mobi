## Purpose

Supply bounded, source-bound evidence about Jetifier conditions in generated Android builds so dependency review can distinguish observed behavior from unknown exposure.

## ADDED Requirements

### Requirement: Effective condition observation
The assessment SHALL capture effective Jetifier boolean settings, their observed producer and relevant generated Android build/project scope. Unsupported, absent or malformed observations MUST remain incomplete and MUST NOT become false.

#### Scenario: Effective setting is measured
- **WHEN** a supported Android project exposes an effective setting
- **THEN** its boolean value and explicit-property presence are retained separately with producer identities

#### Scenario: Observation is unavailable
- **WHEN** the effective option API is unavailable or the Android scope is missing
- **THEN** condition review is incomplete without an inferred default

### Requirement: Transform evidence retains its limits
The assessment SHALL identify its observation interval, observer support, executed transform records and available input identities. A disabled setting or an empty event list MUST NOT prove universal parser unreachability.

#### Scenario: Disabled bounded build
- **WHEN** supported observation spans a successful generated build with disabled settings and no observed Jetifier execution
- **THEN** review reports a bounded disabled condition without clearing the advisory

#### Scenario: Enabled or unsupported transform path
- **WHEN** execution/input identity is missing, unsupported or contradictory
- **THEN** review requires further evidence rather than granting mitigation credit

### Requirement: Replay and isolation
Condition review SHALL bind original graph producer bytes and refuse malformed, altered or unsafe evidence. Historical receipts without condition fields SHALL retain their original scope and report this new capability as unmeasured. Rehearsal MUST use owned resources with existing recovery and cleanup and MUST NOT authorize dependency adoption.

#### Scenario: Historical graph receipt
- **WHEN** a valid older graph has no condition observation
- **THEN** original graph validation remains valid and condition state is unmeasured

#### Scenario: Source-bound fresh pair
- **WHEN** both phases carry complete supported observations
- **THEN** their independent results are reported with graph/source identities and no adoption authorization
