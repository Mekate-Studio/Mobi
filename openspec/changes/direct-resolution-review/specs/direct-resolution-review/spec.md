## Purpose

Establish repeatable evidence for the dependency surface of an isolated direct Toolchain candidate without inferring bridge retirement readiness.

## ADDED Requirements

### Requirement: Direct graph collection preserves capability boundaries
The workflow SHALL collect paired baseline and bridge-unavailable candidate module/test compile/runtime dependency graphs and downloaded fingerprints in owned isolation. Reports MUST refuse missing declared target coverage and MUST retain unexecuted native, plugin, release and onboarding capabilities.

#### Scenario: Graph-only execution passes
- **WHEN** both phases resolve their declared module and platform roots
- **THEN** the report records graph evidence and marks application and native checks as unexecuted without changing production defaults

#### Scenario: Evidence omits a target
- **WHEN** an otherwise passing graph omits a declared platform in a required usage or scope
- **THEN** the report refuses the incomplete graph

### Requirement: Advisory evidence uses exact resolved inputs
The workflow SHALL generate distinct Maven package/version queries from selected nonconstraint graph coordinates. Provider responses MUST bind to those queries and the verified execution result, retain response hashes and retrieval times, and distinguish provider completeness from dependency-surface completeness and finding triage.

#### Scenario: Provider response is incomplete
- **WHEN** a request fails or response cardinality or pagination is incomplete
- **THEN** the review preserves available receipts and reports incomplete coverage rather than no vulnerabilities

#### Scenario: Provider returns an advisory
- **WHEN** the provider returns a finding for an exact selected package/version
- **THEN** the report retains the finding identity and requires human exposure and severity triage without authorizing adoption

### Requirement: Reports verify retained evidence
The workflow SHALL verify file digests, replay graph parsing against captured output and preserve limitations for compiler artifacts, delegated build systems, shaded internals and other ecosystem dependencies. Recovery and cleanup MUST use existing ownership checks.

#### Scenario: Coherent metadata forgery
- **WHEN** stored parsed graphs disagree with retained command output even if metadata hashes were rewritten
- **THEN** report generation refuses the inconsistency
