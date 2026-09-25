## Context

See proposal.md. Slice 3 is committed and pushed at `2a2577d`; its local hook
passed 50 native tests and both builds. Discovery currently uses ambient
Renovate or unpinned npx and silently skips absent OSV-Scanner.

## Goals / Non-Goals

**Goals:** Reproducible extraction, source/config/tool identities, explicit
manager/module/lock coverage and reusable conservative evidence policy.

**Non-Goals:** An all-purpose executor, candidate patching, full mobile resolution,
a clean vulnerability claim without complete fresh evidence, or backend activation.

## Decisions

- Keep the small core in Ruby standard library. Separate Kotlin supplementation
  from a dormant Elixir adapter; test the core without mobile/backend toolchains.
- Install Node 24.21.0 and Renovate 44.93.5 explicitly in an ignored owned store.
  Pin official Node archive SHA-256 values, npm lock/integrities and a complete
  installation receipt. Use `npm ci --ignore-scripts` with isolated configuration
  and cache. Do not select ambient Node/Renovate or run npm during discovery.
  This avoids a mandatory Docker daemon; other pinned platforms remain unverified
  until executed. Optional RE2 cannot load without lifecycle scripts: retain and
  report Renovate's JavaScript-regex fallback and test the actual custom managers.
- Run native Renovate local extract in an owned plain source copy, with bounded
  execution, no credential forwarding, unsafe execution/scripts disabled and
  source drift checks. Capture native output and effective configuration hashes.
  Bundled presets come from the pinned installation; unresolved external presets
  are failures rather than mutable hidden policy.
- Preserve native dependency records. Add narrowly scoped supplemental parsing
  only for measured omissions: the Toolchain wrapper/module settings, resolved
  locks, pinned tools and explicit environment declarations. Record direct,
  locked-transitive and unresolved target/variant graphs separately. Never label
  declarations as an effective resolved graph or static extraction as a scan.
- Make default `just deps` an inventory command. Policy evaluation accepts a
  versioned evidence packet tied to the inventory identity; it keeps every raw
  release and all blocking reasons. Missing provider timestamps or pages are
  incomplete. Stable releases need seven days; majors require separate review;
  compatibility ceilings come from the captured repository rules. Additional
  bundled preset constraints remain a named required policy gap until native
  candidate evaluation is integrated.
- Advisory receipts must match exact resolved inputs and be at most 24 hours
  old, complete and backed by response digests. Missing ecosystems/receipts,
  stale data and provider failures remain incomplete. High/critical findings
  block; unknown severity needs triage; lower findings remain visible. This
  slice validates evidence structure and bindings; it cannot authenticate supplied
  provider assertions or digests without separately preserved response bytes. It does not
  download an advisory database or pretend declarations cover absent graphs.

## Risks / Trade-offs

- Native extraction is an experimental Renovate interface → pin its version,
  capture real output and fixture parser/manager omissions explicitly.
- Empty owned caches cost time → keep explicit tool installation separate and
  reuse only verified tool files; never reuse a mutable caller source copy.
- Native resolution and advisory acquisition are not yet complete → report
  named gaps and return a non-success assessment, while allowing inventory
  creation to succeed as an inventory operation.
- Ecosystem versions are not universally SemVer → unsupported policy comparisons
  report incomplete; never infer eligibility from an unparsed version.

## Migration Plan

Install maintenance tools explicitly, run `just deps`, inspect the ledger, then
review separately collected evidence. Existing Renovate hosted configuration and
schedules remain unchanged. Reverting this slice restores the previous local
lookup entry point. No mobile dependency/default changes are part of rollback.
