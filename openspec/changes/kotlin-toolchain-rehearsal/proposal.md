## Why

The common executor has only fixture evidence. Mobi needs a repeatable, source-bound
Kotlin Toolchain comparison that measures effective settings and graphs, reproduces
the current baseline and keeps native process/resource ownership explicit.

## What Changes

- Add an independent Kotlin rehearsal adapter using reviewed consumer wrappers,
  exact artifact identities and an explicit candidate, initially 0.12.2.
- Capture effective settings, resolved module/target dependencies and compilation
  artifact identities separately from upstream defaults and declarations.
- Reuse existing repository build/test jobs in independent baseline/candidate
  resources, adding resource handlers and negative checks before enabling native
  execution. Expose missing coverage and infrastructure failures without a
  compatible verdict.
- Preserve the current iOS Gradle builder and compiler/plugin pins for this
  Toolchain-only comparison; keep direct-path and bridge-stack experiments separate.
- Publish local evidence, retained diagnostics, recovery instructions and the
  slice 5 integration result through existing maintenance documents.
- Add an explicit Apple Silicon assessment candidate following upstream target
  support: remove only `iosX64` in owned candidate copies and preserve ARM devices,
  ARM simulators, the bridge and native app/test targets. Report implications
  before requesting a separate adoption decision.

## Capabilities

### New Capabilities

- `kotlin-toolchain-rehearsal`: Verified candidate preparation, effective input
  capture and baseline-first Kotlin rehearsal with explicit coverage and ownership.

### Modified Capabilities

None. The existing executor contract remains required; native resource support
extends its adapters without weakening fixture isolation or conservative recovery.

## Impact

Maintenance Ruby scripts, reviewed Toolchain inputs, focused contract tests and
public documentation. Existing jobs remain the build/test authority. No dependency
adoption, bridge removal, release-default change, schedule, provider credential,
backend activation or automatic commit/push is included in slice 6. Signed release
and bridge-retirement claims require their separately authorized evidence.
