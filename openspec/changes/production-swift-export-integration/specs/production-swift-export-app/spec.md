## Purpose

Provide a maintainable production iOS boundary over shared Kotlin behavior, with visible state-evolution failures, coherent native/shared UI ownership and explicit evidence-backed design and adoption decisions.

## ADDED Requirements

### Requirement: Reviewable critical production choices
The integration SHALL record state representation, async ownership, repository concurrency, compiler/build recipe, dependency/diagnostic risk and runtime/adoption choices with alternatives, maintenance costs, source-bound evidence, accountable owner and actual maintainer disposition. Assessment SHALL produce concrete evidence before requesting acceptance. An explicitly provisional integrated candidate MAY implement unresolved choices for code-based review without changing shipping defaults. Production/default adoption MUST require actual disposition; a successful build or completed planning artifact SHALL NOT establish acceptance.

#### Scenario: Proposal and candidate checks are complete
- **WHEN** planning artifacts or isolated candidate checks pass without maintainer disposition of a critical choice
- **THEN** that choice remains review-required; provisional candidate implementation and independent assessments can continue, while production/default adoption remains held

#### Scenario: Maintainer requests review through integrated code
- **WHEN** the maintainer authorizes provisional implementation to understand the trade-offs
- **THEN** the candidate and draft PR identify unresolved decisions beside actual code, demonstrate realistic feature edits and supporting machinery, and preserve the ability to revise or reject the design before adoption

#### Scenario: Candidate cannot meet the maintenance criteria
- **WHEN** the concrete candidate requires another comparable handwritten interop workaround
- **THEN** review records rejection or deferral rather than promoting the workaround as a successful production migration

### Requirement: One authoritative state contract with visible evolution failures
The production state boundary SHALL derive variant discrimination and payload shape from one authoritative contract, preserve shared Kotlin business semantics and reject unsupported or malformed states explicitly. Routine feature evolution MUST NOT require manually synchronized visitor interfaces or numeric-tag registries across languages. Native presentation adaptation SHALL remain distinct from transport bookkeeping. If generated bindings are used, stale or manually altered outputs MUST fail a deterministic repository gate; declaration order MUST NOT define transport identity.

#### Scenario: New state variant with omitted handling
- **WHEN** a shared state gains a variant and a required consumer adaptation is deliberately omitted
- **THEN** compilation or a mandatory deterministic contract gate fails before the application can treat the variant as a valid state, identifying the missing handling

#### Scenario: Payload evolves or a case is removed
- **WHEN** a payload field changes or a case is removed or renamed in an isolated feature-change exercise
- **THEN** the comparison exposes all necessary edits and stale/incomplete mappings, preserves domain behavior and does not require editing parallel transport tables

#### Scenario: Reordered state declarations
- **WHEN** state declarations are reordered without changing meaning
- **THEN** state meaning and native presentation remain unchanged and transport discrimination does not follow ordinal positions

#### Scenario: Unknown or malformed boundary input
- **WHEN** a consumer encounters a version mismatch, unknown variant or invalid payload combination
- **THEN** it receives an explicit boundary failure without silently substituting a known state, dropping the case or exposing a Kotlin exception across an unsupported boundary

### Requirement: Demonstrated maintenance cost before boundary selection
The state-boundary decision SHALL include actual Home and Nearby evolution patches, required edits and declarations, omitted-adaptation failure controls, debugging procedure, generation/upgrade responsibility and removal path. The comparison MUST include effects on native iOS, Android and shared UI. Runtime success alone SHALL NOT establish maintainability.

#### Scenario: State-boundary review
- **WHEN** a production boundary is presented for maintainer decision
- **THEN** the reviewer can inspect a concrete new-variant and payload-change patch, deliberate omission failures and the ongoing ownership cost rather than relying on a hypothetical example or warning count

### Requirement: Enforced isolation and independently owned cleanup
The supported production API SHALL enforce its declared isolation/value boundary and prevent unsupported broader async/error use by callers. Cancellation and retirement SHALL close admission, fence stale results and retain unfinished work in independently owned cleanup. Capacity MUST be released only after actual backend completion; cancelling an acknowledgement waiter MUST NOT cancel cleanup. Remaining generated or linked bridge findings SHALL receive separate disposition rather than being declared unreachable from a source-call audit alone.

#### Scenario: Unsupported API escape
- **WHEN** a caller attempts an unsupported exported operation or allows a mutable Kotlin wrapper to cross the declared asynchronous boundary
- **THEN** a compile or mandatory API/contract gate rejects the use and reports the boundary violation

#### Scenario: Noncooperative work survives cancellation
- **WHEN** a native task is cancelled or a route retires while backend work remains unfinished
- **THEN** stale delivery is fenced, cleanup owns the work and its reservation, and the reservation is released only after actual completion

#### Scenario: Soft shutdown expires or observer cancels
- **WHEN** the observation deadline expires or a shutdown observer is cancelled
- **THEN** unfinished drains remain owned and reported without claiming completion or abandoning cleanup

### Requirement: Coherent native and shared UI app behavior
The integrated app SHALL retain Native Home, Nearby Map and Shared UI using one coherent Kotlin delivery and one app composition root. Native Home and shared Home UI MUST use the exact same shared service instance. All callers of a repository cohort MUST participate in its declared concurrency policy across entry, suspension and resumption. Domain transition/freshness rules SHALL remain shared Kotlin behavior; tab/background transitions SHALL preserve live route ownership.

#### Scenario: Native and shared Home operate concurrently
- **WHEN** Native Home and Shared UI issue work in the integrated app
- **THEN** identity checks establish the same Home service from the same delivery and both retain loading, success, failure, retry and cancellation behavior

#### Scenario: Nearby operations suspend and overlap
- **WHEN** native or Kotlin/shared UI callers access the declared cohort with overlapping suspended operations
- **THEN** all callers obey the reviewed policy and observed repository behavior remains valid without equating Main confinement with whole-operation serialization

#### Scenario: Caller bypasses policy or composition duplicates a graph
- **WHEN** an unguarded cohort caller or a second Kotlin delivery/service graph enters app membership
- **THEN** composition/concurrency qualification fails and identifies the identity or policy violation

### Requirement: Actively checked source-bound build delivery
Production evidence SHALL bind the selected source, configuration, API, complete dependency/tool tuple, module modes, settings, resources and immutable Kotlin delivery. Import/isolation checks MUST have an active negative control and production app compile/link/runtime evidence. Unsupported tuples and unknown diagnostics MUST refuse qualification rather than select fallback profiles or suppress findings. Changed production inputs SHALL receive affected cold and guarded relocated post-cleanup replay qualification with shared UI included.

#### Scenario: Checker is configured but inactive
- **WHEN** a deliberately invalid hidden-type exposure compiles under a supposedly checked recipe
- **THEN** the checker control fails and that recipe receives no checked-import qualification credit

#### Scenario: Production graph differs from hosted pilot
- **WHEN** production membership, Shared UI, compiler flags, tool bytes or dependency inputs differ from retained pilot evidence
- **THEN** affected production checks run against the changed inputs and pilot receipts remain separately scoped historical evidence

#### Scenario: New diagnostic appears
- **WHEN** a source/tuple/emitter/message/location finding lacks a matching disposition
- **THEN** it remains review-required and does not inherit acceptance from a warning-count allowance or a different tuple

### Requirement: Selected dependency attribution and bounded risk decisions
The risk review SHALL attribute the actual selected production graph, distinguish build/runtime/host/embedded surfaces, retain provider authentication and canonical lookup controls, and identify missing coverage. Evidence MUST meet repository freshness policy at decision time. Remediation or exception choices MUST bind exact findings, source, selected artifacts, controls, maintainer, scope, expiry and invalidation triggers. Private JVM temporary storage MUST be verified for every affected launch path and descendant JVM; its control SHALL NOT be credited for unrelated decoder/allocation findings.

#### Scenario: Old exception has different findings or source
- **WHEN** production source, artifacts, findings or scope differ from an existing grant
- **THEN** carry-forward refuses and a fresh remediation or bounded risk decision is required

#### Scenario: Provider answers are empty but coverage is incomplete
- **WHEN** named package queries return no matches while embedded components, host tools or selected graph attribution are missing
- **THEN** the review records those surfaces as incomplete and does not claim clean overall security

#### Scenario: Private temp verification is only a version probe
- **WHEN** a version-only JVM probe passes without observing all affected production launch paths
- **THEN** those launch paths remain unqualified and no decoder/allocation mitigation is inferred

### Requirement: Measured runtime settings and explicit failure behavior
Production limits and observation behavior SHALL be reviewed using actual app navigation, retry, cancellation, native/shared UI overlap, sustained work, retained work and latency/resource measurements. Experimental settings MUST remain provisional until disposition. Admission exhaustion and boundary failures SHALL have explicit native presentation/retry behavior. Energy and memory-byte conclusions MUST use appropriate measurement instruments.

#### Scenario: Fixture limits are reused without measurement
- **WHEN** a candidate supplies fixture constants or increased harness timeouts as production settings without app measurements
- **THEN** settings remain experimental and cannot satisfy production adoption gates

#### Scenario: Capacity is exhausted
- **WHEN** an app owner or parent admission pool has no available capacity
- **THEN** new backend work is not registered and the app presents the reviewed failure/retry behavior without silent loss or unbounded queuing

### Requirement: Exact-scope adoption and complete rollback
Default integration SHALL require explicit maintainer adoption of the exact selected source/configuration/API/profile/policy/settings and target scope after applicable clean-clone, hosted, shared UI, Android parity, physical-device and actual minimum-runtime checks. Credentialed release SHALL remain separately qualified and authorized. Rollback MUST restore a verified complete direct-path content closure including approved native repairs and file modes, with restore/build/test evidence in an owned copy. Switching a flag or restoring a historical revision alone SHALL NOT establish rollback.

#### Scenario: Simulator passes but platform gates remain open
- **WHEN** simulator qualification passes without required actual device, floor-runtime or other target evidence
- **THEN** missing gates stay unqualified and adoption cannot claim those surfaces from simulator success

#### Scenario: Development adoption is approved
- **WHEN** an exact development/unsigned target scope is approved with its required evidence
- **THEN** only that scope switches default and signed release remains held until its separate evidence and authorization exist

#### Scenario: Rollback closure omits the native repair
- **WHEN** selected recovery content lacks the repaired native lock or matching project constraint
- **THEN** rollback verification fails before that content can serve as the adoption checkpoint

### Requirement: One maintained app path after adoption
After approved adoption the repository SHALL consolidate the main app composition, retire obsolete visitor/projection and pilot-only app selection wiring, preserve historical qualification evidence, and document feature development against the selected integration. Repo-owned commands SHALL carry operational behavior through local gates and thin CI. Public Android/iOS identity SHALL remain `studio.mekate.mobi`; the retired hand-maintained iOS Gradle bridge SHALL remain retired and delegated Android bootstrap SHALL be preserved.

#### Scenario: Reader follows the updated feature blueprint
- **WHEN** an architecture reader adds a feature after adoption
- **THEN** the guide describes the selected main-app boundary and its deterministic gates without requiring legacy visitors or a separately maintained pilot application

#### Scenario: Final app closure is inspected
- **WHEN** adopted shipping membership is checked
- **THEN** it contains one maintained app path, preserves all three flows and public identity, and excludes transition-only test controls and obsolete projections
