## Why

The native Home/Nearby pilot passes local cold and guarded replay checks from a
published checkout. Normal hosted CI exercises the direct app, so it does not
qualify the custom exporter or alternate app on a cold GitHub runner.

## What Changes

- Add an explicitly requested, native-only hosted qualification lane with
  pinned Ruby/JDK inputs and validated Xcode/SDK selection.
- Move settings creation, cold execution, retention, recovery, cleanup and
  guarded replay into a repo-owned command.
- Resolve canonical selected Xcode paths throughout producer/consumer helpers.
- Retain source/tuple-bound reports, diagnostics and test results on success
  and failure, without claiming production adoption or accepting risks.

## Capabilities

### New Capabilities

- `native-swift-export-hosted-qualification`: Explicit hosted native-only
  qualification with cold original/reordered phases and post-cleanup replay.

### Modified Capabilities

None. The default app, existing Shared UI flow, Android bootstrap, release and
signing paths remain unchanged.

## Impact

Repo-owned CI and maintenance scripts, one optional GitHub workflow, contracts,
and qualification documentation. No application behavior or dependency pin
changes. Changed execution inputs require fresh qualification receipts.
