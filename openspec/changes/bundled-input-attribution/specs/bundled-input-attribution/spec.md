## Purpose

Account for measured opaque Toolchain distribution files through verifiable reference artifacts and explicit source ownership without overstating dependency security or adoption readiness.

## ADDED Requirements

### Requirement: Verify measured file identities
The workflow SHALL bind attribution to a passing original rehearsal, reviewed configuration and checksum-pinned release archive. It MUST verify file bytes and classpath membership, distinguish unique independent Maven artifact matches from source-module correspondence, and retain unrecognized or mismatched inputs.

#### Scenario: Third-party reference artifact
- **WHEN** a reviewed independent Maven artifact has exactly the measured file's bytes
- **THEN** the report records a reference identity without inferring candidate Maven resolution or variant

#### Scenario: Released project module
- **WHEN** archive membership, embedded module metadata and versioned registered source declarations agree
- **THEN** the report records release/source-module correspondence without inventing Maven coordinates or claiming a reproducible source build

#### Scenario: Changed or missing evidence
- **WHEN** a file, source, configuration or archive identity differs or is missing
- **THEN** attribution refuses or remains incomplete and cannot qualify adoption

### Requirement: Preserve advisory and adoption limits
The workflow SHALL refresh the exact expanded Maven lookup with full provider records, preserve prior evidence, report source-owned and shaded-code coverage separately, clean owned temporary downloads, and keep adoption authorization false.

#### Scenario: More identities reveal a finding
- **WHEN** completing attribution restores a previously absent advisory match
- **THEN** the report retains the finding and withdraws any inference of remediation from the smaller lookup

#### Scenario: Replay after cleanup
- **WHEN** disposable binary downloads have been deleted
- **THEN** retained producer receipts remain verifiable and report missing capabilities independently of top-level file accounting
