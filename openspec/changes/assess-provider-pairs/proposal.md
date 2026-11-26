## Why

The first automated run exhausted its shared provider budget after baseline advisory and checksum work, leaving candidate coverage incomplete. Optional checksum leads must not consume requests before both sides of the advisory comparison have been collected.

## What Changes

- Collect baseline and candidate advisory query batches before fetching finding records or checksum leads.
- Fetch each shared finding ID once and retain phase-specific query attribution and failures.
- Record advisory coverage separately from checksum/provenance coverage while preserving conservative incomplete comparisons.
- Keep the existing global request/deadline bounds and manual-assessment/adoption gates.

## Capabilities

### New Capabilities

- `paired-advisory-collection`: ordered provider work for both native phases under one unchanged budget.

### Modified Capabilities

None.

## Impact

Assessment security collection, native qualification integration, focused contracts and maintenance documentation. No workflow, dependency selection, policy exception or release investigation changes.
