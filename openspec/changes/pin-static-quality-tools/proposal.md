## Why

The first slice validates source coverage and staged content, but accepts whichever
analyzer versions appear on PATH. A clean machine can therefore enforce different
rules. The approved second slice makes tool identity explicit before expanding
the gate or starting dependency upgrades.

## What Changes

- Pin the existing five analyzers and the quality runner's runtime, with reviewed
  primary release sources, download URLs, checksums and configuration hashes.
- Replace the existing floating Homebrew quality bootstrap with an explicit,
  isolated installation path and verified artifact handling.
- Fail before analysis on missing, wrong-version, corrupt or mismatched tools
  and rule configuration; the hook remains offline and read-only.
- Reuse the bootstrap in the existing quality CI job, with negative-path tests
  and a fresh installation rehearsal on the supported local macOS platform.

## Capabilities

### New Capabilities

- `pinned-quality-tools`: Reviewed static-tool identity, explicit installation,
  checksum verification, exact runtime/version checks and recovery.

### Modified Capabilities

None. The active first-slice static gate contract continues to apply.

## Impact

Quality tooling, its bootstrap, the quality job and public onboarding docs change.
Mobile dependency versions, Kotlin Toolchain, the iOS bridge, native jobs and
release defaults stay outside this slice. Global tools are not replaced. The
initial lock preserves established analyzer behavior after upstream verification.
