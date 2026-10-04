## Purpose

Provide reviewable paired native evidence for named typed and asynchronous consumer fixtures before an iOS bridge transition is considered.

## ADDED Requirements

### Requirement: Identical source-bound native fixtures

The assessment SHALL execute identical named fixture sources against the retained bridge and bridge-unavailable candidate, preserve existing native consumers and identify each phase's source and actual test cases.

#### Scenario: Complete passing pair

- **WHEN** both paths execute the original native tests and every declared fixture case successfully
- **THEN** the record identifies both source snapshots, exact fixture hashes and observed test identities, with candidate bridge absence verified

#### Scenario: Missing fixture or original consumer

- **WHEN** a fixture case, original native consumer or required fixture byte identity is missing or changed
- **THEN** the assessment refuses a parity pass even if the general workflow succeeds

### Requirement: Typed and real asynchronous behavior remains explicit

The assessment MUST retain typed state and generic payload behavior and the observed success, failure, cancellation and controlled continuation-lifetime outcomes at the real Kotlin/native boundary.

#### Scenario: Shared behavior limitation

- **WHEN** both paths exhibit the same cancellation or completion limitation
- **THEN** the record describes bounded equivalence and the retained limitation without crediting a feature fix or universal lifecycle parity

#### Scenario: Candidate behavior differs

- **WHEN** the baseline passes and the candidate fails a behavior assertion for unchanged fixture inputs
- **THEN** the record retains the failure and does not permit a passing transition conclusion

### Requirement: Recovery and independent transition gates

The assessment MUST preserve caller source, verify owned recovery and report replay, and retain unmeasured architecture, operational, platform and release gates separately from the bounded fixture result.

#### Scenario: Cleanup or replay is incomplete

- **WHEN** owned resources are not quiescent or evidence replay fails
- **THEN** the record remains non-passing and retains the owned recovery path without deleting caller work

#### Scenario: Bounded local evidence passes

- **WHEN** fixture evidence, original consumers and recovery replay pass
- **THEN** the result closes only the named local fixture claims and grants no default switch, physical bridge deletion, signed delivery or unmeasured device/onboarding/hosted proof
