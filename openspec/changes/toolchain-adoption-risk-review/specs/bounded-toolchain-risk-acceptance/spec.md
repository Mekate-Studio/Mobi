## Purpose

Make an explicit maintainer decision to carry inherited Toolchain risks auditable, bounded and independent of evidence completeness and bridge-retirement approval.

## ADDED Requirements

### Requirement: Exact residual-risk scope
A manual adoption review SHALL preserve every finding and severity and SHALL accept risk only for explicitly approved advisory/component/artifact-hash tuples bound to the reviewed Toolchain distribution and adoption patch. It MUST report accepted risk separately from verified remediation.

#### Scenario: Known inherited finding
- **WHEN** a fresh complete review matches an approved exact tuple within its decision scope
- **THEN** the review reports accepted residual risk while retaining the original advisory and severity

#### Scenario: Changed or new input
- **WHEN** an advisory, selected version, artifact hash, distribution or patch differs from approval
- **THEN** adoption refuses the acceptance and requires a new review

### Requirement: Explicit approval and bounded validity
A residual-risk decision MUST contain explicit maintainer approval, a reason, source and patch identities, covered operations, controls, start and expiry timestamps. Pending, expired, revoked or future decisions SHALL refuse adoption. This proposal recommends a maximum 30-day window; that duration is subject to maintainer approval.

#### Scenario: Expired decision
- **WHEN** the decision has expired or remains pending
- **THEN** adoption remains blocked and the report preserves the unresolved findings

### Requirement: Independent gates
Risk acceptance SHALL NOT waive unknown-severity triage, missing attribution, fresh complete release/advisory collection, functional capability checks or release age. An early-age exception MUST name the exact release and publication/decision timestamps and be approved separately. Neither exception SHALL authorize release delivery or bridge switching/deletion.

#### Scenario: Young release without age approval
- **WHEN** accepted inherited findings coexist with a release younger than seven days and no age exception
- **THEN** production adoption remains blocked while isolated rehearsal remains available

#### Scenario: Incomplete coverage
- **WHEN** provider responses, selected input attribution or required adoption checks are incomplete
- **THEN** a risk decision does not convert that evidence into a passing result

### Requirement: Retirement remains independently measured
After validated Toolchain adoption the workflow SHALL prioritize fresh direct-path evidence against the adopted tuple with the bridge unavailable, preserving native consumers and relevant operational capabilities. A default switch and physical deletion MUST require separate reviewable changes and decisions.

#### Scenario: Retained-bridge checks pass
- **WHEN** an accepted-risk adoption passes retained-bridge native checks
- **THEN** no direct-path or bridge-retirement capability is credited from those results
