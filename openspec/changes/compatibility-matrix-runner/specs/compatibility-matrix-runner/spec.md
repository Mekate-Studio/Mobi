## Purpose

Provide repeatable, source-bound evidence for upgrading the retained iOS bridge and independently assessing a direct Kotlin Toolchain replacement.

## ADDED Requirements

### Requirement: Distinct bounded compatibility tracks

The workflow SHALL keep retained-bridge compile/link and full mobile checks separate from direct SKIE, Swift export and typed-facade assessments. It MUST bind candidate versions and primary-source evidence without adopting dependencies.

#### Scenario: Narrow bridge check passes
- **WHEN** a candidate KLIB and framework compile and link
- **THEN** native tests, application builds and retirement capability cells remain unproven until their own checks run

#### Scenario: Direct integration prerequisite is missing
- **WHEN** reviewed sources do not establish the required standalone integration pipeline
- **THEN** the path reports the missing prerequisite and source evidence without claiming a compiler incompatibility or successful parity

### Requirement: Isolated native preservation

Direct experiments MUST make the hand-maintained bridge physically unavailable in an owned copy, reject stale products and IDE build skipping, record project transformations, preserve native app/test targets and tests, and check DI reachability. Caller inputs MUST remain unchanged.

#### Scenario: Unexpected source or bridge appears
- **WHEN** a build alters an undeclared authored input or recreates the unavailable bridge
- **THEN** the result is refused and cannot provide successful capability evidence

#### Scenario: Declared facade experiment
- **WHEN** a typed interop facade is rehearsed
- **THEN** its patch is recorded, the sealed domain remains authoritative and the existing native consumer tests remain part of the required checks

### Requirement: Conservative evidence and lifecycle

Results MUST distinguish passed checks, causal candidate failures, missing prerequisites, infrastructure failures and checks not attempted. They SHALL reuse baseline-first execution, source binding, resource recovery and evidence-preserving cleanup. Missing required capabilities MUST block retirement; technical success MUST NOT authorize adoption.

#### Scenario: Baseline fails or network fails
- **WHEN** baseline validation fails or a candidate cannot download its inputs
- **THEN** the workflow reports inconclusive or incomplete evidence rather than a demonstrated compatibility regression

#### Scenario: Evidence is changed
- **WHEN** a matrix result's referenced receipt or binding differs from the recorded run
- **THEN** the report refuses to treat the altered evidence as validated proof

#### Scenario: Successful named checks
- **WHEN** all checks in a bounded profile pass
- **THEN** its report retains explicit missing capabilities and adoption authorization remains false
