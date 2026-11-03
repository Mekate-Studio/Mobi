# ADR 0018: iOS Home refresh lifetime across tab switches

Status: Tab lifetime accepted via [PR #76](https://github.com/Mekate-Studio/Mobi/pull/76); callback-admission extension proposed.

## Decision

Leaving Native Home cancels its owned refresh and restores the exact native
state from before loading, including zero and typed errors. Returning retains
that state and permits manual retry without fetching automatically. A cancelled
request cannot replace newer pending or completed work with a late result.

This supersedes ADR 0015's choice to preserve Home work across tab switches.
Its scene policy remains: background cancels; inactive/active changes preserve
visible pending work. Native Android Home already cancels hidden work while
retaining ready state; the platform lifecycle events remain distinct.

## Ownership and alternatives

The scene root retains the existing Home store. HomeRefreshLifecycle observes
the selected-tab input and scene phase around the actual TabView and owns the
existing HomeRefreshLifetime value. Deselection stops its StoreTask before
sending the reducer's recovery action. The reducer reuses refreshPreviousState;
the tab-cancellation slice added no payload cache, lifecycle flag, request
registry or shared API. The callback-admission extension below describes its
separate native UI value. The existing scene owner is moved into this wrapper rather than
kept alongside another owner.

Observing explicit tab selection avoids relying on whether SwiftUI retains a
tab's child view or emits disappearance at a particular point. Removing the
whole root also stops work. Automatic loading on return and continuing hidden
refreshes were considered; this decision keeps refresh user-driven and gives
hidden work a consistent cancellation boundary.

The wrapper is a small native ownership seam that also lets simulator checks
host the production lifecycle around real SwiftUI tabs. Its dispatch closure
uses the same owner as the production Home button. It does not introduce a
platform-independent lifecycle abstraction or change dependency versions.

PR #76 added 25 net runtime lines across five files, including the 23-line
wrapper, one cancellation action and a shared stop operation. The root loses
its separate owner and scene observer. Existing recovery state is unchanged.

## Callback admission extension

A retained Home UI callback must not start a refresh while Home is deselected,
its scene is backgrounded, or its containing view has been removed. Returning
reopens manual admission without fetching. Inactive visible Home remains eligible.
The boundary is HomeRefreshLifecycle's dispatch closure; shared business policy,
feature state and the existing StoreTask owner stay unchanged.

The proposed implementation keeps one private SwiftUI-managed admission Boolean,
initially false, in the existing view wrapper. Its transition uses the combined
selection/non-background input and closes admission before cancelling work.
Disappearance closes it too. A captured callback must read the managed value
when invoked, rather than a selection snapshot from the render that created it.
This is native UI lifetime state, with no request ID, registry or payload cache.
See Apple's [State storage contract](https://developer.apple.com/documentation/swiftui/state).
Actual retained-callback checks, not source resemblance, qualify that behavior.

The baseline at `7369135` and a shorter control that guarded only the render's
selection/scene inputs both failed the retained-callback-after-tab-exit case.
The managed-value implementation is qualified through the same host. The runtime
change is seven net lines in the existing wrapper, including one Boolean. The
callback returns an optional StoreTask so refusal does not manufacture a task or
send a reducer action. The earlier exact-state recovery and owner remain intact.

This cost belongs to MOB-08's supported-lifetime simplification review. A supported
route that reads current availability without this extra value may replace it
only after the same old-callback, initial-hidden/background, removal, inactive
continuity and return/retry checks pass. This is an ordinary native correctness
change; it introduces no Swift-export workaround or dependency version change.

## Qualification and simplification

Regression checks must exercise tab deselection, exact ready/error recovery,
return without fetching, retry, repeated selection and scene transitions, and
noncooperative old success/failure while newer work is pending or complete.
Existing background-before-effect-start, duplicate admission and inactive
continuity checks must remain green.

This extends the existing MOB-08 task-owner simplification obligation. On relevant
TCA/SwiftUI/Swift/Xcode updates, try the supported simpler lifetime route in the
actual tab/scene host and record retained/removal-ready/incomplete with native
results. Remove the adapter and redundant view plumbing only when all ownership
checks pass. The prior-value cache has its separate exact-recovery purpose.

These are simulator host checks with driven selection and scene inputs. Actual
user tab taps, OS scene-event delivery, device/minimum-OS behavior and
scene/process restoration remain outside that evidence. Retained UI callbacks
are qualified at the production dispatch boundary; direct reducer sends bypass
that UI boundary and remain the caller's responsibility.
Optional Shared Home stays separate. This is an application lifecycle change,
not a Swift-export workaround.
