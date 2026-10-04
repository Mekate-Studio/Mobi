## Why

The current direct-input review found 17 delegated build-tool advisories. A released Toolchain update must be assessed using actual selected inputs and execution, independently of its compiler upgrade or SwiftPM announcement.

## What Changes

- Pin Toolchain 0.13.0 for manual assessment, keeping 0.12.2 as production baseline.
- Add an explicitly experimental paired upstream build-input profile with source-bound graphs, compiler fingerprints, Android tests/build and ARM KLIB compilation.
- Compare fresh exact-input advisories and preserve incompatibilities, infrastructure failures, recovery and cleanup.
- Track initial SwiftPM support as a separate capability hypothesis with primary sources and Mobi-specific acceptance gates.

## Capabilities

### New Capabilities

- `upstream-remediation-rehearsal`: isolated upstream candidate execution and advisory comparison without adoption.

### Modified Capabilities

None.

## Impact

Kotlin maintenance adapter, versioned parser/collector support, wrapper pins, CLI, contracts, compatibility matrix and public documentation. No production wrappers, application defaults, dependency adoption, bridge removal or schedules.
