## Why

The current direct-build proof fingerprints selected compiler plugin files but cannot attribute their Maven components. Advisory assessment must join real compiler inputs to authoritative resolver artifacts before claiming coverage.

## What Changes

- Add an isolated manual plugin resolver using the existing executor, bound to a passing paired build-input result.
- Match every selected file by hash and size, preserve independent root graphs and exclusions, and refuse missing, ambiguous or extra inputs.
- Extend fresh advisory review with attributed plugin inputs without waiving existing findings.
- Publish evidence and remaining exposure/remediation decisions separately from adoption and bridge retirement.

## Capabilities

### New Capabilities

- `compiler-plugin-attribution`: fingerprint-backed attribution of compiler-selected files and exact-input advisory review.

### Modified Capabilities

None.

## Impact

Repository maintenance adapter, resolver observer, report verification, CLI, contracts and public documentation. No application dependency adoption, builder changes, release changes or schedules.
