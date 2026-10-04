## Why

The approved direct iOS development default no longer needs the transitional bridge. Its retained files and active maintenance callers obscure the public architecture and prevent bridge-independent maintenance.

## What Changes

- Remove only audited iOS bridge and catalog inputs; preserve delegated Android bootstrap.
- **BREAKING**: retire active bridge rehearsal profiles on the direct source; historical evidence remains replayable.
- Adapt current maintenance, CI caches and dependency policy to the direct baseline.
- Record explicit removal authorization, exact source evidence and complete content recovery without extending risk acceptance or enabling signed delivery.

## Capabilities

### New Capabilities

- `bridge-independent-maintenance`: direct-source maintenance and native gates operate without retained iOS bridge inputs and preserve recoverable historical content.

### Modified Capabilities

None.

## Impact

Bridge files, maintenance adapters/contracts, thin workflow cache keys, Renovate policy and current architecture documentation. Existing Kotlin visitors, Swift projections, native consumers and package ownership remain the baseline. Swift export is a separate future assessment.
