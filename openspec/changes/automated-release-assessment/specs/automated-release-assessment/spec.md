## Purpose

Provide bounded local release assessments grounded in official upstream evidence and actual Mobi code, with explicit evidence gaps and human adoption decisions.

## ADDED Requirements

### Requirement: Complete local assessment before adoption PR

The system SHALL assess locally and emit one source/patch-bound recommendation packet before requesting adoption approval. It MUST NOT open investigation PRs, adopt dependencies, accept age/risk exceptions or authorize merges, delivery or retirement. Only an explicitly approved, revalidated exact patch may become an adoption PR.

#### Scenario: Missing or changed evidence
- **WHEN** required evidence is absent, stale, incomplete or bound to a different source or patch
- **THEN** the packet is incomplete or blocked and adoption is not recommended or authorized

### Requirement: Official interval and actual usage

Assessment MUST include stable and all prerelease versions in each configured provider's relevant interval, official release/source/documentation changes, actual source and selected-graph applicability, dependency/security provenance and freshness, workaround IDs and supported replacement leads. Truncation and unsupported sources MUST be explicit gaps. Swift export MUST use Kotlin documentation/implementation as primary authority, the official sample as support and relevant YouTrack issues including KT-64572 and KT-80305; a parent closure or release alone MUST NOT qualify retirement.

#### Scenario: Provider interval exceeds bounds
- **WHEN** a page, response or request limit prevents full interval collection
- **THEN** the assessment retains available evidence and identifies incomplete interval coverage

### Requirement: Bounded qualification and resources

Assessment SHALL bound elapsed time, candidate count, concurrency, provider requests, cache lifetime and resources. It SHALL run meaningful change-relevant checks in owned copies, preserve baseline-versus-candidate attribution and verify cleanup before recommending adoption.

#### Scenario: Baseline failure
- **WHEN** unchanged baseline qualification fails
- **THEN** the candidate is not blamed and causal comparison is inconclusive

### Requirement: Reviewable outcomes and operational proof

The existing schedule SHALL be reused without duplicate reminders or private-service requirements. Compact source-bound summaries SHALL be reviewable; raw evidence SHALL remain ignored or retained as CI artifacts. The prerequisite SHALL remain open until an end-to-end automated assessment has been demonstrated; discovery alone MUST NOT close it.

#### Scenario: Assessment operation completes with gaps
- **WHEN** a run produces a packet but one or more required assessment stages are incomplete
- **THEN** the run reports those gaps without claiming adoption readiness or prerequisite completion
