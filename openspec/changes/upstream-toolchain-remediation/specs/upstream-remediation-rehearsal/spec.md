## Purpose

Provide a reproducible upstream Toolchain comparison using selected build inputs and explicit failure states, while keeping adoption and architectural retirement independent.

## ADDED Requirements

### Requirement: Rehearse a reviewed candidate in isolation
The workflow SHALL execute a pinned baseline before a separately copied pinned candidate, bind source/configuration/commands/results, collect reviewed module and delegated build inputs, and preserve caller files, index and HEAD. Age-blocked releases MUST require explicit experimental mode and retain an adoption-age gap.

#### Scenario: Young candidate
- **WHEN** a release has not reached the configured age threshold
- **THEN** normal execution refuses it and explicit experimental execution retains the age limitation

#### Scenario: Candidate failure
- **WHEN** the baseline passes and candidate behavior fails
- **THEN** the workflow preserves the diagnostic and distinguishes a causal incompatibility from infrastructure uncertainty without adopting changes

### Requirement: Separate remediation and architecture evidence
The workflow SHALL compare exact selected Maven inputs using fresh provider receipts and retain unresolved findings. SwiftPM capability observations MUST be source-bound and MUST NOT satisfy unexecuted Xcode, interop, release, onboarding or bridge-retirement gates.

#### Scenario: Announcement or unchanged inputs
- **WHEN** a release announces SwiftPM support or changes a compiler default without replacing affected selected inputs
- **THEN** the workflow retains the relevant compatibility/advisory gaps and requires capability-specific rehearsal

#### Scenario: Cleanup
- **WHEN** execution finishes or fails
- **THEN** recovery and owned cleanup are independently reportable and retained producer evidence remains reviewable

#### Scenario: Opaque bundled inputs
- **WHEN** a candidate replaces named Maven components with bundled file dependencies
- **THEN** the workflow reports the loss of identity, permits only unique exact artifact byte references from verified baseline producers, binds the derivation implementation, and retains incomplete attribution rather than claiming remediation from fewer provider matches
