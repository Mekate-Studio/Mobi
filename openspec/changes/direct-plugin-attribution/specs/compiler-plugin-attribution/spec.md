## Purpose

Establish repeatable attribution of compiler-selected plugin files without inferring component identity from cache names, and preserve bounded advisory evidence.

## ADDED Requirements

### Requirement: Attribute actual selected bytes
The assessment SHALL bind a passing paired build-input result to independently resolved plugin roots and require an exact, unique component/variant fingerprint match for every measured plugin file in both phases. It MUST report excluded and unselected artifacts separately.

#### Scenario: Resolver disagreement
- **WHEN** a selected file has no match, conflicting matches or an unmatched retained resolver input
- **THEN** the assessment refuses successful attribution and retains diagnostic evidence

#### Scenario: Complete matching
- **WHEN** every selected file in both phases matches uniquely and the source/result bindings verify
- **THEN** the assessment reports bounded attribution and explicit shaded and unmeasured input gaps

### Requirement: Isolate execution and review
The assessment SHALL use owned source copies, caches, process recovery and cleanup; retain command and producer evidence after cleanup; and query exact attributed Maven inputs with source-bound provider receipts. Findings MUST remain review-required without authorizing adoption or bridge removal.

#### Scenario: Findings or provider failure
- **WHEN** a lookup returns findings or incomplete provider data
- **THEN** it reports review-required or incomplete, respectively, without treating transport success as adoption permission

#### Scenario: Caller preservation
- **WHEN** execution or review completes
- **THEN** caller files, index and HEAD remain unchanged and recovery and cleanup are independently reportable
