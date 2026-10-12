## Purpose

Provide a reproducible, explicitly selected Swift export candidate for Mobi, with complete package identity, safe publication and honest native ownership and integration review boundaries.

## ADDED Requirements

### Requirement: Explicit opt-in language and input contract

The candidate MUST require a named language profile and versioned input descriptor, support both the support-only Swift 5 and all-generated Swift 5 profiles with Swift 6 aliases/native consumers, and bind source, exporter, compiler, target, module, schema, native dependency and resource identities. Candidate generation MUST leave production source and builder defaults unchanged.

#### Scenario: Missing or unknown profile

- **WHEN** an invocation omits its profile or selects an unknown profile
- **THEN** the candidate refuses before generation/publication and leaves the current delivery unchanged

#### Scenario: Both measured language options

- **WHEN** each supported profile is rehearsed with the same declared source and repository policy
- **THEN** receipts identify every generated module's language mode and the Swift 6 consumer mode without selecting a production default

#### Scenario: Input changes at an unchanged path

- **WHEN** a declared source, generator, dependency, schema or compiler setting changes while its path remains the same
- **THEN** prior input identity cannot qualify the new delivery and the changed tuple requires applicable fresh evidence

### Requirement: Complete relocatable delivery

A published delivery MUST contain the complete declared export/native consumer closure, relative package references, exact member hashes and separate producer/consumer provenance. Consumers MUST reject missing, changed, unexpected or escaped members before using a delivery. Source-package replay MUST NOT be described as SwiftPM binary-distribution compatibility.

#### Scenario: Corrupted or stale delivery

- **WHEN** a generated member, archive, alias, resource or contract is missing or altered, an unexpected member appears, or a reference escapes the delivery
- **THEN** publication/consumption refuses with a specific finding and cannot silently treat the altered bytes as the previous complete delivery

#### Scenario: Relocated source package

- **WHEN** a retained delivery is copied to a new owned location and its original producer workspace is unavailable
- **THEN** the declared consumer can compile/link from the relocated closure and records its compiler-specific products without requiring original assessment paths

### Requirement: Fenced atomic publication and pinned readers

Publication MUST expose one complete immutable generation at a time, reject stale expected generations and preserve pinned older objects while readers use them. Reader registration and collection eligibility MUST share a consistent serialization boundary.

#### Scenario: Writer interruption

- **WHEN** a writer is interrupted during staging, after installing an object or after committing the active pointer
- **THEN** consumers see a complete old or complete committed new delivery and no partial selected graph

#### Scenario: Concurrent or ABA writer

- **WHEN** writers compete for the same expected generation or a stale writer returns after identical bytes are published again
- **THEN** only the current expected generation can publish and stale writers cannot replace the newer selection

#### Scenario: Reader held across publication

- **WHEN** a reader pins an old generation and a new complete generation is selected
- **THEN** that reader continues using its verified old object until it releases its pin

### Requirement: Conservative collection and declared responsibility

The candidate MUST report collection eligibility before deletion, protect active, pinned, held, retained-reference and uncertain-ownership objects, and require positively verified recovery before removing crashed reader pins. Storage/age settings and maintenance responsibilities MUST be declared; an unmet budget MUST NOT justify deleting protected objects.

#### Scenario: Reader or evidence protects an old object

- **WHEN** an old object is pinned by a live or uncertain reader, held for review or referenced by retained evidence
- **THEN** collection marks it ineligible regardless of age and leaves it intact

#### Scenario: Crashed reader recovery

- **WHEN** a reader exits unexpectedly
- **THEN** its pin is removed only after ownership-aware recovery proves the associated resource/process quiescent

#### Scenario: Storage budget exhausted by protected objects

- **WHEN** the configured storage budget cannot admit another delivery without protected deletion
- **THEN** publication refuses with a capacity report rather than evicting protected content

### Requirement: Native ownership and repository access contract

An integrated candidate fixture MUST explicitly declare parent/route lifetimes, share the exact Home service across native and Compose peers, and apply one declared access policy to every caller of the exact Nearby repository cohort. Both Main confinement and shared complete-operation mutex policies MUST remain available for comparison. Business calls after retirement MUST refuse while idempotent cleanup remains available; native payloads and wire schema handling MUST be validated at the language boundary.

#### Scenario: Peer route teardown

- **WHEN** one route is destroyed while a peer still uses the shared Home service
- **THEN** the retired route admits no new business work, late delivery is fenced, and the peer service remains usable

#### Scenario: Repository access bypass

- **WHEN** a caller to a shared repository is not covered by the declared confinement or shared-lock policy
- **THEN** the access audit is incomplete and cannot qualify that policy for integration

#### Scenario: Unknown or reordered wire values

- **WHEN** Kotlin enum order changes or an unknown schema/tag/payload reaches native copying
- **THEN** stable named mappings preserve known meanings or produce explicit rejection without leaking result capabilities

#### Scenario: Foreign-executor client use

- **WHEN** a caller attempts to use a main-executor-only native client from another executor
- **THEN** the declared API prevents it or uses an independently validated safe path; an unchecked actor assumption alone cannot qualify unrestricted use

### Requirement: Cancellation completion and capacity remain distinct

The fixture MUST distinguish caller cancellation, UI recovery, delivery fencing, retained drain ownership and actual backend completion. It MUST retain unfinished request/lease accounting through cancellation and soft shutdown deadlines, restore only matching native request state, and release accounting exactly once after real completion. Route capacity MUST NOT be reported as a general Kotlin job bound.

#### Scenario: Noncooperative cancellation and soft deadline

- **WHEN** a cancelled backend job remains noncooperative after the configured shutdown observation deadline
- **THEN** the caller/UI can recover, shutdown reports stillDraining, and a separately owned drain retains its request/lease until actual completion

#### Scenario: Copy failure after consume

- **WHEN** native payload validation fails after a backend result has been consumed
- **THEN** the result capability is released and prior UI state restored without inventing an outstanding request to drain

#### Scenario: Compose launches exceed declared job admission

- **WHEN** a Compose owner receives overlapping launches beyond its declared per-owner job limit
- **THEN** excess work refuses before backend registration/launch; that job limit has independent evidence from coarse route reservations

#### Scenario: Busy retry and closed roots

- **WHEN** capacity is full, a duplicate/stale retry arrives or the parent session is closed
- **THEN** denial accepts no backend work, manual retry can admit at most one owner after capacity actually returns, stale controls cannot revive disposed routes, and closed roots remain terminal

### Requirement: Visible diagnostics and independent integration review

Compiler errors and native Swift 6 compile warnings MUST fail. Generated and runtime diagnostics MUST retain tuple/emitter/message identity and require explicit review for new or changed findings. Candidate success MUST NOT imply approval of unresolved compatibility risk, production configuration, hosted/device/release gates or adoption.

#### Scenario: Inheritance warning opt-in

- **WHEN** an opt-in suppresses the generated coroutine inheritance diagnostic without establishing a compatible bridge contract
- **THEN** the compatibility finding remains unresolved and cannot qualify adoption solely from warning suppression

#### Scenario: New finding with unchanged total count

- **WHEN** a diagnostic message, location/emitter input or target contract changes while the warning count stays constant
- **THEN** the candidate requires review rather than passing from a count threshold

#### Scenario: Unselected integration decisions

- **WHEN** candidate tests pass but a production profile, repository policy, maintenance owner, numeric runtime limits or diagnostic disposition is unselected
- **THEN** the report remains review_required and production wiring/default changes are not applied

### Requirement: Maintained source-to-app qualification and replay

Qualification MUST rebuild from public source and declared locked producer/native inputs in owned workspaces, disclose warm/host cache use, then compile/link/run fresh consumers after original disposable workspaces are removed. Reports MUST preserve incomplete/failed checks and separate simulator scope from other platform/security/delivery gates.

#### Scenario: Only assessment binary seeds available

- **WHEN** a run uses retained assessment producer/native products instead of building the maintained candidate from its declared public inputs
- **THEN** it reports bounded warm-replay evidence and cannot claim maintained cold source-to-app qualification

#### Scenario: Passing local replay with external gates open

- **WHEN** owned local generation/app/replay checks pass but device, minimum-runtime, hosted, Android parity, release or advisory checks are unrun
- **THEN** those gates remain explicitly open and the passing local evidence is preserved without a general production-readiness claim
