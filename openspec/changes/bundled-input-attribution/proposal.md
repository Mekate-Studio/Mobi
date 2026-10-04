## Why

The Toolchain 0.13.0 rehearsal passed its bounded builds but left 32 settings-classpath files without artifact identities. Fewer provider matches cannot establish remediation when the distribution hides Maven coordinates.

## What Changes

- Verify the measured files against the checksum-pinned release distribution and source-bound ownership evidence.
- Independently compare third-party Maven artifact bytes, retaining variant and attribution limits.
- Add repeatable repository-owned evidence verification and refresh the exact advisory lookup without rewriting the earlier rehearsal.
- Publish unresolved security and adoption gates; preserve caller production inputs and disposable cleanup.

## Capabilities

### New Capabilities

- `bundled-input-attribution`: Source-bound attribution of opaque distribution files, with exact byte joins, explicit ownership and provider coverage limits.

### Modified Capabilities

None.

## Impact

Maintenance scripts, contracts, public assessment documents and a separate evidence packet. No application dependencies, wrapper adoption, bridge/default changes, schedules, commits or publishing.
