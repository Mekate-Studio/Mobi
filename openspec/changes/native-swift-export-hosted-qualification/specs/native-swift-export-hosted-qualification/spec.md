## Purpose

Qualify the native Swift-export app pilot on an explicitly requested hosted
runner while preserving source provenance, cleanup evidence and review gates.

## ADDED Requirements

### Requirement: Explicit bounded hosted execution
The repository SHALL expose an opt-in native-only hosted qualification that
checks out the exact requested revision and records its tool and source inputs.

#### Scenario: Requested PR qualification
- **WHEN** the qualification label is present on a PR event
- **THEN** the lane runs against that PR head with read-only permissions and no default switch

#### Scenario: Ordinary PR execution
- **WHEN** a PR lacks the qualification label
- **THEN** the dedicated native qualification does not run

### Requirement: Qualified inputs before production
The command MUST reject dirty source, unsafe evidence paths or incompatible
Ruby, JDK and Apple tool inputs before starting native production.

#### Scenario: Incompatible tool selection
- **WHEN** the selected tool tuple differs from the qualified tuple
- **THEN** the run reports failure without producing or accepting a delivery

#### Scenario: Hosted runtime selection
- **WHEN** the hosted command runs on the Xcode 27 preview image
- **THEN** it explicitly binds simulator major 27 into cold and replay inputs and refuses an absent runtime before production

#### Scenario: Macro enablement on a fresh home
- **WHEN** native package checkout revisions match their locks
- **THEN** only the four named locked macro targets are approved in the disposable home, with macro validation enabled and approval evidence retained

#### Scenario: Macro approval drift
- **WHEN** a required package lock is missing, duplicated or differs from the actual checkout, or its approval path escapes the owned home
- **THEN** approval refuses without changing an unowned approval store

### Requirement: Cold qualification and guarded replay
The command SHALL require passing original and reordered cold app tests, retain
verified deliveries, confirm quiescence and cleanup, then replay the retained
original archive through the existing guarded replay checks.

#### Scenario: Cold work removed
- **WHEN** both cold phases pass and owned disposable work is confirmed removed
- **THEN** replay consumes the verified original archive and retains its own test evidence

#### Scenario: Cold failure or cleanup refusal
- **WHEN** a cold phase fails or recovery cannot confirm cleanup
- **THEN** replay does not begin and the overall qualification cannot pass

### Requirement: Honest retained outcomes
The command MUST retain bounded reports, journals, immutable results, step logs
and available test evidence on success and failure without declaring risk
acceptance or production readiness.

#### Scenario: Incomplete native execution
- **WHEN** execution stops before complete delivery or test evidence exists
- **THEN** available diagnostics are retained and the report identifies the incomplete outcome

#### Scenario: Complete qualification
- **WHEN** all phases, test summaries and cleanup checks pass
- **THEN** the report records qualification passed with production and risk reviews still required
