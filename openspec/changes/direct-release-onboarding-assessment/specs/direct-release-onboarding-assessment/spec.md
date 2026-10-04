## Purpose

Provide bounded, replayable operational evidence for reviewing eventual iOS bridge retirement while keeping production selection and accepted risk independent.

## ADDED Requirements

### Requirement: Operational evidence binds both execution paths
The assessment SHALL bind source revision, exact probe, raw commands and output hashes for both retained and bridge-unavailable direct phases. A passing complete operational assessment MUST require actual Nightly cases, unsigned simulator Release and unsigned ARM64 archive with product inspection. Named partial pairs MUST declare required operations, mark excluded operations unattempted and preserve those missing capabilities; they MUST NOT claim complete operational coverage individually.

#### Scenario: Complete pair
- **WHEN** both phases complete all required operational checks
- **THEN** the receipt reports only measured product and plan behavior and preserves separate runtime, signing and architecture limits

#### Scenario: Incomplete or failed producer
- **WHEN** setup, execution or evidence verification fails
- **THEN** the producer remains incomplete or failed and any corrected execution receives its own identity

#### Scenario: Bounded hosted pairs
- **WHEN** execution is split into named Nightly, simulator Release and device-archive pairs within the original resource budget
- **THEN** complete hosted coverage requires all three passing pairs bound to the same source/probe revision and actual required operations in both paths

### Requirement: Setup evidence preserves host scope
The assessment SHALL distinguish clean public source, hosted runner execution, dependency/cache reuse and explicit SDK/license prerequisites. Copied host license acceptance MUST NOT establish empty-host onboarding.

#### Scenario: Prepared local SDK
- **WHEN** a local phase copies an installed SDK including licenses
- **THEN** the receipt retains prepared-host scope and leaves independent onboarding proof open

### Requirement: Assessment preserves production and recovery boundaries
The assessment MUST preserve the source checkout, production builder defaults, original risk scope/expiry and retained raw evidence. A successful receipt SHALL require owned recovery quiescence and cleanup verification and SHALL defer default transition and physical bridge removal.

#### Scenario: Completed owned execution
- **WHEN** an operational run ends
- **THEN** recovery checks owned resources, cleanup affects only disposable owned paths and replay verifies source/output bindings without authorizing production migration
