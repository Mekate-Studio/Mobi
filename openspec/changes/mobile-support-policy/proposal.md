## Why

The validated Toolchain/ARM migration is approved for adoption. Mobi also needs
an explicit, configurable minimum-OS policy and repeatable support-impact review
instead of SDK-dependent iOS defaults and indefinite legacy Android support.

## What Changes

- Adopt the validated Toolchain 0.12.2 and ARM-only iOS candidate, updating the
  reviewed maintenance baseline and onboarding documentation.
- **BREAKING**: assess and adopt app minimums at one stable major release behind
  the latest: currently iOS 26 and Android 16/API 36. Separate minimums from
  compile/target SDK changes; keep the bridge and native app/test targets.
- Add configurable, source-bound support-policy assessment to the manual update
  workflow. Unsupported architecture/dependency combinations, API changes and
  support loss require explicit impact review and user adoption decisions.
- Reuse the existing isolated rehearsal and failure/recovery model. Allow an
  explicit fresh run-store name without transferring old ownership markers.

## Capabilities

### New Capabilities

- `mobile-support-policy`: Reviewed stable-major history, configurable support
  lag, declared-floor inventory, decision requirements and isolated OS rehearsal.

### Modified Capabilities

None. Existing quality and executor guarantees remain required.

## Impact

Toolchain wrappers, shared target lists, app minimum declarations, maintenance
policy/adapter/CLI, focused tests and public documentation. No automatic adoption,
new schedule, bridge retirement, release publishing, commit or push. The user has
approved this migration and minimum policy; future compatibility-impacting changes
still need a concrete assessment and adoption decision.
