# Cross-platform mobile feature follow-ups

Reviewed against `d3b5082529b55262bfa184088e6f7ab4bc0d8f40` on 2026-10-24.
The iOS changes below are merged. Android source review identifies applicability;
only the named executable checks qualify a counterpart. This list tracks ordinary
application improvements separately from the [interop workaround registry](interop-workarounds.md).

## Current assessment

| ID | Improvement and iOS evidence | Android assessment | Required follow-up or closure evidence |
| --- | --- | --- | --- |
| MOB-01 | Accurate blocking failure messages, [#54](https://github.com/Mekate-Studio/Mobi/pull/54) | Implemented: Android presentation reads the existing typed failure reason | Regression checks cover location/repository/unexpected reasons, with absent and retained snapshots, blocking and retry. Validation is reported in the implementation PR; Compose/device interaction is not claimed. |
| MOB-02 | Reject obsolete refresh results and preserve current location decisions, [#40](https://github.com/Mekate-Studio/Mobi/pull/40)/[#41](https://github.com/Mekate-Studio/Mobi/pull/41)/[#46](https://github.com/Mekate-Studio/Mobi/pull/46) | Native Nearby implemented: completion preserves current location decisions, and a new precise location supersedes earlier refresh work | Actual presenter checks cover blocked/degraded completion and overlapping requests, including repeated coordinates, changed coordinates, queued location events, old/new success or failure, late noncooperative completion, manual cancellation/retry and timer survival. Host checks qualify native result ownership; device location delivery is outside this evidence. |
| MOB-03 | Let active work finish across visible timer ticks, [#53](https://github.com/Mekate-Studio/Mobi/pull/53) | Implemented: a composition-owned timer checks shared admission/freshness and awaits each automatic request | Actual Circuit presenter regressions under Robolectric/API 36 cover loading recomposition, a slow automatic request and subsequent refresh, a pending manual request, blocked location, a snapshot not due, and cancellation on composition disposal. This qualifies host Compose ownership; device interaction and navigation lifetime are outside this check. |
| MOB-04 | Deliberate cancellation recovery, [#42](https://github.com/Mekate-Studio/Mobi/pull/42)/[#51](https://github.com/Mekate-Studio/Mobi/pull/51) | Native Home/Nearby implemented for their recorded ownership cases; optional Shared Home remains open | Home checks cover exact previous-state recovery and retry for repository-thrown and owned-job cancellation. Nearby checks cover active-job repository cancellation, retained/absent snapshots, earlier failures, degraded/blocked location, retry, timer survival and obsolete-request rejection. Supersession/disposal cancel Nearby jobs and skip recovery. A future independent cancel action while Nearby remains owned needs its own policy/runtime checks; optional Shared Home needs its own rendering-runtime qualification. |
| MOB-05 | Manual refresh admission, [#49](https://github.com/Mekate-Studio/Mobi/pull/49)/[#50](https://github.com/Mekate-Studio/Mobi/pull/50) | Native Home/Nearby implemented: admission and loading share a nonsuspending segment after dispatch. Home resolves its current counter there; Nearby uses shared `canRequestRefresh`. Optional `SharedHomeScreen` still checks before launching; that source-observed risk is unqualified | Nearby checks cover rapid/busy callbacks, completion, blocked/resolving location and retry. Home checks cover queued duplicates, busy rejection, completion, retained callbacks using current values, repository-failure retry with absent/previous values, and disposal. Shared Compose Home admission needs its own rendering-runtime check. Android automatic refresh uses the presenter-owned timer and shared freshness; its unused `VisibleRefreshDue` UI event is removed. iOS still emits its own visible-refresh action. |
| MOB-06 | Feature lifetime across view re-entry, [#47](https://github.com/Mekate-Studio/Mobi/pull/47)/[#48](https://github.com/Mekate-Studio/Mobi/pull/48) | Native Home/Nearby tab-state lifetime implemented for recorded cases; optional Shared Home remains open | Actual tab-content checks cover Home ready-state restoration and Nearby snapshot/decision retention, location revalidation, failure expiry, hidden-request/timer cancellation and restart, retry, queued location ordering, and rejection of old responses/callbacks. See [ADR 0010](../adr/0010-android-home-tab-state-lifetime.md) and [ADR 0011](../adr/0011-android-nearby-tab-state-lifetime.md). Foreground/recreation/process restoration, device interaction and the iOS revalidation/aging counterpart still need qualification. |
| MOB-07 | Swift-export errors, service captures and generated support | Platform-specific: Android calls Kotlin directly | Keep IOS-prefixed bridge exceptions and retirement checks in the interop registry. Shared repository error/freshness rules already reach both platforms; Swift `KotlinError` handling and TCA executor constraints need no literal Android port. |

MOB-03 follows the documented
[Compose effect-key cancellation/restart contract](https://developer.android.com/develop/ui/compose/side-effects#launchedeffect).
The [presenter regressions](../../android-app/test/nearbyvehiclemap/NearbyVehicleMapPresenterTest.kt)
exercise the actual composition with virtual coroutine time and controlled repository completion.
The timer checks every ten seconds from composition entry; after an automatic request
finishes, it waits another interval. Each tick uses the existing shared freshness
and admission rules. A fresh, busy or blocked state stays unchanged by the timer.
Nearby location supersession is qualified under MOB-02; its recorded
cancellation-recovery cases are qualified under MOB-04.

MOB-05's [Home](../../android-app/test/home/HomePresenterTest.kt) and
[Nearby](../../android-app/test/nearbyvehiclemap/NearbyVehicleMapPresenterTest.kt)
admission checks run the real presenters on a queued test dispatcher. They read
current state after dispatch and qualify admission-to-loading without a suspension
in between. Home's native callback carries refresh intent; an older screen callback
cannot supply an obsolete counter value. The iOS Home reducer already reads its
current value in the admitted action. Optional Shared Home still needs its own
runtime qualification; native presenter checks do not qualify its UI callback.
Manual refresh and repository-failure retry still bypass
freshness; the automatic timer retains its existing freshness check. Android's
[UI](../../android-app/src/nearbyvehiclemap/NearbyVehicleMapUiFactory.kt) emits
manual refresh intent, while the presenter owns automatic timing. The unused
Android `VisibleRefreshDue` event and adapter branch are removed: adding another
callback would duplicate an automatic path with no production caller. The
existing routing check now exercises the actual manual event, and queued
manual-duplicate coverage remains intact. iOS keeps `visibleRefreshDue` because
its view emits that action and its reducer applies shared freshness. This is
native contract cleanup, with no new shared state, policy or interop workaround.

MOB-02's Nearby completion checks run the actual presenter with controlled
repository completion. A single local refresh function serves initial-location,
manual and timer requests. After the await, it reads the currently owned location
decision: blocked state remains untouched; visible state accepts the returned
snapshot/failure while retaining its current location variant. The existing iOS
reducer already guards blocked completion and preserves the current location.
All refresh jobs now run in the existing composition-owned request scope. A new
precise location [cancels its children](https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines/cancel-children.html)
before launching the replacement, including when coordinates repeat. The scope
itself remains active for later refreshes. A post-await
[`ensureActive`](https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines/ensure-active.html)
rejects a provider result returned after cancellation. The independently owned
timer [joins](https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines/-job/join.html)
each automatic job; cancelling that request does not cancel the timer. Its
admission/freshness check runs inside the request job, before loading. The iOS
counterpart already uses cancellation of superseded refresh effects.
This is ordinary native result application, with no new shared API, request
registry, state flags or interop workaround. The request scope must remain
exclusive to refresh work; unrelated jobs would otherwise be cancelled too.
Cancellation is cooperative: the host fixture deliberately returns late to
qualify result rejection, not termination of an external provider. Device
location delivery is not qualified by the host checks.

MOB-04's native Home check runs both cancellation modes from initial state,
loaded zero/positive values, and repository/unexpected errors with absent or
retained values. The presenter captures its previous typed state at admission,
restores it only while its composition-owned scope remains
[`active`](https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines/is-active.html),
then rethrows cancellation. The owning scope and the individual request job have
different lifetimes: a cancelled child can recover the visible state while its
owner still exists; disposal cancels the owner too. The existing disposal check
continues to assert cancellation of both the request and its pending repository
response. Existing typed repository-failure behavior stays shared and unchanged.
The iOS Home client already restores the previous state on cancellation. This
is ordinary native lifecycle handling, with no new shared API, state flag or
interop workaround. Optional Shared Home still assigns `service.refresh`
directly and needs its own runtime qualification; native presenter evidence does
not qualify that consumer.

Nearby's [cancellation checks](../../android-app/test/nearbyvehiclemap/NearbyVehicleMapCancellationTest.kt)
run the actual presenter. It uses the existing shared
`cancelledRefreshState()` transition, matching its iOS client: loading becomes initial, refreshing becomes loaded with the same
snapshot, and the loading overlay clears. This deliberately does not restore an
earlier error as Home does. Recovery reads the current state, preserving a
blocked or temporarily unavailable location decision. The checks include
cancellation during retries after repository/unexpected failures, with absent
and retained snapshots.

A repository-thrown `CancellationException` can leave the Nearby request job
active. The catch checks the current job with
[`ensureActive`](https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines/ensure-active.html)
before applying recovery, then rethrows cancellation. Supersession and disposal
cancel that job, so they skip recovery even if the composition scope remains
active for a replacement. A composition-scope check alone would let obsolete
cancellation reset the replacement's loading state. The timer joins the cancelled
request and continues on its next interval. No new shared API, state flag,
request registry or interop workaround is introduced. The production shell has
no independent user-cancel action; adding one while Nearby stays owned requires
an explicit recovery policy and runtime evidence rather than reusing the
supersession behavior implicitly.

MOB-06's [Home tab checks](../../android-app/test/home/HomeTabLifetimeTest.kt)
render the production `AppDestinationContent` through Circuit and switch between
Native Home and Nearby through Metro's real factories with recorded UIs and
Android lifecycle owners. The content owner memoizes the graph's Circuit lookup
so tab recomposition preserves service identity. Home's initial/loaded/error ready value
uses Circuit's keyed retention provider; visible loading and jobs remain
composition-owned. Leaving during a refresh cancels the job and returns to the
prior ready value on re-entry. A late cancelled response cannot update the
retained value after a newer request completes. The extra ready-state cell and
service-identity input are review decisions in ADR 0010, rather than an interop
workaround. This qualifies native content ownership, not navigation-button
interaction, Activity recreation or process restoration.

The [Nearby tab checks](../../android-app/test/nearbyvehiclemap/NearbyTabLifetimeTest.kt)
share the same native fixture and keep the existing Home checks. Nearby retains
the shared cancellation-normalized value, cancels hidden requests and timer work,
and returns visible cached location to Resolving. A cached snapshot is shown with
"Checking location" and disabled actions until the new result arrives; known
blocked decisions keep their existing blocking presentation. Precise resolution
still refreshes immediately, while temporary loss can use the last position and
the timer continues to honor shared freshness. Expired failure overlays use the
existing shared time policy. A blocked result cancels older queued precise work.
The owner guard rejects callbacks from a disposed composition; per-request
cancellation checks reject superseded results. These are ordinary native ownership
rules, with no new interop workaround, state flag or shared API.

The production UI rechecks location on entry and publishes missing permission
before prompting. Host checks drive result events; they do not qualify OS dialogs,
platform location delivery or map rendering. iOS already retains stores and
rechecks location, but the cached-map action-gating and expiry-on-return cases
remain an explicit iOS counterpart review. Optional Shared Home, Activity
foreground/recreation and process restoration remain separate.

## AND-01: Presenter host-test harness simplification

`android-app/module.yaml` adds Robolectric 4.16 and native access for host tests;
the presenter suites select their runner and API 36 without app resources.
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

## AND-02: Toolchain distribution download header limit

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
the Toolchain and its HTTP client unchanged. A passing installed-JDK run does not
qualify automatic download.

Hosted prerequisite runs hit the same parser limit downloading
`kotlin-native-prebuilt:2.4.20` from both direct Maven Central endpoints,
`repo1.maven.org` and `repo.maven.apache.org`, before JDK selection or tests.
The producer selects [Google's documented public Maven Central mirror](https://docs.cloud.google.com/docs/buildpacks/java#google_cloud_hosted_maven_central_mirror)
through the pinned Toolchain's supported
[`KOTLIN_DEFAULT_MAVEN_CENTRAL_URL` setting](https://github.com/JetBrains/kotlin-toolchain/blob/v0.13.0/sources/libraries/maven-central-configuration/src/org/jetbrains/amper/mavencentral/mavenUtil.kt).
Its [native provisioner](https://github.com/JetBrains/kotlin-toolchain/blob/v0.13.0/sources/amper-kotlin-native/src/org/jetbrains/amper/kotlin/native/konanDistributionProvisioning.kt)
uses that setting for the distribution too. This adds a public mirror dependency
for the producer's Toolchain resolution, including dependencies, with the same
coordinates and compiler version. There is no custom transport or injected cache;
an explicit endpoint selection is preserved. Hosted results qualify this route
separately; a local pass cannot qualify hosted cold downloads.
The explicit matching JDK declaration is a normal build prerequisite that can
remain useful after the download limitation is fixed.

On Toolchain/bundled HTTP-client or provider changes, review the pinned upstream
provisioning requirements and recheck automatic JDK provisioning from empty caches
without a matching installed `JAVA_HOME`, and recheck the default Maven Central
endpoint without the producer override. Record retained/removal-ready/incomplete
status and actual results in the update PR. Retire this download accommodation only
after the cold routes and the normal native jobs pass. Remove the producer
endpoint default once the unmodified route passes. Keep declared CI JDKs aligned
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
- [Optional Shared Home](../../shared-ui-home/src/HomeContent.kt), whose admission
  callback remains a source-only follow-up.

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
