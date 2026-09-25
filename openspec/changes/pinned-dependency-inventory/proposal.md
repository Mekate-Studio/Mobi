## Why

The local dependency command selects unpinned Renovate/runtime binaries and can
skip vulnerability scanning while returning success. Maintenance needs a source-bound
inventory that shows native extraction, supplemental coverage and unresolved data
before any candidate assessment or rehearsal.

## What Changes

- Pin an independently installed Node/Renovate toolchain and its transitive npm
  lock; verify installation receipts without installing during discovery.
- Replace the unpinned local front door with isolated, non-mutating discovery.
  Use native Renovate managers first and capture exact extraction/config identities.
- Add the demonstrated gaps: Toolchain/compiler plugins, resolved Swift/gem/npm
  locks, quality tools, SDK/runtime/runner/image declarations and floating inputs.
- Keep declared, locked and unresolved target graphs distinct in a coverage ledger.
- Add reusable release-age/major/ceiling and advisory-freshness policy evaluation;
  missing, stale, truncated or failed provider data cannot report a clean result.
- Keep Kotlin inventory separate from an independent, dormant Elixir adapter.

## Capabilities

### New Capabilities

- `dependency-inventory`: Pinned source-bound extraction, explicit coverage gaps
  and conservative release/advisory evidence evaluation.

### Modified Capabilities

None.

## Impact

Repository-owned maintenance scripts, a maintenance-tool lock and explicit
bootstrap, `just deps`, contract tests and public documentation. No application
dependency adoption, native build/default changes, bridge retirement, new
schedules, provider writes or automatic upgrades. Full candidate rehearsal and
native resolved-graph acquisition remain separate later slices; absent evidence
must remain visible in this inventory.
