## Purpose

Provide source-bound local evidence that an isolated direct iOS build propagates a Kotlin change into Swift and can restore the retained bridge without reusing direct products.

## ADDED Requirements

### Requirement: Isolated direct incremental validation
The manual profile SHALL run an unchanged baseline first, preserve native app/test targets and original tests, and make the hand-maintained bridge unavailable during the candidate's direct checks. It SHALL test a changed Kotlin implementation through a native Swift expectation with caches/products retained and record source, command, test and framework identities.

#### Scenario: Changed implementation reaches Swift
- **WHEN** initial direct native checks and the changed native expectation pass and measured framework bytes change
- **THEN** the report records bounded local incremental evidence with its verified references

#### Scenario: Stale or missing direct evidence
- **WHEN** the native probe is absent, framework identities are missing/unchanged or required checks did not execute
- **THEN** the result cannot close incremental evidence or authorize a transition

### Requirement: Validated bridge restoration
The profile MUST validate authored preimages and path/mode identities before restoring the original owned copy. It SHALL remove experiment additions, restore deleted bridge inputs and executable modes, clear owned generated products and rerun native bridge tests/build. Restored source identity MUST equal the original source manifest.

#### Scenario: Exact restoration and rebuilt native consumers
- **WHEN** restored inputs match the original identity and original native tests/build pass after clearing direct products
- **THEN** local rollback evidence is recorded separately from direct success

#### Scenario: Unexpected content or path drift
- **WHEN** authored content/modes drift, the bridge reappears early or a restoration output path is symlinked
- **THEN** restoration refuses before overwriting those inputs and owned evidence remains recoverable

### Requirement: Capability and decision boundaries
The report SHALL verify stage receipt chains and keep unexecuted device, release, lifecycle, generic, onboarding and hosted gates explicit. It MUST retain adoption authorization as false and SHALL leave production defaults, dependencies, bridge files and schedules unchanged.

#### Scenario: Local round trip passes
- **WHEN** all named local round-trip checks pass
- **THEN** only their bounded capabilities pass and bridge retirement remains deferred

#### Scenario: Failure or interruption
- **WHEN** any stage fails, times out or is interrupted
- **THEN** no complete round-trip pass is recorded and existing resource recovery/cleanup remains available
