## Why

The static gate now verifies inputs and tools, but commits do not yet run selected
native checks. The classifier under-selects app manifests, Android test prep
rewrites tracked metadata, and hard-coded test-module lists can omit new tests.

## What Changes

- Correct manifest/dependency precedence and preserve exact Git paths, including
  deletions and both sides of renames, in local and CI classification.
- Discover supported Android test-bearing modules from the declared graph and
  reject unsupported test targets instead of silently omitting them.
- Separate validation preparation from release version/signing preparation.
- Extend the existing commit gate with one static pass and selected existing
  jobs in an owned copy; verify caller/index and copied inputs around execution.
- Keep CI quality static-only, with its separately selected native jobs.

## Capabilities

### New Capabilities

- `conservative-precommit-validation`: Shared conservative selection, discovered
  tests, isolated validation and explicit failure/recovery evidence.

### Modified Capabilities

None. The active static gate and CI tiering changes remain separate records.

## Impact

Repository-owned classifier, check/job scripts, test-module discovery, focused
fixtures and onboarding documents. No dependency upgrades, bridge/default
changes, release-job changes, new schedules or general dependency executor.
