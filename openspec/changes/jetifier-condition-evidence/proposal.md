## Why

The selected Jetifier XML helper expands an owned external entity, but existing dependency receipts do not measure whether Mobi's generated Android builds enable or execute Jetifier. Adoption review needs observed conditions rather than a library-presence or upstream-default inference.

## What Changes

- Extend the private delegated Gradle observer with effective Jetifier options and bounded transform execution/input evidence.
- Add source-bound interpretation that distinguishes disabled, enabled, incomplete and historical unmeasured evidence without clearing advisories automatically.
- Rehearse baseline and the reviewed Toolchain candidate; preserve failures, recovery and cleanup.
- Record current primary owner-release discovery and remaining compatibility/remediation gaps.

## Capabilities

### New Capabilities

- `jetifier-condition-evidence`: Manual condition collection and conservative review of generated Android builds.

### Modified Capabilities

None. Existing historical graph receipts remain valid in their original scope.

## Impact

Repository-owned maintenance observer, evidence interpreter, contracts and public documentation. No application dependency adoption, iOS bridge/default change, policy waiver, schedule, commit or push.
