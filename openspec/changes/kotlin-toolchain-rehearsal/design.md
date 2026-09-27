## Context

See proposal.md for motivation. Slice 5's executor accepts explicit argv, exact
source replacements and typed results. It deliberately supports only filesystem
and process-group resources. Native jobs additionally use detached Gradle JVMs,
Android SDK files and an iOS simulator; these require ownership beyond the
supervisor process group.

The versioned Kotlin CLI provides `show settings --all-modules` and `show
dependencies --all-modules --include-tests`. Isolated exploratory runs of both
0.11.1 and 0.12.2 confirmed these commands work on this checkout. Their output
formats differ, including the Android compileSdk shape. Effective settings and
the resolved text graph must therefore be parsed by a version-bounded adapter.

## Goals / Non-Goals

**Goals:** make input capture and actual repo-owned regression checks repeatable,
source-bound and conservatively classified; retain useful partial evidence when
a candidate or prerequisite fails.

**Non-Goals:** adopt versions, prove bridge retirement, silently upgrade Metro or
SKIE, authenticate supplied provider receipts, publish releases, create schedules
or activate the Elixir profile.

## Decisions

1. **Reviewed consumer wrappers.** A repository manifest pins the official
   consumer wrapper URLs/hashes, embedded distribution checksum and release
   timestamp. Explicit preparation downloads only those wrappers. Rehearsal
   verifies them again. The default policy edits only `kotlin` and `kotlin.bat` in the candidate.
   Copying a wrapper from an upstream source tag is rejected because it can name
   a different bootstrap build. The normal checkout stays at 0.11.1.
2. **Separate evidence scopes.** An input-only profile captures version, effective
   settings and resolved graph text for every module, including test scopes.
   The mobile profile adds existing Android/shared tests, Android debug build,
   bridge-backed iOS tests and debug build. Each profile runs the unchanged
   baseline first with the same named checks. A passing input profile cannot
   claim native compatibility. Incomplete artifact/graph coverage is an explicit
   ledger, including signed release and direct-path parity.
3. **Preserve both stacks.** `KOTLIN_IOS_BUILDER=gradle` remains explicit. Bridge
   catalog, native app/test targets, Swift packages/adapters and compiler plugins are
   held unchanged. The default policy preserves all architecture targets. A Toolchain-only candidate regression is retained for the
   subsequent coordinated-stack assessment, rather than repaired implicitly.
4. **Owned generated workspace.** Checks build in a second copy under phase
   output, protecting the executor's strict source snapshot. Authored inputs
   are hash/mode checked before and after commands; builds use the owned output
   copy and new Kotlin/Swift files in declared source/test roots are rejected.
   This is not a complete generated-file allowlist or a hostile-code sandbox. HOME, Toolchain/Gradle/Native caches,
   temp, SDK copies and derived data are private to the phase. Only declared
   host tool locations enter the clean environment.
5. **Native lifecycle hooks.** Journal a random JVM ownership tag before spawn
   and pass it through private Gradle JVM settings. Toolchain's Tooling API
   replaces these options in the measured baseline, so an exact daemon classpath
   under the nonce-bound private distribution is a second ownership proof. Bind
   its artifact hash, canonical path, uid and live process/start identity;
   a PID or broad process name is insufficient. Unknown daemons block cleanup.
   Recovery and the supervisor's coordinator-loss path
   use the same handler. An owned simulator has a journaled unique name and
   runtime before creation; only its verified device may be shut down/deleted.
   Xcode test clones must match the exact nonce-bearing base name and runtime;
   unknown names carrying that nonce refuse cleanup. Clones are recorded and
   removed before the base, including on timeout.
   Simulator commands stay in the supervisor group. Unconfirmed creation blocks
   cleanup even when the device is not yet visible. Existing user simulators and
   shared native services are never cleanup targets.
6. **Evidence and failure precedence.** Record per-command exit, elapsed time,
   diagnostics, effective configuration, graph roots/edges and downloaded artifact
   digests. Missing prerequisites and network/bootstrap failures are incomplete
   or inconclusive. A candidate-only attributed compiler/test failure requires a
   passing corresponding baseline. Ambiguous failures stay inconclusive. Missing
   required evidence cannot become `ready_for_review`; adoption remains false.
7. **Explicit upstream-compatible target assessment.** After the recorded Compose
   `iosX64` failure, maintainers requested assessing target retirement instead of
   pinning old dependencies to preserve it. Optional policy `apple-silicon` adds
   six exact candidate-only edits: five shared module target lists and the bridge
   Intel target/source-set block. Unknown mappings or new modules require review.
   ARM device/simulator main/test graph coverage is required; Intel graph roots
   are rejected. Intel iOS becomes an intentional exclusion, while hosted/Linux,
   device/release and other missing evidence remain visible. The iOS 16 package
   floor, Xcode app/test targets, plugin pins and bridge selection stay unchanged.
   The baseline still uses the original targets. Target-policy migration is
   opt-in and cannot authorize dependency adoption or bridge removal.

## Risks / Trade-offs

- Text introspection is not a stable JSON API → pin supported versions, preserve
  raw output hashes, test both captured formats and reject unknown/missing roots.
- Native tools may create detached processes → prove real registry/tag behavior
  and interruption cleanup before accepting native success; retain uncertain
  resources and report the exact gap.
- Private SDK/cache copies cost disk/time → use supported local copy-on-write
  where available, record identities and never redirect writes to caller caches.
- A complete security/compatibility assessment requires more than this adapter →
  keep provider, bridge graph, platform, release and direct-path gaps explicit.
- macOS host capabilities vary → preflight required SDK/Xcode/runtime inputs and
  return a named missing prerequisite before native work where possible.

## Migration Plan

Extend the existing maintenance front door and contract dispatcher. Leave normal
native jobs and their defaults unchanged. Validate fixture failure paths and
isolated real probes, then leave slice 6 uncommitted for review. Recovery uses
retained run IDs; removing the adapter integration restores the earlier command
surface without changing any dependency pin or release path.
