# Compiler warning follow-ups

Status: open, recorded 2026-11-06. Address these in focused follow-up PRs after
the Beta2 integration and its failing CI are resolved. This note does not suppress
warnings, change compiler settings or qualify a warning as harmless.

## Evidence and scope

Snapshot: `4222074c20cca0192d52c92435f84869c3fdebf0`,
[CI #575](https://github.com/Mekate-Studio/Mobi/actions/runs/42087445512).
The raw [iOS test job](https://github.com/Mekate-Studio/Mobi/actions/runs/42087445512/job/127456325142)
contains **67 file/line/column warning emissions at 52 distinct locations and
messages**. Repeated diagnostics and source-excerpt copies are not distinct
findings. This is a partial build snapshot: the Swift test compiler crashed and
no tests ran. It is not a complete warning baseline for a successful clean build.

For reproduction, download artifact `13445502557`, read
`logs/xcodebuild-ios-tests.log`, and select complete diagnostics matching
`path:line:column: warning: message`. Normalize the checkout prefix, then deduplicate
by relative path, line, column and message. Preserve the full message and source
ownership; generated-code warnings are not authored-code warnings.

The counts below partition those 52 diagnostics. Android warnings are additional
examples from the same commit's build/test jobs, outside that count.

## Follow-up slices

| ID | Observed warnings | Ownership and next review | Closure evidence |
| --- | --- | --- | --- |
| WARN-01 | 11 native service captures are non-Sendable: Home client at lines 15/18/23; Nearby client at lines 35/38/44/50/53/57/72/78 | Authored client boundaries; coordinate with IOS-02's actor ownership/native-value review. Avoid adding unchecked service conformance to clear diagnostics. | Actual client/reducer cancellation, failure, identity and lifetime checks pass; emit SIL under strict Swift 6 and recheck IOS-02 before removing exceptions. |
| WARN-02 | 6 Swift Testing argument sites pass generated `NearbyVehicleMapFailureReason`, which is non-Sendable | Authored tests in failure-aging, feature and revalidation suites. Review native parameter representations while preserving every Kotlin reason case. | Same parameter matrix and failure assertions run on the supported local/hosted compiler tuple, without new unchecked conformance. |
| WARN-03 | 2 generated support diagnostics: `KotlinError.wrapped` stores non-Sendable `KotlinBase`, and the runtime import requests preconcurrency handling | Generated KotlinRuntimeSupport; IOS-08 already tracks strict-support removal. | Recheck official selected Kotlin sources/issues and the real strict support graph; remove the Swift 5 exception only after that graph and app tests pass. |
| WARN-04 | 7 generated Swift modules use `@_implementationOnly` without library evolution | Exporter output/runtime packaging; review with IOS-07/08/10 on Kotlin/Swift updates. | Supported producer output eliminates the diagnostics while preserving one runtime, module visibility and the real app's link/test behavior. Do not enable library evolution merely to hide the warnings. |
| WARN-05 | 15 generated Kotlin diagnostics: coroutine inheritance opt-in (1), redundant Elvis (1), unchecked casts (5), unused expressions (8) | Coroutine/exporter support and generated bridges. Prioritize the inheritance warning: its diagnostic says it will become an error in a future release. | Review official Kotlin/coroutines changes; regenerate the actual graph and run async error/cancellation tests. Record upstream applicability and any remaining diagnostics; do not hand-edit generated files. |
| WARN-06 | 9 generated Swift diagnostics: unreachable defaults (6), ineffective/optional casts (2), unused error (1); generated Native C++ mixed initializer extension (1) | Swift exporter and Kotlin/Native output | Selected upstream output reduces the diagnostics while complete switches and omission controls still behave correctly. Keep the generator/source version and exact before/after warning evidence. |
| WARN-07 | 1 authored unused `StoreTask?` result in `ios-app/src/iosApp.swift:30`; Android also reports unused `Unit` in `NearbyVehicleMapUiFactory.kt:193` | Small native-source cleanup after integration | Make the intended return/discard behavior explicit and preserve native lifetime/admission tests. |
| WARN-08 | Android declares lifecycle-runtime-compose 2.9.4 but resolves 2.11.0-beta01 | Dependency graph alignment; inspect actual Toolchain resolution and Compose/Circuit compatibility before changing the declaration. | Record why the resolved version is selected, make declarations consistent with the reviewed graph, and run Android presenter/lifetime/build gates. This note authorizes no version adoption. |
| WARN-09 | Android SDK Manager CLI deprecation and missing `cmdline-tools;latest/package.xml` followed by redownload | Runner provisioning / delegated Android bootstrap | Review supported Android CLI/Toolchain integration in a separate script change; qualify cold-runner SDK/license setup and preserve delegated bootstrap. |

Start with small owned-source and dependency-alignment slices; review concurrency
boundaries explicitly, then qualify upstream-generated changes through the
[workaround update workflow](interop-workarounds.md#observable-retirement-in-the-update-workflow).
Each PR records warning categories/counts before and after, actual behavior checks
and remaining warnings. New generated-source patches, blanket suppression or
unqualified Sendable assertions do not close this backlog.

## Separate blocking compiler failure: IOS-16

The warnings above did not explain the failing test job. Swift **6.3.3**
(`swiftlang-6.3.3.1.3`) in hosted Xcode **26.6** aborted during IR generation of
`NearbySceneTestSupport.swift`, at `Observations(predicate)`. The crash named:

```text
@$sScA_pSgSbIeAghgd_Sbs5NeverOIeAghrzr_TR
```

Demangling identifies a reabstraction from an isolated Sendable Boolean closure
to the typed-throws `Never` closure representation. `SyncCallEmission::setArgs`
appears in the compiler backtrace. This is a compiler abort before test execution,
not another lifecycle assertion or an asserted Kotlin-runtime failure.

The same actual test module compiled and ran locally with Xcode 27.1 / Swift 6.4.
The compatibility form is an explicit `Observations({ predicate() })` closure;
its final local/hosted qualification is recorded in [PR #82](https://github.com/Mekate-Studio/Mobi/pull/82).
An exact upstream issue/fix for this IR-generation crash has not been verified.
The related runtime-crash reports are not treated as exact attribution.

IOS-16 in the [registry](../../maintenance-interop-workarounds.json) requires
rechecking the direct function form on Swift/Xcode updates, with optimized
compilation of the actual test module and the existing lifecycle tests on every
supported compiler. Swift/Xcode release discovery is currently a visible manual
coverage gap in the existing workflow; the watch does not run this check.
