# Cross-platform mobile feature follow-ups

Reviewed against `8b281df839abc7273d60485fe446d0820360e8d3` on 2026-10-23.
The iOS changes below are merged. Android source review identifies applicability;
only the named executable checks qualify a counterpart. This list tracks ordinary
application improvements separately from the [interop workaround registry](interop-workarounds.md).

## Current assessment

| ID | Improvement and iOS evidence | Android assessment | Required follow-up or closure evidence |
| --- | --- | --- | --- |
| MOB-01 | Accurate blocking failure messages, [#54](https://github.com/Mekate-Studio/Mobi/pull/54) | Implemented: Android presentation reads the existing typed failure reason | Regression checks cover location/repository/unexpected reasons, with absent and retained snapshots, blocking and retry. Validation is reported in the implementation PR; Compose/device interaction is not claimed. |
| MOB-02 | Reject obsolete refresh results and preserve current location decisions, [#40](https://github.com/Mekate-Studio/Mobi/pull/40)/[#41](https://github.com/Mekate-Studio/Mobi/pull/41)/[#46](https://github.com/Mekate-Studio/Mobi/pull/46) | Open: `NearbyVehicleMapPresenter` assigns awaited results directly while location callbacks can change state | Exercise the actual presenter: blocked/degraded location during a request and a newer location request finishing before the older one. Retain the current location decision and newest applicable snapshot. State-producer delegation tests do not qualify this ordering. |
| MOB-03 | Let active work finish across visible timer ticks, [#53](https://github.com/Mekate-Studio/Mobi/pull/53) | Open: `LaunchedEffect(featureState)` starts refresh and changes its own key to loading; refreshing states remain snapshot-backed | Qualify Compose effect cancellation/restart with a request held longer than the timer interval. Verify one active refresh, successful completion, subsequent refresh, and no timer work while location is blocked. Treat the source-observed risk as unqualified until this test runs. |
| MOB-04 | Deliberate cancellation recovery, [#42](https://github.com/Mekate-Studio/Mobi/pull/42)/[#51](https://github.com/Mekate-Studio/Mobi/pull/51) | Open: both presenters enter loading before awaiting services that rethrow `CancellationException` | Distinguish cancellation while the feature remains owned from composition disposal. Qualify the intended prior-state restoration and retry, including previous errors/snapshots. Preserve structured cancellation; do not copy Swift bridge error handling into direct Kotlin calls. |
| MOB-05 | Manual refresh admission, [#49](https://github.com/Mekate-Studio/Mobi/pull/49)/[#50](https://github.com/Mekate-Studio/Mobi/pull/50) | Partly present: Home checks `Loading`; Nearby checks `isRefreshInFlight`. Nearby does not use the full shared `canRequestRefresh` predicate at the callback boundary | Exercise rapid callbacks, blocked location, completion and retry in the actual presenter. Qualify the admission-to-loading transition and review freshness separately. Existing callback-wiring tests do not prove request exclusion. |
| MOB-06 | Feature lifetime across view re-entry, [#47](https://github.com/Mekate-Studio/Mobi/pull/47)/[#48](https://github.com/Mekate-Studio/Mobi/pull/48) | Needs platform review: presenters use ordinary `remember` and AppShell conditionally composes each destination | Establish the intended tab/back-stack lifetime using Circuit/Compose ownership, then test tab re-entry and recreation with loaded/error states. iOS `StateObject` is not an Android implementation recipe. |
| MOB-07 | Swift-export errors, service captures and generated support | Platform-specific: Android calls Kotlin directly | Keep IOS-prefixed bridge exceptions and retirement checks in the interop registry. Shared repository error/freshness rules already reach both platforms; Swift `KotlinError` handling and TCA executor constraints need no literal Android port. |

MOB-03 is an inference from the presenter source and the documented
[Compose effect-key cancellation/restart contract](https://developer.android.com/develop/ui/compose/side-effects#launchedeffect).
It is not a measured Mobi lifecycle result. The runtime checks in the table remain required.

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
