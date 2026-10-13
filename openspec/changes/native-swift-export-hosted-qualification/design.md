## Context

The published native Home/Nearby pilot passed local cold original/reordered
builds and post-cleanup replay. Ordinary Mobile CI validates the direct app.
Hosted runners need explicit Ruby, JDK and Apple tool selection and must retain
failure evidence without treating a workflow result as adoption.

## Goals / Non-Goals

**Goals:** Qualify the exact PR checkout on a cold hosted runner; retain bound
deliveries, tests and recovery receipts; exercise replay after disposable work
is removed; reject incompatible inputs before production.

**Non-Goals:** Default switching, Shared UI removal, dependency upgrades,
physical devices, minimum runtime qualification, signing, advisory acceptance
or performance-limit approval.

## Decisions

- Use a dedicated PR-label-triggered workflow rather than enlarging ordinary
  CI or scheduling exporter work. The label is an explicit request; checkout
  uses the PR head SHA, with read-only repository permissions.
- Keep orchestration in a repo-owned Ruby command exposed through run_job.sh.
  Existing Executor, Delivery, Origin and Recovery checks remain authoritative.
- Set up Ruby 4.0.6 and JDK 26; resolve the selected Xcode Developer directory
  canonically and verify Swift 6.4/Xcode 27.0/SDK 27.0. Do not change global
  xcode-select. Bound tool metadata propagates selection to subprocesses.
- Use GitHub's `xcode-27` public-preview image, with simulator major 27 explicitly
  bound into the descriptor/delivery and replay. Ordinary `macos-26` remains on
  Xcode 26; its main-app lanes are unchanged. Refuse absent runtime before
  production. Local pilot commands retain an explicit major-26 default. These
  extra-runtime checks do not qualify runtime floors or preview-image stability.
- Create source/tuple-bound experimental settings. Retain both cold deliveries,
  but replay only the original-enum archive after confirmed cleanup. Existing
  timeouts and reviewed-versus-experimental boundaries stay intact.
- Enable only four existing locked macro targets after verifying their checkout
  revisions. Store approval fingerprints in the disposable phase home and
  direct Foundation home lookup there; probe its preferences and refuse an
  inherited Xcode skip-macro bypass. A global skip flag would hide the first hosted failure, so
  it is not used. Approval records are retained; no package risk is accepted.
- Export reports, step logs, journals, immutable receipts and test bundles on
  failure as well as success. Never upload an entire work directory or cache.
  A cleanup refusal or missing test summary prevents a passing report.

## Risks / Trade-offs

- Hosted Apple tool availability may differ from the qualified tuple: fail
  explicitly and retain tool diagnostics rather than weakening the tuple.
- Native builds are costly: opt-in execution and bounded existing timeouts
  limit cost; retained artifacts have a finite retention period.
- Host tool and dependency caches make this cold-product qualification rather
  than a hermetic build. Record that limitation in the report.
- Changing helper inputs invalidates historical qualification for this exact
  source; require fresh hosted receipts. Local prior receipts remain historical.

## Migration Plan

Add contracts, validate staged content through the repository gate, publish to
the draft PR and request the lane using its label. Inspect retained receipts
before recording the hosted outcome. Rollback is removal of the opt-in workflow
and orchestration; the default app does not change.
