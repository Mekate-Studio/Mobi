## Purpose

Provide exact dependency and validation evidence for a maintainer's decision on a coupled Kotlin bridge upgrade, while preserving isolation and explicit gaps.

## ADDED Requirements

### Requirement: Paired resolution evidence

The manual review rehearsal SHALL capture Toolchain module dependency graphs and all resolvable bridge project/buildscript configurations for baseline and candidate. It MUST retain selected versions, dependency edges, variants and artifact hashes, and identify failed or unsupported resolution.

#### Scenario: Resolution succeeds
- **WHEN** both phases resolve the declared graph scope and pass the required native checks
- **THEN** their source-bound evidence is available for comparison with explicit scope and limitations

#### Scenario: Baseline resolution fails
- **WHEN** a required baseline configuration cannot resolve
- **THEN** the candidate is not evaluated as a causal upgrade comparison and the failed scope remains visible

### Requirement: Exact manual review boundary

The review packet SHALL identify the exact source, patch, coupled versions, primary release interval, advisory and OS-policy evidence, validation outcomes and cleanup. It MUST NOT infer adoption permission from passing checks or hide missing evidence.

#### Scenario: Evidence is incomplete
- **WHEN** required interval, graph, advisory or validation evidence is missing or stale
- **THEN** the packet identifies the blocker and cannot claim adoption readiness

#### Scenario: Maintainer has not approved the named patch
- **WHEN** the reviewed patch has no explicit maintainer decision
- **THEN** production dependency pins and policy remain unchanged
