# ADR 0016: iOS Nearby timer scheduling across scene backgrounding

Status: Proposed for review.

## Decision

Nearby's automatic timer stops scheduling ticks when its scene backgrounds.
Inactive/active transitions keep the current cadence. Leaving the view still
cancels the timer. Each return from background or view re-entry starts a full
existing ten-second delay; missed ticks are dropped rather than replayed.

The existing [SwiftUI task(id:) API](https://developer.apple.com/documentation/swiftui/view/task(id:priority:_:))
owns the loop. Its identity is whether the scene is outside background, not the
whole ScenePhase value. A whole-phase identity would restart the delay on inactive
interruptions. A background task body exits before sleeping; cancellation checks
prevent a completed/cancelled sleep from emitting an obsolete tick.

## Ownership and cost

A 23-line NearbyRefreshTimer ViewModifier separates scheduling from the existing
one-shot view-entry/location task. The view keeps dispatching its existing
visibleRefreshDue action with current wall-clock time. Shared freshness, location
and busy-state admission remain in the existing reducer/client. The sleep uses a
standard Clock with ContinuousClock as the production default, allowing virtual
time in tests without changing feature policy.

The runtime diff adds **17 net lines across two files**, including the extracted
modifier. No task handle, feature-state flag, cache, request registry or new
interop workaround is added. Unlike Home's scene-task owner, this loop is a
structured SwiftUI task and needs no additional lifetime adapter.

Clock test APIs were visible through TCA's transitive imports but failed to link
in the test bundle. MobiIOSTestDependencies explicitly links the already resolved
Clocks 1.0.6 and ConcurrencyExtras 1.3.2 products for appTests only. Its package,
project and export declarations add 22 lines. The app's product dependency list is
unchanged; no package version changes. This is an explicit test dependency, not a
build workaround. The runner and hosted workflow remain unchanged.

## Deliberate boundary

Only timer scheduling changes. Already launched refresh effects remain owned by
the retained store and can complete while backgrounded, updating the displayed
snapshot. Manual and location callbacks keep their current behavior. The location
entry task is separate, so timer resumption does not begin another location check
or cancel an admitted request. Request cancellation and location revalidation need
one coordinated subsequent slice, including the pre-start cancellation lesson in
MOB-08. No Home-style exact-state recovery policy is applied to Nearby here.

## Qualification

An actual UIHostingController runs the production modifier under controlled scene
inputs with a TestClock. Checks cover inactive/active cadence, recomposition,
initial background, repeated stop/return with a full delay, no replay, and view
removal/re-entry without duplicate timers. A production TCA store integration check
proves an admitted refresh survives backgrounding, preserves its snapshot while
pending, completes while stopped, and allows a later automatic refresh.

These simulator checks qualify SwiftUI task identity/cancellation under explicit
view/environment updates. They do not qualify OS scene event delivery, interactive
backgrounding, native map rendering or platform location delivery. Final local
checks use iOS 26.5; device, minimum-OS and process restoration are not claimed.
