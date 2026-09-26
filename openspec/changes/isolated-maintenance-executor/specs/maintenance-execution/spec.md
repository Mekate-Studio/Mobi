## Purpose

Provide repeatable baseline/candidate maintenance checks whose evidence remains
source-bound and whose owned resources can be inspected and safely recovered.

## ADDED Requirements

### Requirement: Comparable isolated runs
Execution SHALL preserve caller source and Git state, bind exact source, patch,
check, policy and tool identities, and use independent baseline/candidate copies.
Candidate execution SHALL require a passing baseline using the same check plan.

#### Scenario: Baseline fails
- **WHEN** any required baseline check fails
- **THEN** candidate execution does not start and the comparison is inconclusive

#### Scenario: Source or candidate identity changes
- **WHEN** caller/source/check/policy bytes drift or a candidate preimage mismatches
- **THEN** execution refuses a successful comparison and retains the evidence

### Requirement: Durable typed outcomes
Each run SHALL record atomic versioned outcomes and append-only lifecycle events.
Malformed or missing check output SHALL fail even when a child exits zero.
Passing checks SHALL NOT authorize adoption or imply untested native capabilities.

#### Scenario: Candidate regression
- **WHEN** comparable baseline checks pass and candidate output attributes a regression
- **THEN** the result is incompatible and preserves both sets of check evidence

#### Scenario: Incomplete execution
- **WHEN** prerequisites are missing, output is malformed, or execution is interrupted
- **THEN** a distinct non-success state and failure point remain reviewable

### Requirement: Verified process and resource ownership
Resources SHALL be journaled before creation. Processes SHALL have bounded
execution and ownership stronger than a PID before cleanup signals are sent.
Caller credentials, shared caches and Git hooks SHALL NOT be inherited.

#### Scenario: Timeout or coordinator loss
- **WHEN** a check exceeds its deadline or its coordinator disappears
- **THEN** owned execution stops within bounded grace and no passing receipt is issued

#### Scenario: Reused PID or uncertain resource
- **WHEN** recorded process identity, ownership marker or canonical path disagrees
- **THEN** recovery reports the uncertainty without signaling or deleting that resource

### Requirement: Conservative recovery and cleanup
Recovery SHALL inspect retained state without resuming partial candidate work.
Cleanup SHALL default to a dry run, respect active leases and review holds,
validate ownership, and preserve failure history and result evidence.

#### Scenario: Concurrent or held run
- **WHEN** cleanup targets an active or review-held run
- **THEN** deletion is refused even when retention has elapsed

#### Scenario: Interrupted cleanup
- **WHEN** deleting an owned disposable directory fails partway through
- **THEN** cleanup failure is recorded separately and a retry is idempotent

### Requirement: Independent adapter contracts
The common executor SHALL support independently executable Kotlin and Elixir
fixtures without requiring mobile SDKs, backend tools, services or private access.
Unsupported real resource types SHALL remain explicit missing capabilities.

#### Scenario: Dormant backend fixture
- **WHEN** the Elixir contract fixture executes
- **THEN** only owned fixture resources are used and no backend is activated
