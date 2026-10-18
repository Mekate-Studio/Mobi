## Purpose

Provide an explicitly selected Swift export configuration of the real Mobi app with reviewable concurrency, lifetime, measurement, provenance and rollback contracts, independently of production adoption.

## ADDED Requirements

### Requirement: Explicit isolated pilot selection
The repository SHALL expose an alternate app configuration and repo-owned build/test command requiring explicit language profile, repository policy, runtime settings and optional shared UI selection. Invalid or missing selections MUST refuse without fallback. Default smoke commands, public identity, delegated Android bootstrap and retired iOS bridge status SHALL remain intact.

#### Scenario: Explicit pilot invocation
- **WHEN** a valid pilot build or test is requested
- **THEN** the selected configuration and output roots are recorded and the default configuration is not rewritten

#### Scenario: Invalid selection
- **WHEN** a selection is missing, unknown or inconsistent with delivery inputs
- **THEN** execution refuses before producing or consuming an app delivery

### Requirement: Coherent real app delivery
Each app configuration SHALL consume one coherent Kotlin delivery and one app composition root. Native Home and optional shared Home UI MUST share the same Home service instance; Nearby owners MUST share the declared repository cohort. The pilot SHALL exercise real Home and Nearby behavior and exclude scripted diagnostic scenarios, test gates and constant test clocks from shipping membership.

#### Scenario: Native and optional shared Home
- **WHEN** the pilot runs Native Home and enables shared UI
- **THEN** both routes consume the exact shared Home service from the selected delivery and retain real loading, success, failure and retry behavior

#### Scenario: Real Nearby navigation
- **WHEN** users enter Nearby, change location permission, refresh or leave and re-enter a route
- **THEN** real location/time inputs drive existing map state and rendering contracts through the declared cohort without a second linked Kotlin delivery

#### Scenario: Shared UI disabled
- **WHEN** the pilot is built with shared UI disabled
- **THEN** native Home and Nearby remain usable and shared route sources/dependencies follow the declared disabled closure

### Requirement: Complete cohort concurrency contract
The pilot SHALL record every caller of the exact repository cohort, including native, Kotlin and optional shared UI access, and refuse qualification with unguarded access. Main confinement MUST cover entry and resumption while explicitly allowing suspension overlap. Complete-operation serialization, when selected, MUST use one shared cohort policy across suspension and delegate return.

#### Scenario: Overlapping suspended refreshes
- **WHEN** two cohort refreshes suspend and resume under main confinement
- **THEN** entry/resumption remains on Main and observed interleavings are checked for repository safety without claiming whole-operation serialization

#### Scenario: Escaping cohort access
- **WHEN** a raw caller bypasses the declared policy or accesses another repository instance as though it were the same cohort
- **THEN** cohort qualification refuses and identifies the caller and instance boundary

### Requirement: Owned retirement and cancellation
The pilot SHALL close business admission on retirement, fence stale delivery, retain unfinished work in parent-owned cleanup, and release reservations only after actual completion. Parent admission and per-owner Kotlin jobs MUST be accounted separately. Tab and background transitions SHALL preserve live route ownership; soft shutdown SHALL report unfinished drains without claiming backend completion.

#### Scenario: Cancellation with noncooperative work
- **WHEN** a route cancels or retires while Kotlin work remains unfinished
- **THEN** stale results do not reach the route, cleanup retains the work and its reservation, and capacity is restored only on actual completion

#### Scenario: Soft deadline or cancelled waiter
- **WHEN** shutdown reaches its soft deadline or an acknowledgement waiter is cancelled
- **THEN** unfinished work remains owned, still-draining status is available, and cleanup is not cancelled by the waiter

#### Scenario: Capacity exhausted
- **WHEN** parent admission or an owner's job limit is exhausted
- **THEN** work refuses before backend registration and the real app exposes reviewed busy/retry behavior

### Requirement: Measured runtime and diagnostic decisions
A qualified pilot SHALL require a versioned reviewed settings record bound to actual app measurements for reservations, jobs, polling/backoff, shutdown and retry behavior. Experimental runs MUST label provisional settings and SHALL NOT silently copy diagnostic constants as approved limits. Diagnostic dispositions MUST bind exact tuple/profile/target/emitter/message/location fingerprints; unknown findings SHALL retain review-required status and compiler errors/native Swift 6 warnings SHALL fail.

#### Scenario: Provisional measurement run
- **WHEN** experimental settings are used to measure app behavior
- **THEN** results remain provisional until limits and rationale are explicitly reviewed, including cancellation, retry, retention and sustained polling observations

#### Scenario: New diagnostic or changed tuple
- **WHEN** an unknown finding or changed compiler/dependency input is observed
- **THEN** existing dispositions cannot silently cover it and applicable qualification/review is required

### Requirement: Bounded source-bound evidence
Pilot receipts SHALL identify source/configuration, delivery, descriptor, installed compiler tuple, per-module language modes, native inputs, settings, diagnostics and test/resource results. Changed promoted sources MUST receive applicable cold production and guarded post-cleanup replay. Swift 5 support consumed by Swift 6 SHALL be described as language-mode qualification on the installed compiler, without historical compiler, stable ABI or library-evolution claims.

#### Scenario: Promoted app source differs from rehearsal
- **WHEN** reusable rehearsal code is promoted or composition inputs change
- **THEN** historical fixture success is retained separately and new integrated app qualification binds the changed inputs

#### Scenario: Local pilot passes
- **WHEN** local simulator build/tests and replay pass
- **THEN** published clean clone, hosted, physical device, minimum runtime, Android parity, advisory and release/signing gates remain independently recorded as qualified, deferred, failed or unqualified

#### Scenario: Default raw evidence and refused wrapper
- **WHEN** the existing default raw build and twelve-test result are referenced
- **THEN** their passing scope is reported separately from the refused assessment wrapper receipt

### Requirement: Complete repaired content rollback
Before implementation the pilot SHALL retain and verify a fresh complete direct-path rollback snapshot containing current dirty/untracked source, required input closure, file modes, hash inventory, repaired native lock and matching Xcode constraint. Evidence MUST remain retained separately. Restoring into an owned copy and validating direct build/tests SHALL establish rollback evidence; selecting a flag or historical revision alone SHALL NOT establish restoration.

#### Scenario: Historical baseline lacks approved repair
- **WHEN** rollback content is selected
- **THEN** SwiftSyntax 603.0.2, Perception 2.0.10 and the matching Xcode constraint are included and hash verified rather than relying solely on the historical baseline revision

#### Scenario: Source changes after snapshot
- **WHEN** direct-path inputs change before pilot implementation begins
- **THEN** the snapshot is refreshed and restore verification is repeated before it can serve as the implementation rollback baseline
