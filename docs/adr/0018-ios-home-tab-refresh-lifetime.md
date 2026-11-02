# ADR 0018: iOS Home refresh lifetime across tab switches

Status: Proposed.

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
no additional payload cache, lifecycle flag, request registry or shared API is
introduced. The existing scene owner is moved into this wrapper rather than
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

The runtime delta is 25 net lines across five files, including the 23-line
wrapper, one cancellation action and a shared stop operation. The root loses
its separate owner and scene observer. Existing recovery state is unchanged.

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
scene/process restoration remain outside that evidence. Programmatic refresh
callbacks issued after their UI lifetime ends remain a separate admission
qualification; this change cancels work owned at the selection boundary.
Optional Shared Home stays separate. This is an application lifecycle change,
not a Swift-export workaround.
