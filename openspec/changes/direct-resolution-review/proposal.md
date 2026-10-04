## Why

The current direct round-trip proves local application behavior and recovery but lacks direct dependency-resolution and advisory evidence. Bridge graph receipts cannot establish the dependencies selected by the direct Toolchain path.

## What Changes

- Add a manual graph-only `direct-resolution` compatibility profile using the existing isolated executor and typed-facade experiment.
- Capture baseline and bridge-unavailable candidate module/test graphs, effective settings and downloaded artifact fingerprints.
- Generate exact resolved Maven advisory queries and retain provider-bound responses with explicit incomplete/failure states.
- Preserve native, plugin, release and onboarding gaps; publish a current-tuple assessment without changing production defaults.

## Capabilities

### New Capabilities

- `direct-resolution-review`: Isolated direct-path resolution and advisory evidence with conservative coverage and verified report bindings.

### Modified Capabilities

None.

## Impact

Repository-owned maintenance scripts, contract tests, manual CLI help and public maintenance documentation. No dependency adoption, physical bridge removal, new schedules, mandatory service credentials or release-default changes.
