## Purpose

Collect reproducible retained-bridge validation for a reviewed Toolchain upgrade without changing production or granting adoption.

## ADDED Requirements

### Requirement: Explicit native and packaging evidence
Rehearsals SHALL compare baseline and candidate in owned workspaces, retain the Gradle bridge and Xcode targets, bind simulator major and macro validation, and report unsigned packaging separately from signed release readiness.

#### Scenario: Candidate native validation
- **WHEN** a reviewed candidate is rehearsed with the mobile profile
- **THEN** both phases execute repository Android and Xcode app/test jobs with macro validation enabled and an owned simulator of the declared minimum major.

#### Scenario: Unsigned packaging
- **WHEN** packaging is rehearsed without production signing credentials
- **THEN** produced artifacts are fingerprinted and signed export, delivery and device execution remain unproven.

### Requirement: Honest adoption limits
The assessment SHALL distinguish passed, failed, infrastructure-inconclusive and untested gates, retain release-age and advisory blockers, and prohibit automatic adoption.

#### Scenario: Green rehearsal with unresolved risks
- **WHEN** commands pass but advisories or release age remain unresolved
- **THEN** the assessment still requires review and grants no adoption or bridge-retirement authority.

### Requirement: Version-bound plugin attribution
The existing independent resolver SHALL select reviewed mappings per executed Toolchain version and join resolved artifact bytes to the retained upstream compiler invocations without transferring older attribution automatically.

#### Scenario: Candidate attribution
- **WHEN** the reviewed upstream producer pair and bundled attribution are complete
- **THEN** each phase uses its own version-bound mapping and the advisory lookup includes verified bundled queries and newly attributed candidate plugins.

#### Scenario: Unsupported mapping
- **WHEN** the version, pinned mapping sources or resolver distribution differs from the reviewed mapping
- **THEN** attribution refuses and supplies no passing adoption evidence.
