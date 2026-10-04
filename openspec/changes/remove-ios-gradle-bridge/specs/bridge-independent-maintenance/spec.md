## Purpose

Keep the public direct iOS development baseline maintainable without transitional bridge inputs while preserving explicit recovery and evidence boundaries.

## ADDED Requirements

### Requirement: Direct maintenance without bridge inputs
Current dependency assessment and native development gates SHALL operate without hand-maintained iOS bridge files. Android delegated bootstrap MUST remain supported. Retired bridge-only execution SHALL report an explicit unsupported scope.

#### Scenario: Direct source assessment
- **WHEN** maintenance assesses the adopted source with bridge inputs absent
- **THEN** it validates current direct declarations and reports missing provider or graph evidence conservatively

#### Scenario: Historical bridge request
- **WHEN** a bridge-only rehearsal is requested on direct source
- **THEN** it refuses with recovery guidance before native execution

### Requirement: Recoverable removal
Removal SHALL record exact prior source revisions and validate complete restored content and native consumers in an isolated owned copy. It MUST preserve unrelated saved work, signed-delivery holds and the original risk expiry.

#### Scenario: Content recovery
- **WHEN** recovery is rehearsed
- **THEN** restored source bytes and modes match the selected published revision and its native consumers are rebuilt
