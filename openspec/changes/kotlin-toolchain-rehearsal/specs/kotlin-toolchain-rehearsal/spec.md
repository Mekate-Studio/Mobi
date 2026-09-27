## Purpose

Provide source-bound Kotlin Toolchain input and regression comparisons while
preserving the current iOS bridge, caller state and explicit evidence gaps.

## ADDED Requirements

### Requirement: Explicit upstream target policy
The adapter SHALL offer an opt-in Apple Silicon candidate that removes only
reviewed Intel iOS target declarations in an owned copy. It SHALL preserve ARM
device and simulator main/test graph coverage, the bridge, native app/test targets
and deployment floor. The report SHALL distinguish intentional target exclusions
from missing evidence. Adoption SHALL require a separate maintainer decision.

#### Scenario: Changed source mappings or missing ARM graphs
- **WHEN** candidate target mappings differ from the reviewed shape or required
  ARM device/simulator graph roots or test scopes are absent
- **THEN** rehearsal cannot report successful coverage or alter the caller

### Requirement: Exact candidate preparation
The command SHALL accept only an explicitly reviewed candidate and verify its
consumer wrappers, distribution identity and release-age policy before execution.
Candidate changes SHALL remain confined to an owned copy.

#### Scenario: Wrapper drift or unreviewed version
- **WHEN** prepared bytes differ from their reviewed hash or the version is unknown
- **THEN** rehearsal refuses execution without changing caller source or pins

### Requirement: Effective input evidence
The adapter SHALL capture effective module settings and resolved dependency graphs
for declared modules and test scopes, binding raw outputs and normalized evidence
to exact source and tools. Declarations and upstream defaults SHALL remain distinct
from runtime/artifact proof.

#### Scenario: Missing or unfamiliar graph output
- **WHEN** a required module/target is absent or the output cannot be interpreted
- **THEN** coverage is incomplete and the command cannot certify compatibility

### Requirement: Baseline-first scoped regression
Every comparison SHALL run the unchanged baseline before its candidate using the
same named checks. Input-only success SHALL NOT imply native test/build success.
The native profile SHALL reuse repository-owned jobs with the bridge selected.

#### Scenario: Candidate compiler regression
- **WHEN** the corresponding baseline passes and candidate diagnostics attribute
  failure to the candidate's compiler or test behavior
- **THEN** the result records incompatibility with both sets of retained evidence

#### Scenario: Infrastructure or missing prerequisite
- **WHEN** a required tool/resource is missing or bootstrap/network execution fails
- **THEN** the outcome is incomplete or inconclusive rather than compatible

### Requirement: Native resource ownership
Native execution SHALL isolate phase caches/generated output and journal resource
ownership before creation. Timeout, interruption and recovery SHALL stop only
verified owned processes/devices. Unknown ownership SHALL prevent cleanup.

#### Scenario: Detached JVM or coordinator loss
- **WHEN** a native job leaves a daemon or its coordinator disappears
- **THEN** the same ownership-aware recovery path bounds owned execution and retains
  a non-success result if quiescence cannot be established

#### Scenario: Unrelated simulator or reused process identity
- **WHEN** live identity differs from the recorded owner
- **THEN** the resource remains untouched and recovery reports the uncertainty

### Requirement: Preserve evidence boundaries
Results SHALL list missing graph, provider, platform and packaging coverage and
SHALL NOT authorize adoption, bridge removal or release-default changes.

#### Scenario: Current bridge still builds
- **WHEN** all requested bridge-backed checks pass for a Toolchain candidate
- **THEN** the result certifies only those checks and provides no direct-path or
  bridge-retirement claim
