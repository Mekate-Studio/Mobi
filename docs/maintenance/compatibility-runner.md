# Compatibility matrix runner

Current source uses `rehearse-compatibility direct-mobile` for native checks and
`direct-resolution`/`direct-build-inputs` for scoped attribution, and
`direct-ios-release`/`direct-ios-archive` for unsigned operational builds. These profiles
use the adopted content on both phases with bridge inputs absent. Historical
bridge and facade-transform profiles refuse on current source; restore a complete
published retained revision in an isolated copy to use the historical recipes
below. See [physical removal and recovery](bridge-removal.md).


For a separately reviewed, published stable candidate, `rehearse-compatibility`
accepts explicit `--experimental` before the trailing `--store NAME`. This
allows isolated technical assessment before the seven-day threshold, records
real selection/eligibility timestamps and retains `release_age` as a gap when
blocked. Normal admission still refuses an under-age candidate; future release
timestamps always refuse. Neither mode authorizes adoption. An experimental
pass needs fresh real-time age, source and advisory review before a normal
adoption decision. The caller's reviewed candidate config is not overwritten
merely to select a new tuple; use an isolated source snapshot with a recorded
configuration overlay, then retain/recover/clean it through the same executor.

This is the manual slice 7 runner. It reuses the common executor and Kotlin resource handler. Production pins, the builder default, native targets/tests, Renovate ceilings and existing schedules are unchanged. Toolchain updates, retained-bridge updates and direct-path parity remain distinct decisions.

Status: implemented, locally validated, committed and pushed as `9d25553`. The bridge compile/link and full mobile comparisons passed. The direct typed-facade candidate also passed all four mobile jobs and all 12 native Swift cases with its bridge absent. The [validation report](seventh-slice-validation.md) and [seven-run receipt](evidence/2026-09-29-slice-7.json) retain earlier failures, corrections, ownership refusal, recovery and limits. No candidate is adopted. Slice 6 was committed and pushed as `ff7146e`; [all seven hosted jobs passed](evidence/2026-09-28-slice-6-integration.json), independently of this slice.

## Commands

```sh
./scripts/dev/dependency_updates.sh assess-compatibility
./scripts/dev/dependency_updates.sh prepare-kotlin
./scripts/dev/dependency_updates.sh rehearse-compatibility bridge-compile --store compatibility
./scripts/dev/dependency_updates.sh compatibility-report RUN_ID --store compatibility
# Only after the narrow candidate passes:
./scripts/dev/dependency_updates.sh rehearse-compatibility bridge-mobile --store compatibility
# Manual upgrade review: graphs plus the same mobile jobs
./scripts/dev/dependency_updates.sh rehearse-compatibility bridge-review --store upgrade-review
./scripts/dev/dependency_updates.sh compatibility-report RUN_ID --store upgrade-review
# Independent experiment, with the current production tuple as baseline:
./scripts/dev/dependency_updates.sh rehearse-compatibility direct-facade --store compatibility-direct
# Bounded incremental Kotlin-to-Swift check and exact bridge restoration
./scripts/dev/dependency_updates.sh rehearse-compatibility direct-roundtrip --store direct-roundtrip
./scripts/dev/dependency_updates.sh recover RUN_ID --store compatibility
./scripts/dev/dependency_updates.sh cleanup RUN_ID --apply --discard --store compatibility
```

Use the matching store for recovery, reporting and cleanup. The execution host must be Apple Silicon macOS with Xcode, a compatible simulator runtime, JDK 21 and an Android SDK. The normal public setup supplies pinned Ruby. No GitHub account, private runner, AI access or additional schedule is required to run locally.

The current reviewed baseline/nomination in `maintenance-compatibility.json` is Kotlin 2.4.20, Metro 1.4.5 and SKIE 0.10.15, holding bridge Compose 1.9.0 after the approved [adoption](bridge-adoption-validation.md). The earlier slice-7 nomination was Kotlin 2.4.10 / Metro 1.4.4 / SKIE 0.10.14. Runtime/compiler Metro declarations stay coupled across module manifests and the bridge catalog in the disposable candidate. Versioned sources and dated release responses support nomination; they do not establish Mobi compatibility or complete interval review. Newer releases are shown separately with age eligibility; the command reads the reviewed snapshot, not live release discovery.

The initial slice-7 source review read the Metro 1.2.0–1.4.4 release notes, including Native scoped-initialization changes, KLIB factory fixes, opt-in IR generation and newer compiler build versions. The [slice-9 review](ninth-slice-review.md) adds the complete stable Kotlin/Metro/SKIE interval, paired bridge resolution and fresh mapped Maven advisories. It recommends deferring this older compiler tuple despite passing local checks. Language/API targets or a compiler table alone cannot establish Native artifact compatibility or adoption readiness.

`bridge-compile` first executes the unchanged baseline, then the candidate. KLIB compilation and framework linking are separate cells. A produced framework is required for the link cell. `bridge-mobile` also runs the existing Android/shared tests, Android debug build, iOS test plan and iOS debug build. The native test evidence must include both current suites and at least 12 distinct cases. A compile-only success never fills these cells.

## Manual upgrade review

`bridge-review` adds `show dependencies --all-modules --include-tests` and all
project/buildscript configurations of `gradle-bridge/` to `bridge-mobile`.
Non-resolvable configurations are inventoried explicitly. Resolvable graphs
retain selected components, dependency edges, variants and artifact identities.
Kotlin/Native distributions use sorted relative tree fingerprints. Kotlin's
existing SwiftPM lock-file metadata producer runs before its project output is
hashed; authored source remains guarded. Missing outputs, unresolved edges,
unknown identities or incomplete target/plugin scope cannot pass. Controlled
partial graphs remain available locally after failure; the candidate is stopped
when baseline evidence cannot be established.

After both phases pass, `compatibility-report` verifies their digest chains,
compares graph/configuration/variant/artifact content and emits
`resolution.baseline_advisory_queries` and `candidate_advisory_queries`.
Those lists contain exact normalized Maven names/versions. Toolchain artifact
suffixes are recorded when normalized; constraint labels are excluded. The
provider state is `not_queried`. Submit their deduplicated union to a reviewed
provider such as [OSV querybatch](https://google.github.io/osv.dev/api/#tag/vulnerabilities/operation/queryBatch),
retain exact request/response hashes and timestamps, check response counts and
pagination, fetch each finding's full record and triage it against actual use.
Provider failure, missing/paginated responses or data older than policy permits
cannot be called clean. Preserve the query-to-input binding in the review packet.

This is semi-automated collection and comparison with manual semantic/advisory
review. It does not prove shaded-code, Native-distribution, Swift/Ruby/npm or
Toolchain-delegated Android plugin coverage. Only the measured bridge graph gap
closes automatically; independent provider, release and direct-path gates remain.
Finish or recover a run before changing source/code; report after cleanup has
released its lease. Use the matching named store for recovery and cleanup.
The [slice-9 validation](ninth-slice-validation.md) records a real paired run,
retained failures, cleanup and exact review-only patches. No new watch schedule
or mutating adoption command is introduced.

## Direct resolution review

The manual [direct-resolution profile](direct-resolution-review.md) collects paired
Toolchain graphs and fingerprints without native jobs. Its exact-input OSV lookup
retains provider failures and findings separately from full graph coverage.

## Direct experiments

The manual [direct-roundtrip profile](direct-roundtrip.md) extends the existing
typed-facade experiment with a changed native probe, framework identities and
validated restoration before bridge native checks. Its absence claim covers the
direct stages before restoration. It does not change any default or close the
independent device/release/onboarding/hosted gates.

The SKIE prerequisite assessment requires a supported standalone pipeline for compiler configuration, Swift generation and framework processing. Its Gradle plugin has more responsibilities than providing a compiler coordinate. The Swift export assessment requires standalone Toolchain emission and Xcode embedding; Alpha Kotlin documentation with a Gradle task does not prove that integration. Both paths can stop at a source-bound `missing` prerequisite without claiming a reproduced compiler failure.

The measured earlier direct experiment retained Metro 1.1.1. Direct profiles inherit the reviewed current baseline; a new run now uses Metro 1.4.5, whose [bounded local round trip](direct-current-assessment.md) now passes. Complete direct graph/advisory and retirement gates remain open. Follow the [retirement path](bridge-retirement-path.md) instead of inheriting the older simulator pass.

The typed-facade experiment adds an explicit visitor at the DI boundary and equivalent Swift case projections. Kotlin `when` expressions and typed visitor methods retain sealed-domain exhaustiveness; payloads remain their existing typed Kotlin values. No string tags or unchecked type casts are introduced. The existing Swift adapters retain their switches; one Kotlin enum switch uses the explicit projection. Explicit enum constant aliases retain native consumer spelling, and distinct visitor method names avoid Objective-C selector collisions. These are experiment templates, not production APIs. Any adoption requires architecture review and additional parity evidence.

In the generated direct copy the runner removes `gradle-bridge/`, adds the missing `shared-di` dependency, and replaces only the custom build phase with the documented Toolchain integration phase. The checked-in app/test target identities, test sources, scheme and test plans remain. Every transformation has preimage/output hashes; the local transformation receipt retains changed/added content, and the public receipt retains its hashes. The immutable outer audit snapshot still exists for evidence, but the build copy has no bridge or stale products. This is operational isolation, not an OS security sandbox against malicious same-user code.

The `di_reachable` result describes the Toolchain module graph. The retained bridge compiles shared DI through its flattened source sets even when that module is absent from the Toolchain app graph.

Expected authored inputs remain guarded before and after each command. Unexpected project/source edits or bridge reappearance refuse the result. The IDE build-skip variable is explicitly disabled. Commands use private HOME/caches/SDK copy and owned simulators/JVMs. Code/source/index changes while a run is active invalidate its evidence; finish or recover the run before editing.

## Interpreting results

`compatibility-report` verifies the run/journal/check/evidence/log digest chain and keeps baseline/candidate cells separate. It refuses a successful summary without both passing phases or altered referenced evidence. Causal candidate failure after a passing baseline is `incompatible`; network or unknown failures are inconclusive, missing prerequisites incomplete, and source drift refused. Missing/unexecuted capabilities do not become passing when another cell succeeds.

Device execution, archive/export, cancellation/lifecycle equivalence, generic export, cold direct CI and incremental direct builds remain separate gaps. The manual `bridge-review` profile adds complete measured bridge target graphs; the slice-9 packet supplies dated interval and mapped Maven advisory review with explicit coverage limits. Older profiles do not acquire that evidence retroactively. Bridge retirement remains deferred and adoption authorization remains false. Local framework or simulator success cannot remove these gates.

Slice 8 consolidates the existing compatibility workflow around this evaluator’s reviewed compile/link profile. See the [watch guide](compatibility-watch.md) for bounded release discovery, semantic comparison, history and recovery. A watch observation never authorizes adoption.

## Selected compiler and delegated Android inputs

The manual [direct-build-inputs profile](direct-build-input-proof.md) adds selected
compiler invocation/path/fingerprint proof and required delegated settings,
debug-main and compiler/build-tool graphs. It runs Android jobs and ARM KLIB
compilations, creates no simulator and does not repeat Swift app/release checks.
Its [current assessment](direct-build-input-assessment.md) passes bounded
execution, but 17 named build-tool advisory matches require review. Uncollected
configurations, plugin-coordinate attribution and independent retirement gates
remain explicit. No workflow schedule or production builder is changed.

After a passing `direct-build-inputs` pair, the manual
[compiler attribution command](compiler-plugin-attribution.md) uses the same
owned executor and an independent resolver to join selected plugin fingerprints.
Its `plugin-report` and `review-advisories` commands retain the original compiler
source binding separately from the fresh resolver run.
