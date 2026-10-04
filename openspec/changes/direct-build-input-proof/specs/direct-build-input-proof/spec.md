## Purpose

Provide exact compiler invocation and delegated Android resolution evidence for direct build candidates while retaining explicit limits on broader parity and security claims.

## ADDED Requirements

### Requirement: Selected compiler inputs are execution bound
The workflow SHALL retain successful compiler invocation records with module, platform, arguments and fingerprints for every selected plugin path. Configured coordinates MUST remain distinct from selected paths and unsupported coordinate attribution MUST remain a named gap.

#### Scenario: Invocation selects an artifact
- **WHEN** a successful bounded compilation passes a plugin artifact to the compiler
- **THEN** the report binds that selection to retained telemetry and the artifact's bytes without deriving coordinates from its filename

#### Scenario: Required compilation evidence is absent
- **WHEN** a required module or target has no successful invocation record, or an artifact escapes owned storage
- **THEN** the collector refuses proof for that scope

### Requirement: Delegated graphs preserve build ownership
The workflow SHALL observe generated Android Gradle builds in owned isolation and retain settings/project buildscript and configuration inventories, selected Maven components, edges, variants, artifact identities and incomplete resolution states. It MUST preserve the native shells and caller's bridge and dependency declarations.

#### Scenario: Delegated resolution is incomplete
- **WHEN** a required buildscript scope or artifact identity is missing or unresolved
- **THEN** the report refuses complete delegated graph proof and retains the partial receipt

### Requirement: Advisory and capability claims remain scoped
The workflow SHALL extend exact-input advisory requests only with verified selected Maven coordinates, and MUST retain unsupported plugin attribution, shaded/native internals and unexecuted application/release/onboarding capabilities.

#### Scenario: A selected build tool has an advisory
- **WHEN** fresh provider evidence matches a selected build-tool version
- **THEN** the finding requires exposure triage and does not authorize adoption or retirement
