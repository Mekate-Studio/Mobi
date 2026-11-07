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

The WARN-01 through WARN-09 counts below partition those 52 diagnostics. Android
warnings are additional examples from the same commit's build/test jobs, outside
that count. WARN-10 comes from a later successful build and is not part of those 52.

## Follow-up slices

| ID | Observed warnings | Ownership and next review | Closure evidence |
| --- | --- | --- | --- |
| WARN-01 | 11 native service captures are non-Sendable: Home client at lines 15/18/23; Nearby client at lines 35/38/44/50/53/57/72/78 | Authored client boundaries; coordinate with IOS-02's actor ownership/native-value review. Avoid adding unchecked service conformance to clear diagnostics. | Actual client/reducer cancellation, failure, identity and lifetime checks pass; emit SIL under strict Swift 6 and recheck IOS-02 before removing exceptions. |
| WARN-02 | 6 Swift Testing argument sites pass generated `NearbyVehicleMapFailureReason`, which is non-Sendable | Authored tests in failure-aging, feature and revalidation suites. Native scenario inputs now keep Kotlin reasons on the test actor; see [implementation evidence](#warn-02-native-swift-testing-arguments). | Same parameter matrix and failure assertions run on the supported local/hosted compiler tuple, without new unchecked conformance. |
| WARN-03 | 2 generated support diagnostics: `KotlinError.wrapped` stores non-Sendable `KotlinBase`, and the runtime import requests preconcurrency handling | Generated KotlinRuntimeSupport; IOS-08 already tracks strict-support removal. | Recheck official selected Kotlin sources/issues and the real strict support graph; remove the Swift 5 exception only after that graph and app tests pass. |
| WARN-04 | 7 generated Swift modules use `@_implementationOnly` without library evolution | Exporter output/runtime packaging; review with IOS-07/08/10 on Kotlin/Swift updates. | Supported producer output eliminates the diagnostics while preserving one runtime, module visibility and the real app's link/test behavior. Do not enable library evolution merely to hide the warnings. |
| WARN-05 | 15 generated Kotlin diagnostics: coroutine inheritance opt-in (1), redundant Elvis (1), unchecked casts (5), unused expressions (8) | Coroutine/exporter support and generated bridges. Prioritize the inheritance warning: its diagnostic says it will become an error in a future release. | Review official Kotlin/coroutines changes; regenerate the actual graph and run async error/cancellation tests. Record upstream applicability and any remaining diagnostics; do not hand-edit generated files. |
| WARN-06 | 9 generated Swift diagnostics: unreachable defaults (6), ineffective/optional casts (2), unused error (1); generated Native C++ mixed initializer extension (1) | Swift exporter and Kotlin/Native output | Selected upstream output reduces the diagnostics while complete switches and omission controls still behave correctly. Keep the generator/source version and exact before/after warning evidence. |
| WARN-07 | 1 authored unused `StoreTask?` result in `ios-app/src/iosApp.swift:30`; Android also reports unused `Unit` in `NearbyVehicleMapUiFactory.kt:193` | Explicit discard at the Home UI callback boundary; empty Android no-overlay branch. See [evidence](#warn-07-unused-native-results). | Preserve native lifetime/admission behavior, run both platform test/build gates and require the two targeted authored diagnostics to be absent. |
| WARN-08 | Android declares lifecycle-runtime-compose 2.9.4 but resolves 2.11.0-beta01 | Circuit 0.34.0 already selects the beta through JetBrains Lifecycle. The direct declaration now matches that selection; see [graph evidence](#warn-08-lifecycle-declaration-alignment). | Before/after main/test compile/runtime graphs preserve selected versions and edges; qualify native lifetime tests and Debug builds. Review a future effective version change separately. |
| WARN-09 | Android SDK Manager CLI deprecation and missing `cmdline-tools;latest/package.xml` followed by redownload | Runner provisioning / delegated Android bootstrap | Review supported Android CLI/Toolchain integration in a separate script change; qualify cold-runner SDK/license setup and preserve delegated bootstrap. |
| WARN-10 | 8 authored `Store.withState` reads in `NearbySceneLifetimeTests.swift`; successful CI #595 emitted 48 repeated deprecation annotations | Direct `store.state` reads use the existing `@ObservableState` and pinned TCA API; see [evidence](#warn-10-observable-store-reads-in-lifetime-tests). This is test API maintenance. | Preserve callback rejection and late location/fleet result matrices; run the actual iOS suite on local/hosted compilers and require zero `withState` deprecation diagnostics. |

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

## WARN-02: native Swift Testing arguments

The six Nearby snapshot-failure parameter sites now transport the native
`NearbySnapshotFailureScenario: Sendable`. Its two values select the existing
RepositoryUnavailable and Unexpected scenarios. Each existing `@MainActor` test
creates its generated Kotlin reason through one actor-isolated property. The
13-line helper is test-only; it is not an app enum projection or a complete
mirror of Kotlin's failure reasons. RiderLocationUnavailable was not part of
these six matrices and its existing coverage remains unchanged.

[Swift Testing's macro contract](https://developer.apple.com/documentation/testing/test(_:_:arguments:_:))
requires Sendable collections and elements. An actor-isolated test body alone
does not make a generated argument Sendable. No generated code, unchecked
conformance, preconcurrency import or production ownership exception is added.

| Test | Parameter combinations retained |
| --- | --- |
| Retained failure aging | 2 times × 2 reasons; existing 4-way degraded/suspended loop |
| Healthy / absent snapshot | 2 reasons; existing healthy/absent-state loop |
| Expired failure retry | 2 reasons |
| Location check failure | 2 snapshot-presence values × 2 reasons |
| Failure meaning and retry | 3 previous states × 2 reasons |
| Failure explanation | 2 previous states × 2 reasons |

The total remains 22 parameterized invocations. Assertions and inner loops are
unchanged. Production app state, Kotlin transitions and export modules are
unchanged; WARN-01 / IOS-02 still need their own ownership review. This testing
API correction has no Android behavior delta.

Baseline: successful [CI #590 iOS job](https://github.com/Mekate-Studio/Mobi/actions/runs/42292771869/job/128150281787),
commit `c8ed8540ec49be932ae11e9ba49015e72b2a9241`. Its beautified log contains
84 repeated warning annotations naming the non-Sendable generated failure
reason, originating at the six parameter sites. These are repeated emissions,
not 84 distinct diagnostics. The older failed-build 52-warning snapshot above
is not a comparable complete-build total.

Candidate local evidence, commit `49527dc`: Xcode 27.1 / Swift 6.4,
iPhone Air simulator iOS 26.5. The normal pre-commit gate passed static quality
and `ios-test` (428.499 seconds), with 77 tests / 170 executions, no failures or
skips. The xcresult confirms all six matrices above (4/2/2/4/6/4 cases).
The raw Xcode compiler log contains **zero** warnings naming the generated
failure reason. Other warning categories remain open; this is not an overall
warning-free build. The same export checks still confirm one Kotlin runtime and
six complete switches with six omission controls.

Hosted qualification and the like-for-like CI #590 warning comparison are
reported on the review PR for its final head; local Swift 6.4 alone does not
qualify hosted Swift 6.3.3.

Simplification check on Kotlin/exporter/Swift updates: if the actual generated
reason gains a checked Sendable conformance, try passing it directly again in
these six tests, remove this helper, and require the same matrices to compile
without these warnings and run on both supported compiler tuples. A release
note alone does not establish that the exported enum is safe to transfer.

## WARN-10: observable store reads in lifetime tests

Recorded 2026-11-07. The successful [CI #595 iOS job](https://github.com/Mekate-Studio/Mobi/actions/runs/42298968724/job/128171536334)
at `6c26c599e2dad82f6411188ff47bbfce0fa27970` emitted 48 repeated `withState`
deprecation annotations from eight authored calls. The same code's successful
local Xcode 27.1 / Swift 6.4 build emitted 24 complete diagnostic lines for this
category. Counts are repeated emissions, not numbers of distinct source sites;
compare each supported compiler separately. Other categories remain open.

TCA **1.26.0**, pinned at `e2fa1df6cd9eec6fa6314aa20513e47da576f24e`,
[exposes `Store.state` for `ObservableState`](https://github.com/pointfreeco/swift-composable-architecture/blob/e2fa1df6cd9eec6fa6314aa20513e47da576f24e/Sources/ComposableArchitecture/Observation/Store%2BObservation.swift#L22-L35)
and [deprecates `withState`](https://github.com/pointfreeco/swift-composable-architecture/blob/e2fa1df6cd9eec6fa6314aa20513e47da576f24e/Sources/ComposableArchitecture/Internal/Deprecations.swift#L255-L270).
Nearby already has `@ObservableState`, and all three affected test functions
run on `@MainActor`. Replace each identity closure with `store.state`; retain
the captured previous values, comparison timing and existing assertions.

The preserved scenarios are callback rejection outside the lifetime (one test),
old location results with the newer check pending/resolved (two parameter cases),
and old fleet success/failure with newer work pending/complete (four parameter
cases). Require all seven executions and the full native suite to pass, with zero
deprecation diagnostics on both local and hosted compilers. Final qualification
and counts are recorded on the review PR containing this change.

This removes eight closures and adds no helper, dependency or workaround.
App behavior and the IOS-02, IOS-13 and IOS-16 boundaries stay separate. This
Swift test API change has no Android behavior delta.

## WARN-07: unused native results

Recorded 2026-11-07. The [successful CI #600 iOS job](https://github.com/Mekate-Studio/Mobi/actions/runs/42372565618/job/128403566003)
at `aa9048eb8e6d4edc32e2ce0c759b79adb27d5464` emitted one unused `StoreTask?`
return warning at the Home button callback. The [successful CI #590 Android test job](https://github.com/Mekate-Studio/Mobi/actions/runs/42292771869/job/128150281754)
and [Debug build job](https://github.com/Mekate-Studio/Mobi/actions/runs/42292771869/job/128150281904)
at `c8ed8540ec49be932ae11e9ba49015e72b2a9241` each emitted one unused-expression
diagnostic at the explicit `Unit` in `NativeMapOverlay`'s `None` branch.
That Android source and its selected build configuration are unchanged between
this baseline and the cleanup's main base, `8a3d3ec84afcb5d9919bcbf20ad709a22e63ec97`.
These are targeted source diagnostics, not the total remaining warning count.

The Home UI callback now explicitly discards its return with `_ = refresh()`.
`HomeRefreshLifetime.refresh` still retains the admitted task, and its stop path
still cancels that task. The callback still invokes refresh once; rejection,
background/tab cancellation and late-result policy stay with the existing owner.
Android's `None` branch is an empty block, with the same no-content behavior;
banner and blocking branches are unchanged.

This is ordinary native-source maintenance. It adds no helper, dependency,
annotation or interop workaround. Existing iOS Home lifetime/admission and Android
Home/Nearby presenter/lifetime checks, plus both Debug builds, qualify the change.
The Android host tests do not establish device rendering or OS delivery behavior.
Final local/hosted results and targeted warning counts are recorded on the review
PR containing this change. Other warning categories remain in the backlog.

## WARN-08: Lifecycle declaration alignment

Recorded 2026-11-07, against main `217694fcef92b56a118bb7499d5a870365c641ea`.
The Android declaration changes from `2.9.4` to the already resolved
`2.11.0-beta01`. Home and Nearby directly import `LifecycleStartEffect`, so the
app keeps an explicit dependency for the API it uses.

The source of the beta is [Circuit 0.34.0's pinned Lifecycle version](https://github.com/slackhq/circuit/blob/0.34.0/gradle/libs.versions.toml).
Its published Android POMs show these paths, also present in Mobi's resolved graph:

- `circuit-foundation-android:0.34.0` → JetBrains `lifecycle-viewmodel-compose:2.11.0-beta01` → AndroidX ViewModel Compose → AndroidX `lifecycle-runtime-compose:2.11.0-beta01`.
- `circuit-retained-android:0.34.0` → JetBrains `lifecycle-runtime-compose:2.11.0-beta01` → AndroidX `lifecycle-runtime-compose:2.11.0-beta01`.

Toolchain 0.13.0 separately [defaults Compose to 1.12.1](https://github.com/JetBrains/kotlin-toolchain/blob/v0.13.0/sources/frontend-api/src/org/jetbrains/amper/frontend/schema/DefaultVersions.kt).
The compiler remains Mobi's explicit Kotlin 2.5.0-Beta2. Neither tuple changes.

Before/after `./kotlin show dependencies --all-modules --include-tests` output was
parsed with the existing `Maintenance::KotlinEvidence.graphs` parser for 0.13.0.
Both captures have **104 roots across nine modules**, with 19,247 printed nodes
and edges each, including request/repeated nodes rather than distinct artifacts.
Every root's module, usage, scope, platforms, edges and selected versions are
unchanged. The full parsed JSON differs at exactly 12 scalar fields: the direct
request label, selected-artifact display label and requested-version field in
each of Android's main/test × compile/runtime roots. All other raw fields match.

| Capture | Parsed JSON SHA-256 |
| --- | --- |
| Baseline | `579538b3b01205ef382586d1e16d25c2fe97a217c0b2250d3a95c98ac670d48b` |
| Candidate | `d1432aec1a8c7b5f50dd9b4e67478a75c47c3c6124ee5ef6c1e9e1b380111787` |

After omitting parsed requested-version fields/display labels and normalizing
only that direct request fragment label, both otherwise complete graphs have
SHA-256 `3bcdd74261104198e299fdf79324f1e1f77901f297c1b6aba0c3c6d697c2658c`
(sorted-key compact JSON). These are Toolchain Maven-graph comparisons, not
Native packaging or delegated Gradle graph fingerprints. The normal native
build/test gates separately qualify the actual integration. Final warning
counts and local/hosted results are recorded on the review PR.

**Stable-version follow-up:** the separate [2.11.0 qualification](evidence/2026-11-07-lifecycle-2.11-stable.md)
records the effective AndroidX upgrade, reviewed release interval, remaining
JetBrains version split and native lifetime/build checks. The original alignment
above only made the existing beta selection visible.
