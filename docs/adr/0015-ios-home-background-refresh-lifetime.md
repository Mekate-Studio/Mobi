# ADR 0015: iOS Home refresh lifetime when its scene backgrounds

Status: Accepted via [PR #72](https://github.com/Mekate-Studio/Mobi/pull/72).

## Decision

Home cancels an owned refresh when its scene becomes background and restores the
exact native state from before loading, including zero values and failure reason.
Inactive and active scene changes leave work alone. Returning does not fetch
automatically; the retained state allows the existing manual retry action.

The root that retains the Home store observes SwiftUI's scenePhase and sends that
value to the reducer, including its initial phase. This also handles backgrounding
while another tab is selected. Tab switching by itself retains its current work
policy; this decision does not add a view-disappearance cancellation rule.
The distinction between [background](https://developer.apple.com/documentation/swiftui/scenephase/background)
and [inactive](https://developer.apple.com/documentation/swiftui/scenephase/inactive)
is an explicit native policy, not a literal copy of Android STARTED events.

## State-retention cost

HomeCounterLoadable.loading contains only a previous integer. It cannot recover
whether that integer came from a loaded value or a repository/unexpected error,
and first-load projection can omit zero. Exact cancellation recovery therefore
adds one optional native refreshPreviousState value, present only for an owned
refresh. Refresh admission captures it before entering loading. Completion clears
it; background recovery restores it and clears it after the scene cancels work.
The missing value means there is no owned refresh to restore, not a missing domain
payload. No task, callback, lifecycle flag or request registry is stored in feature
state. The existing shared state contract and Sendable client values are unchanged.

The scene root also retains one runtime StoreTask through the 25-line
HomeRefreshLifetime value. Home's button dispatches through that owner. It keeps
the actual task returned by an admitted refresh, preserves that handle when a busy
refresh is ignored, and cancels/clears it before sending background recovery.
The task stays outside feature state. This uses TCA's supported
[StoreTask lifetime API](https://github.com/pointfreeco/swift-composable-architecture/blob/1.26.0/Sources/ComposableArchitecture/Store.swift#L564).

A control using only .cancellable/.cancel IDs passed started-request checks but
failed background-before-effect-start: the cancellation ID had not registered
when the scene changed. The actual StoreTask owner passes that timing check as
well as noncooperative late-result checks. TCA Send suppresses cancelled-task
responses, so there is no added try/catch or generation token. The unused
cancellation ID is removed from the final implementation.

The production diff adds **45 net lines across six files**, including the new
25-line owner. The pending prior value enables exact recovery; the separate runtime
task handle closes the observed effect-start gap. These costs are explicit.
The native lifetime adapter is tracked for simplification as
[MOB-08](../maintenance/mobile-feature-follow-ups.md#mob-08-home-scene-task-ownership-simplification)
on TCA/SwiftUI updates, with removal checks in the update workflow. No Swift-export
workaround, shared API, dependency or maintenance automation changes. Existing
IOS-13 suite serialization stays in force.

## Qualification and remaining work

The simulator checks run the production lifetime owner and store together, covering
all seven recorded ready states, cancellation recovery,
manual retry, repeated scene changes without fetching, and inactive/active changes
while work is pending. Controlled clients observe cancellation and deliberately
return old success/failure after a newer request is pending or complete. Existing
TestStore checks now also assert the pending value is cleared after completion;
Swift/Kotlin client cancellation and typed repository failures keep their existing
checks. Checks also cover background before the effect starts and a duplicate refresh
that must not discard the active task handle. Local final simulator evidence uses
iOS 26.5; two later attempts on iOS 27.1 stalled before test-host startup.

The scene callback is wired into the production root and compiled in the normal
iOS jobs. Tests drive scene inputs through production stores; actual OS scene
notification delivery and interactive background/foreground behavior are not
claimed as tested. Programmatic action admission while already backgrounded,
Home tab-exit cancellation, iOS Nearby scene/timer/location lifetime, scene/process
restoration and optional Shared Home remain separate decisions and checks.
