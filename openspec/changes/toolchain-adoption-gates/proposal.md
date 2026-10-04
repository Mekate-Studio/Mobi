## Why

Toolchain 0.13.0 compiles the shared libraries with an isolated compile SDK 37 patch, but bundled attribution found no advisory remediation. An adoption decision also needs fresh retained-bridge native and packaging evidence with explicit runtime, onboarding and rollback limits.

## What Changes

- Extend isolated upstream rehearsals with native and unsigned packaging profiles, retaining Xcode ownership and the Gradle bridge.
- Bind macro validation, minimum-major simulator selection and private SDK provisioning to the run.
- Record source-bound advisory risk, release age, recovery, rollback and remaining adoption gates publicly.
- Keep production pins, OS defaults and release behavior unchanged.

## Capabilities

### New Capabilities

- `upstream-adoption-gates`: Repeatable, non-adopting native and packaging evidence for a reviewed Toolchain candidate.

### Modified Capabilities

None.

## Impact

Repository-owned maintenance adapters, checks, contract tests and English assessment documents. Native execution uses owned simulators and private SDK/cache copies. Successful execution never grants adoption or bridge retirement.
