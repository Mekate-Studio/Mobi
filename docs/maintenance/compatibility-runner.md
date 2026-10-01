# Compatibility matrix runner

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
# Independent experiment, with the current production tuple as baseline:
./scripts/dev/dependency_updates.sh rehearse-compatibility direct-facade --store compatibility-direct
./scripts/dev/dependency_updates.sh recover RUN_ID --store compatibility
./scripts/dev/dependency_updates.sh cleanup RUN_ID --apply --discard --store compatibility
```

Use the matching store for recovery, reporting and cleanup. The execution host must be Apple Silicon macOS with Xcode, a compatible simulator runtime, JDK 21 and an Android SDK. The normal public setup supplies pinned Ruby. No GitHub account, private runner, AI access or additional schedule is required to run locally.

The bridge candidate is nominated in `maintenance-compatibility.json`: Kotlin 2.4.10, Metro 1.4.4 and SKIE 0.10.14, holding bridge Compose 1.9.0. Runtime/compiler Metro declarations stay coupled across module manifests and the bridge catalog in the disposable candidate. Versioned sources and dated release responses support nomination; they do not establish Mobi compatibility or complete interval review. Newer releases are shown separately with age eligibility; the command reads the reviewed snapshot, not live release discovery.

The initial source review read the Metro 1.2.0–1.4.4 release notes, including Native scoped-initialization changes, KLIB factory fixes, opt-in IR generation and newer compiler build versions. Language/API targets and the compiler compatibility table do not establish Native artifact compatibility. The complete Kotlin/Compose migration interval, advisory review and bridge target graphs remain explicit gaps. Current evidence does not make this candidate ready for adoption.

`bridge-compile` first executes the unchanged baseline, then the candidate. KLIB compilation and framework linking are separate cells. A produced framework is required for the link cell. `bridge-mobile` also runs the existing Android/shared tests, Android debug build, iOS test plan and iOS debug build. The native test evidence must include both current suites and at least 12 distinct cases. A compile-only success never fills these cells.

## Direct experiments

The SKIE prerequisite assessment requires a supported standalone pipeline for compiler configuration, Swift generation and framework processing. Its Gradle plugin has more responsibilities than providing a compiler coordinate. The Swift export assessment requires standalone Toolchain emission and Xcode embedding; Alpha Kotlin documentation with a Gradle task does not prove that integration. Both paths can stop at a source-bound `missing` prerequisite without claiming a reproduced compiler failure.

The direct experiment retains Metro 1.1.1, independently of the bridge candidate's Metro 1.4.4. Its simulator pass does not establish that combined tuple.

The typed-facade experiment adds an explicit visitor at the DI boundary and equivalent Swift case projections. Kotlin `when` expressions and typed visitor methods retain sealed-domain exhaustiveness; payloads remain their existing typed Kotlin values. No string tags or unchecked type casts are introduced. The existing Swift adapters retain their switches; one Kotlin enum switch uses the explicit projection. Explicit enum constant aliases retain native consumer spelling, and distinct visitor method names avoid Objective-C selector collisions. These are experiment templates, not production APIs. Any adoption requires architecture review and additional parity evidence.

In the generated direct copy the runner removes `gradle-bridge/`, adds the missing `shared-di` dependency, and replaces only the custom build phase with the documented Toolchain integration phase. The checked-in app/test target identities, test sources, scheme and test plans remain. Every transformation has preimage/output hashes; the local transformation receipt retains changed/added content, and the public receipt retains its hashes. The immutable outer audit snapshot still exists for evidence, but the build copy has no bridge or stale products. This is operational isolation, not an OS security sandbox against malicious same-user code.

The `di_reachable` result describes the Toolchain module graph. The retained bridge compiles shared DI through its flattened source sets even when that module is absent from the Toolchain app graph.

Expected authored inputs remain guarded before and after each command. Unexpected project/source edits or bridge reappearance refuse the result. The IDE build-skip variable is explicitly disabled. Commands use private HOME/caches/SDK copy and owned simulators/JVMs. Code/source/index changes while a run is active invalidate its evidence; finish or recover the run before editing.

## Interpreting results

`compatibility-report` verifies the run/journal/check/evidence/log digest chain and keeps baseline/candidate cells separate. It refuses a successful summary without both passing phases or altered referenced evidence. Causal candidate failure after a passing baseline is `incompatible`; network or unknown failures are inconclusive, missing prerequisites incomplete, and source drift refused. Missing/unexecuted capabilities do not become passing when another cell succeeds.

Device execution, archive/export, cancellation/lifecycle equivalence, generic export, full release-interval and advisory review, complete bridge target graphs, cold direct CI and incremental direct builds are separate gaps. Bridge retirement remains deferred and adoption authorization remains false. Local framework or simulator success cannot remove these gates.

Slice 8 consolidates the existing compatibility workflow around this evaluator’s reviewed compile/link profile. See the [watch guide](compatibility-watch.md) for bounded release discovery, semantic comparison, history and recovery. A watch observation never authorizes adoption.
