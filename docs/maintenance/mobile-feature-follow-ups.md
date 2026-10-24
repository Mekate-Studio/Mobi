# Cross-platform mobile feature follow-ups

Reviewed against `e73075fdab45e9323dd7e0ab59842c01f932c272` on 2026-10-23.
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
| MOB-05 | Manual refresh admission, [#49](https://github.com/Mekate-Studio/Mobi/pull/49)/[#50](https://github.com/Mekate-Studio/Mobi/pull/50) | Nearby implemented: queued callback work checks current shared `canRequestRefresh` and enters loading before suspension. Home still checks `Loading` before launching; queued admission needs its own runtime qualification | Nearby presenter checks cover rapid mixed manual/visible callbacks, a busy request, completion, every blocked-location reason with/without a snapshot, location becoming blocked before dispatch, resolving location, repository failure and manual retry while fresh. Home admission remains open. Explicit `VisibleRefreshDue` freshness remains separate; this slice preserves its existing shared callback route. |
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

MOB-05's Nearby admission checks run the real presenter on a queued test dispatcher.
They read current state after dispatch and qualify admission-to-loading without a
suspension in between. Manual refresh and repository-failure retry still bypass
freshness; the automatic timer retains its existing freshness check. This is
native callback correctness, with no added shared state or interop workaround.

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
JDK. Review supported host configuration, then run all presenter lifecycle and
admission checks and the full Android host suite without Robolectric. If they pass
on the actual Android dependency variant, remove the redundant dependency, runner/SDK
annotations and native-access flag, and rerun the normal gate. Preserve the
runtime assertions; do not replace them with state-producer delegation tests.
Record **retained**, **ready for removal** or **incomplete**, with the executed
checks, in the update PR. This is a manual adoption-review step; the iOS interop
watch does not emit AND-01 assessments or poll Circuit/Robolectric releases.

## AND-02: Toolchain JDK download header limit

On 2026-10-24, Toolchain 0.13.0's automatic Temurin 25 download failed before
compilation in its HTTP response-header parser: `TooLongLineException` with an
8,192-character limit. The observed GitHub response had a 9,242-character CSP
header. The same failure occurred in
[hosted Home validation](https://github.com/Mekate-Studio/Mobi/actions/runs/40071276148/job/120805064097).

The current accommodation supplies JDK 25 through the supported `JAVA_HOME` path.
Mobile workflows use `setup-java` to declare that already-required major; local
jobs can select an installed JDK. The Xcode test/build wrappers and Fastlane
archive arguments forward that selection as a build setting: observed Xcode
phases otherwise replaced the parent JDK 25 with a local JDK 19. This is a
cross-platform build limitation, despite its Android CI discovery. It leaves
the Toolchain and its HTTP client unchanged. A passing installed-JDK run does not qualify automatic download.
The explicit matching JDK declaration is a normal build prerequisite that can
remain useful after the download limitation is fixed.

On Toolchain/bundled HTTP-client or provider changes, review the pinned upstream
provisioning requirements and recheck automatic JDK provisioning from empty caches
without a matching installed `JAVA_HOME`. Record retained/removal-ready/incomplete
status and actual results in the update PR. Retire this download accommodation only
after the cold route and the normal native jobs pass. Keep declared CI JDKs aligned
with the selected Toolchain requirements. This manual check is outside the iOS
interop report; it adds no schedule or automatic toolchain adoption.
Runtime declarations also apply to gated release workflows; smoke checks do not
qualify credentialed archive, signing or publication.

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
