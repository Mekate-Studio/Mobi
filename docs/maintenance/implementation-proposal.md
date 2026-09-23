# Staged implementation proposal

Status: slices 1–2 integrated with passing hosted CI; slice 3 implemented locally
for review; slices 4–12 remain proposed.
See [first slice validation](first-slice-validation.md) and
[second slice validation](second-slice-validation.md), then
[third slice validation](third-slice-validation.md) for local evidence, the
separately approved Swift compatibility fix and outstanding hosted/Intel
validation. The
[audit](audit.md), [compatibility matrix](kotlin-compatibility.md) and
[workflow design](workflow-design.md) define the evidence behind this backlog.
Each slice should be a small reviewed integration into `main` under existing
protections. No automatic upgrades or AI PR-review dependency is proposed.

## First slice: truthful static coverage and commit input identity

Start with the existing five analyzers, hook and scripts. Introduce one shared
input collector and an index-equals-checkout guard, keeping installation and
autofix separate. Route the hook through `scripts/dev/check.sh`; let
`run_job.sh quality-check` and `just lint` use the shared static implementation.
No dependency versions, analyzer rules, native build defaults or schedules
change in this slice.

The collector should use the project's declared seven-module graph and all
recognized source roots, plus repository-owned Kotlin build scripts, shell
scripts/hook and Swift package code. Include new nonignored source in manual
lint; reject it in commit mode until staged. Resolve templates/custom layouts
or fail with a precise unsupported-input message. Exclude owned generated
output explicitly. Do not execute Toolchain downloads merely to enumerate
this baseline's simple layout.

Target files: `scripts/dev/lint.sh`, `scripts/dev/format.sh`,
`scripts/dev/check.sh`, `.githooks/pre-commit`, a small shared collector/guard,
and focused temporary-repository contract fixtures. Keep `just` aliases and
the repository job interface stable. Update the `quality-check` dispatcher
branch to select the explicit static mode when `check.sh` gains commit-mode
guards; CI must not accidentally run local commit orchestration. The first slice reports actual analyzer
versions; the next slice enforces reviewed pins. Until then, call this
**content/coverage correctness**, not a fully reproducible quality gate.

Acceptance checks:

1. Existing source passes with the recorded baseline tools and current rules.
   No formatter, installer, dependency lookup or Git mutation is invoked by
   the commit gate. Missing tools fail before expensive work with setup advice.
2. An unstaged new Kotlin file is inspected by manual lint. Once staged, an
   intentional formatting error fails commit mode. A new declared feature and
   `src@android`, `src@ios`, `test@…` source roots are covered without editing a
   module-name list. An unknown configured layout fails explicitly.
3. An intentional rule violation in each newly covered surface fails: Swift
   package source, detekt source in a new module, and the shell hook. Repair
   each and require success; valid vendored/generated output is excluded for
   a documented reason. Do not weaken policy to accommodate fixtures.
4. Partial staging, unstaged tracked deletion, rename/mode/symlink changes,
   intent-to-add and unmerged entries fail before analysis. Filenames with
   spaces, tabs, newlines and leading dashes cannot disappear or become flags.
   Escaping symlinks, unsupported sparse files and Git trust flags cannot hide
   content. Staging the intended full content permits checks.
5. A fixture that edits a tracked file or index during a deliberately slow
   analyzer causes the final guard to reject its nominally successful result.
   A file changed with restored size/mtime must still invalidate evidence.
6. Tracked ignored files remain accounted for; nonignored untracked files block
   commit mode. Ordinary ignored generated output neither gets scanned nor
   mutates tracked files. User work is never stashed/restored or overwritten.
7. Hook, manual check and CI static job select equivalent inputs under their
   documented modes and run each analyzer once. Compare manifests in fixtures.
   Capture total/per-tool duration and input counts; start from the audit's
   7.05-second warm baseline, without claiming a universal timing budget.

Tests should assert these observable properties in disposable Git repositories
and run representative real-tool violations where available. They are needed
because a false-green hook is the failure being corrected.

## Ordered follow-up slices

| Slice | Deliverable | Acceptance evidence / dependency |
| --- | --- | --- |
| 2. Reproducible existing tools | Pin five analyzers plus core runtime, install URLs/checksums and rule profiles; update existing bootstrap separately from gate | Fresh supported macOS bootstrap, exact-version verification, wrong version/missing binary/checksum mismatch fail; current gate passes with reviewed pins. Do not blindly copy observed PATH versions |
| 3. Conservative validation selection | Fix app-manifest precedence; add non-mutating test prep and pre-commit orchestration using existing jobs | Both app manifests and unknown/dependency/toolchain changes select required full validation; host/native behavior changes avoid duplicate packaging; tested snapshot and index remain identical; newly declared tests cannot be omitted |
| 4. Pinned complete inventory | Pin Renovate/runtime and capture native-manager extraction; add missing Toolchain/analyzer/SDK/image/tool coverage; explicit vulnerability policy | Extraction fixtures include all modules/plugins/locks; direct/transitive coverage ledger, blocked releases and missing timestamps visible; unavailable/stale advisory/provider data cannot be clean |
| 5. Small common executor | Isolated copies, schema, base-first rehearsal, process/resource ownership, recovery and cleanup | Negative-path contract suite for failures, timeout, interruption, drift and ownership; no caller mutation, no credentials or uploads; fake Kotlin/Elixir adapters independently exercise protocol |
| 6. Kotlin Toolchain rehearsal | Source-bound current/candidate effective settings and graphs; actual repo-owned build/test commands | Reproduce baseline; candidate 0.12.2 bootstrap/hash, plugin/factory/UI/native/package checks; current bridge remains selected. Any candidate younger than seven days is experimental only |
| 7. Compatibility matrix runner | Track 1 narrow compile and full validation; Track 2 three bounded interop experiments | Native tests/targets retained, DI reachability checked, phase/scheme changes recorded, bridge-unavailable evidence; causal failures distinguished from infrastructure |
| 8. Consolidate existing watch | Existing compatibility workflow calls common evaluator and reports meaningful matrix deltas | Simulated no-change quiet run, improved compatibility/regression/blocker notification, provider failure explicit, technical success never adopts; no duplicate schedule |
| 9. Reviewed upgrade | Exact source/patch-bound adoption and final checks | Maintainer approves named coupled set, full interval assessment/graph diff complete, final receipt current; existing defaults retained unless separately authorized |
| 10. Optional direct default and retirement | ADR update plus reversible switch, then bridge removal only when matrix proves parity | Local/cold CI native tests, architectures, required release evidence and physically absent bridge; rollback tested. May remain deferred indefinitely if gaps persist |
| 11. Elixir activation | Enable the dormant adapter only with a real backend capability | Format/compile/Credo/Sobelow/Boundary/audit/ExUnit/PostgreSQL/release checks; failure/recovery fixtures; unrelated mobile jobs require none of its tools |
| 12. Reuse refinement | Public configuration/examples and optional review skill | Fresh-clone Kotlin-only and independent Elixir contract demonstrations, license/contribution fit, no private dependencies; separate packaging only after actual reuse |

Secret detection and Actions validation can follow slice 2 as small independent
additions, with real regression fixtures and measured cost. Architecture-edge
checks belong after graph inventory; symbol-level/type-aware checks and API/ABI
snapshots are bounded experiments, not prerequisites for finishing slice 1.

Some slices may be split further. Do not combine executor development, multiple
ecosystem upgrades and bridge removal into one integration. A retained bridge
upgrade can land even when direct-path parity remains unproven.

## Review gates and durable decisions

Use a focused OpenSpec change for the selected implementation slice, reusing
the existing `spec-driven` structure and CI-validation capability where
appropriate. This proposal does not mark the existing CI change archived or
alter unrelated active changes. ADRs 0001/0002/0004/0005 define invariants;
ADRs 0003/0006 require explicit reconsideration for build ownership or interop.

For each slice report: source/configuration verified, commands actually run,
untested assumptions, remaining blockers, and a concrete next probe. Include
rule/coverage/runtime changes in the review. Passing static checks cannot close
native compatibility work. Historical archive claims cannot close new packaging
evidence. Hosted protections and integrations remain intact unless a later
explicitly scoped task changes them.
