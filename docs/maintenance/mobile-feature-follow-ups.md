# Cross-platform mobile feature follow-ups

Reviewed against `3d8905ab98d27d3e68ff2bdc2e812b65495c27b9` on 2026-10-23.
The iOS changes below are merged. Android source review identifies applicability;
only the named executable checks qualify a counterpart. This list tracks ordinary
application improvements separately from the [interop workaround registry](interop-workarounds.md).

## Current assessment

| ID | Improvement and iOS evidence | Android assessment | Required follow-up or closure evidence |
| --- | --- | --- | --- |
| MOB-01 | Accurate blocking failure messages, [#54](https://github.com/Mekate-Studio/Mobi/pull/54) | Implemented: Android presentation reads the existing typed failure reason | Regression checks cover location/repository/unexpected reasons, with absent and retained snapshots, blocking and retry. Validation is reported in the implementation PR; Compose/device interaction is not claimed. |
| MOB-02 | Reject obsolete refresh results and preserve current location decisions, [#40](https://github.com/Mekate-Studio/Mobi/pull/40)/[#41](https://github.com/Mekate-Studio/Mobi/pull/41)/[#46](https://github.com/Mekate-Studio/Mobi/pull/46) | Open: `NearbyVehicleMapPresenter` assigns awaited results directly while location callbacks can change state | Exercise the actual presenter: blocked/degraded location during a request and a newer location request finishing before the older one. Retain the current location decision and newest applicable snapshot. State-producer delegation tests do not qualify this ordering. |
| MOB-03 | Let active work finish across visible timer ticks, [#53](https://github.com/Mekate-Studio/Mobi/pull/53) | Implemented: a composition-owned timer checks shared admission/freshness and awaits each automatic request | Actual Circuit presenter regressions under Robolectric/API 36 cover loading recomposition, a slow automatic request and subsequent refresh, a pending manual request, blocked location, a snapshot not due, and cancellation on composition disposal. This qualifies host Compose ownership; device interaction and navigation lifetime are outside this check. |
| MOB-04 | Deliberate cancellation recovery, [#42](https://github.com/Mekate-Studio/Mobi/pull/42)/[#51](https://github.com/Mekate-Studio/Mobi/pull/51) | Open: both presenters enter loading before awaiting services that rethrow `CancellationException` | Distinguish cancellation while the feature remains owned from composition disposal. Qualify the intended prior-state restoration and retry, including previous errors/snapshots. Preserve structured cancellation; do not copy Swift bridge error handling into direct Kotlin calls. |
| MOB-05 | Manual refresh admission, [#49](https://github.com/Mekate-Studio/Mobi/pull/49)/[#50](https://github.com/Mekate-Studio/Mobi/pull/50) | Partly present: Home checks `Loading`; Nearby checks `isRefreshInFlight`. Nearby does not use the full shared `canRequestRefresh` predicate at the callback boundary | Exercise rapid callbacks, blocked location, completion and retry in the actual presenter. Qualify the admission-to-loading transition and review freshness separately. Existing callback-wiring tests do not prove request exclusion. |
| MOB-06 | Feature lifetime across view re-entry, [#47](https://github.com/Mekate-Studio/Mobi/pull/47)/[#48](https://github.com/Mekate-Studio/Mobi/pull/48) | Needs platform review: presenters use ordinary `remember` and AppShell conditionally composes each destination | Establish the intended tab/back-stack lifetime using Circuit/Compose ownership, then test tab re-entry and recreation with loaded/error states. iOS `StateObject` is not an Android implementation recipe. |
| MOB-07 | Swift-export errors, service captures and generated support | Platform-specific: Android calls Kotlin directly | Keep IOS-prefixed bridge exceptions and retirement checks in the interop registry. Shared repository error/freshness rules already reach both platforms; Swift `KotlinError` handling and TCA executor constraints need no literal Android port. |

MOB-03 follows the documented
[Compose effect-key cancellation/restart contract](https://developer.android.com/develop/ui/compose/side-effects#launchedeffect).
The [presenter regressions](../../android-app/test/nearbyvehiclemap/NearbyVehicleMapPresenterTest.kt)
exercise the actual composition with virtual coroutine time and controlled repository completion.
The timer checks every ten seconds from composition entry; after an automatic request
finishes, it waits another interval. Each tick uses the existing shared freshness
and admission rules. A fresh, busy or blocked state stays unchanged by the timer.
Location changes during an already active request remain MOB-02; cancellation
recovery while the feature stays owned remains MOB-04.

## AND-01: Presenter host-test harness simplification

`android-app/module.yaml` adds Robolectric 4.16 and native access for host tests;
the presenter suite selects its runner and API 36 without app resources.
This compensates for the pinned Toolchain's Android schema not exposing Circuit's
[documented AGP stub-default setting](https://github.com/slackhq/circuit/blob/0.34.0/docs/testing.md).
Running the actual presenter without Robolectric currently fails in Android
logging/tracing stubs before qualifying feature behavior. The
[Toolchain example](https://github.com/JetBrains/kotlin-toolchain/tree/v0.13.0/sources/test-integration/test-projects/android/robolectric)
provides the supported current runner.

Recheck AND-01 when updating Toolchain, Circuit, Compose, Robolectric or the test
JDK. Review supported host configuration, then run all five presenter lifecycle
checks and the full Android host suite without Robolectric. If they pass on the
actual Android dependency variant, remove the redundant dependency, runner/SDK
annotations and native-access flag, and rerun the normal gate. Preserve the
runtime assertions; do not replace them with state-producer delegation tests.
Record **retained**, **ready for removal** or **incomplete**, with the executed
checks, in the update PR. This is a manual adoption-review step; the iOS interop
watch does not emit AND-01 assessments or poll Circuit/Robolectric releases.

The Android surfaces are:

- [Nearby presenter](../../android-app/src/nearbyvehiclemap/NearbyVehicleMapPresenter.kt)
  and [state producer](../../android-app/src/nearbyvehiclemap/NearbyVehicleMapPresenterStateProducer.kt).
- [Nearby presentation](../../android-app/src/nearbyvehiclemap/NearbyVehicleMapPresentation.kt)
  and [presentation regressions](../../android-app/test/nearbyvehiclemap/NearbyVehicleMapPresentationTest.kt).
- [Home presenter](../../android-app/src/home/HomePresenter.kt),
  [Home state producer](../../android-app/src/home/HomePresenterStateProducer.kt)
  and [app shell](../../android-app/src/AppShell.kt).

## Keep the assessment current

For each native correctness or presentation PR, assess the other consumers and
record **already shared**, **counterpart present**, **open**, or **platform-specific**.
Link the actual implementation and regression evidence. Keep an open item open
until the owning runtime is exercised; source resemblance and a shared service
unit test do not qualify Compose lifecycle or TCA effects.

Keep each implementation slice small. Changes to shared product policy require
shared tests; native lifecycle fixes require their platform's ownership and
cancellation checks. An interface, scheduler, or new state owner needs its own
review rather than becoming an incidental parity abstraction. This list does not
adopt dependencies, retire workarounds, or schedule automatic ports.
