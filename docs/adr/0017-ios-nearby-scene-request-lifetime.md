# ADR 0017: iOS Nearby request and location lifetime

Status: Proposed for review.

## Decision

Nearby location resolution and admitted fleet requests belong to the displayed
view's lifetime outside scene background. Background or view disappearance cancels
that work and enters the existing location-checking presentation. The snapshot
stays visible; loading normalizes through shared cancelledRefreshState. Returning
or re-entering first ages retained failures using shared policy, then resolves
current location before refresh or map actions become available. No new cache or
shared policy is introduced. Inactive/active interruptions preserve ongoing work.

A precise result starts the existing initial refresh. Temporary unavailability
uses shared cached-position fallback without automatically fetching; blocked
permission/accuracy/service outcomes use the existing blocked presentation. Each
return also retains #73's full timer delay and no-replay policy. Unlike #73's
scheduling-only stage, admitted work can no longer finish into background content.
View disappearance uses the same cleanup rather than leaving an unowned task.

## One request owner

NearbyVehicleMapLifetime retains one StoreTask outside feature state. start cancels
its predecessor before dispatching task; stop cancels and clears it synchronously
before dispatching suspend. UI callbacks are ignored without an active owner.
Manual, automatic and location-started work share this owner. Ignored busy actions
return an empty task and must not replace the admitted handle. The StoreTask from
location resolution also owns the refresh effect launched by its response.

The baseline regression against #73 demonstrates the pre-start cancellation-ID
gap: re-entry can arrive before an old refresh registers, and its completion then
replaces revalidated content. The direct task owner closes that gap. The old
CancelID, cancellable wrapper and cancellation-ID actions are removed, giving the
production path one cancellation mechanism. Runtime cancellation/supersession tests
now drive the owner; reducer state and shared cancellation tests remain.

NearbyVehicleMapLifecycle binds that owner to supported SwiftUI task(id:),
onChange and onDisappear APIs. The identity is outside-background status, preserving
inactive continuity. The task body rejects an already-cancelled start. All view
intents and timer ticks use its supplied dispatch closure. No independent location
callback, generation ID or task registry remains. Native hasCachedRiderLocation is
a computed projection of existing content; it lets return age failures even after
stop has entered checkingLocation. It stores no extra lifecycle state.

## Async Core Location boundary

The old mutable completion/delegate client is replaced by a one-result reader over
[CLLocationUpdate.liveUpdates](https://developer.apple.com/documentation/corelocation/cllocationupdate/liveupdates(_:)).
Apple documents its implicit When In Use authorization goal in
[What's new in location authorization](https://developer.apple.com/videos/play/wwdc2024/10212/).
The APIs and diagnostics are available below Mobi's iOS 26 floor; no fallback,
package update, new permission key or explicit full-accuracy prompt is added.

Each resolution creates a fresh sequence. It waits through an authorization prompt
or insufficient-use diagnostic, then returns the first meaningful result and
stops consuming updates. Global denial maps to servicesDisabled before local
accessDenied; restriction and reduced accuracy keep their distinct existing typed
reasons. A location is accepted only after those diagnostics. Location-unavailable,
sequence error or unexpected normal completion uses temporary fallback; task
cancellation emits no location result. TCA suppresses late sends from a cancelled
provider, including a noncooperative test provider.

This supported platform API replaces callback bookkeeping. It is not a Swift-export
workaround. The custom StoreTask owner is a native TCA timing adaptation and joins
[MOB-08's simplification review](../maintenance/mobile-feature-follow-ups.md#mob-08-home-scene-task-ownership-simplification)
on TCA/SwiftUI/Swift/Xcode updates. Removing it requires passing the same early/late
cancellation and hosted lifecycle cases without that owner. Record retained,
removal-ready or incomplete; do not remove it on version numbers alone.

## Cost and evidence

The production diff adds **20 net lines across seven files**. This includes the
34-line task owner, 23-line SwiftUI wrapper, and replacing the 105-line delegate
client with a 62-line async dependency/reader. It adds one optional task handle,
no stored payload or lifecycle flag. Dependency versions, project/build scripts,
Android behavior and shared business APIs remain unchanged.

The baseline pre-start check fails against #73. Deterministic production-store
checks exercise all three refresh triggers, cancellation/recovery with and without
a snapshot, busy events, location-to-refresh ownership, current blocked/fallback
results and obsolete location/fleet completion while newer work is pending or
complete. A UIHostingController runs the actual production lifecycle wrapper under
explicit phase/removal/re-entry updates, using controlled async clients. Reader
checks exercise nil updates, first-result termination, cancellation and errors.
Existing timer, interop, reducer and shared cancellation checks remain.

The host waits for SwiftUI onChange to acknowledge each scene/visibility input
before advancing to the next transition. Executor yields are not evidence that
SwiftUI consumed an update. The initial hosted run had 152 passing cases and a
one-minute timeout in the combined location-lifetime test; replacing the rendering
yield assumption with this acknowledgement passed 30 focused local repetitions
on the same iPhone Air/iOS 26.5 configuration. It changes test synchronization,
not the production lifetime policy or the one-minute test limit. The hosted
manual-request check also requires its dispatch callback before sending, so a
missing callback fails immediately rather than becoming a missing-request wait.

These checks do not synthesize CLLocationUpdate diagnostics or qualify real
CoreLocation delivery, permission dialogs/settings, OS scene delivery, map
rendering, device/minimum-OS execution or process restoration. They compile the
real async API and qualify orchestration with injected inputs. An interactive
permission/location check remains a separate follow-up, not a green simulator
claim. Optional Shared Home remains separate.
