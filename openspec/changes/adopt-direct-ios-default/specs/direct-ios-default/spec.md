## Purpose

Make the approved direct iOS development path consistent across public callers while preserving typed native behavior, bounded risk and a complete rollback route.

## ADDED Requirements

### Requirement: Consistent direct development selection
Development, repository tests and unsigned iOS builds SHALL select direct Kotlin integration by default. Unsupported and stale Gradle overrides MUST fail before build work with complete rollback guidance.

#### Scenario: Default caller
- **WHEN** an iOS development caller has no builder override
- **THEN** it selects direct Kotlin integration

#### Scenario: Stale bridge selector
- **WHEN** a caller selects the Gradle bridge on the adopted source
- **THEN** it refuses and explains that complete content rollback is required

### Requirement: Typed native interoperability
Native consumers SHALL retain exhaustive typed cases and concrete payloads across the direct boundary, preserving current feature behavior and measured async semantics.

#### Scenario: Existing feature consumers
- **WHEN** native feature consumers run against the adopted boundary
- **THEN** their original repository cases pass without changing feature clients or reducers

### Requirement: Bounded delivery and risk
Credentialed iOS delivery SHALL remain held. Default adoption MUST preserve the approved vulnerability exception expiry and exclude physical bridge deletion.

#### Scenario: Credentialed delivery entry point
- **WHEN** a caller requests signed archive, export or TestFlight delivery
- **THEN** it refuses before consuming credentials

#### Scenario: Approved default application
- **WHEN** the maintainer-approved development default is applied
- **THEN** its source and scope are recorded separately without extending the risk window or authorizing bridge deletion

### Requirement: Reviewable integration and rollback
Application SHALL preserve unrelated pending inputs and bridge/catalog bytes. Validation MUST distinguish applied source evidence from historical candidate or hosted receipts.

#### Scenario: Working checkout has pending evidence
- **WHEN** the reviewed default is integrated
- **THEN** pending evidence is retained and any documentation merges are recorded explicitly

#### Scenario: Rollback request
- **WHEN** complete rollback is performed
- **THEN** bound source content and modes are restored and restored consumers are validated after owned work and incompatible products are cleared
