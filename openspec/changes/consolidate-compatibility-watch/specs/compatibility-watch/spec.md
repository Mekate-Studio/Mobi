## Purpose

Turn the existing compatibility watch into a conservative observer of the common evaluator and public upstream release evidence.

## ADDED Requirements

### Requirement: Isolated reviewed evaluation

The watch SHALL call the repository-owned compatibility evaluator with a reviewed tuple, preserve caller inputs, and retain explicit missing capabilities. It MUST NOT adopt versions, lift dependency ceilings or authorize bridge retirement.

#### Scenario: Narrow checks pass
- **WHEN** the watched compile/link profile passes
- **THEN** the report records those cells as passed and leaves mobile/device/release and retirement evidence unproven

### Requirement: Source-bound discovery with failure visibility

The Kotlin adapter SHALL record provider URLs, retrieval times, response digests and release timestamps. Missing or failed provider data MUST remain incomplete and MUST NOT be presented as no updates.

#### Scenario: Provider fails
- **WHEN** a provider times out, rate-limits or returns malformed data
- **THEN** the report identifies the provider gap and cannot report a complete discovery result

### Requirement: Semantic change notification and continuity

The common comparator SHALL exclude volatile execution metadata, verify prior snapshot integrity/scope/age and distinguish capability changes from a changed candidate. Missing or invalid history MUST NOT result in an unchanged verdict. Technical compatibility and notification status SHALL be separate.

#### Scenario: No meaningful change
- **WHEN** valid comparable snapshots have identical capability, release and blocker observations
- **THEN** no notification annotation is emitted, even when timestamps or run IDs differ

#### Scenario: Improvement, regression or blocker changes
- **WHEN** comparable capability evidence improves/regresses or a provider/prerequisite blocker changes
- **THEN** the report describes the changed fields and emits an actionable annotation without authorizing adoption

#### Scenario: History cannot be restored
- **WHEN** a prior snapshot is absent, expired, malformed or from another scope
- **THEN** continuity is explicit and the run establishes a fresh observation instead of claiming no change

### Requirement: Existing schedule and bounded recovery

The integration SHALL preserve the existing schedule/manual trigger, use repo-owned operational scripts and recover/clean only owned rehearsal resources. It MUST retain public-safe evidence and refuse unsafe cleanup.

#### Scenario: Resource ownership is uncertain
- **WHEN** recovery cannot establish quiescence
- **THEN** cleanup is blocked, the report records the failure and no successful operation is reported
