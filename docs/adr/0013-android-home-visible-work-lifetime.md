# ADR 0013: Android Home request ownership while the host is visible

Status: Proposed for review with the Home visible-lifetime change.

## Decision

Native Home keeps the exact ready state from ADR 0010 while its host stops and
starts. Pending refresh work cancels on ON_STOP, and refresh callbacks do nothing
before ON_START or while stopped. Starting again allows manual retry using the
current retained value; it does not fetch automatically.

The boundary is STARTED, rather than RESUMED. A paused but still visible host can
finish work. This follows Android's existing
[LifecycleStartEffect contract](https://developer.android.com/topic/libraries/architecture/lifecycle#lifecyclestarteffect):
cleanup runs on stop or composition disposal. Cancellation is performed directly
by that cleanup, without waiting for a recomposition to remove content.

## State and work ownership

The ready-state cache stays unchanged and contains only typed feature data.
The remembered composition scope supplies its dispatcher and parent job. Each
STARTED lifetime creates one supervised child scope, cancelled permanently when
that lifetime ends. A composition-only nullable handle lets synchronous UI
callbacks find the currently owned scope. It holds no feature payload and is
neither saved nor retained.

On stop, cleanup cancels that scope, clears the handle and immediately restores
the ready state. Restoration does not wait for a provider to cooperate with
cancellation. On start, a new child scope is created. No lifecycle flag, request
identifier, request registry or additional feature cache is introduced.

A callback captures the current child scope before launching work. Existing
post-await `ensureActive` checks reject obsolete success/failure results. Existing
cancellation recovery now tests that captured child's lifetime: cancelling an
individual request while still visible restores its exact previous state, while
cancellation from an older stopped lifetime cannot overwrite a newer request.
Looking up the latest scope during recovery would confuse these two lifetimes.

## Cost and alternatives

This adds one ephemeral scope handle and a supervised child per visible lifetime.
Reusing the composition-wide owner and cancelling only its children is shorter,
but that owner becomes active for newer work while an old provider may still
return. The old cancellation catch could then restore its earlier state over a
new loading or loaded value. Keeping each owner permanently cancelled avoids
that race without a request registry or value-identity coupling.

The supported Lifecycle API is already in the current dependency graph. This is
ordinary native work ownership, not a Swift-export or build workaround. Shared
Kotlin state/API, repository behavior, dependency versions and shared refresh
admission rules are unchanged. AND-01 still governs the host-test harness.

## Qualification and remaining scope

Checks drive the production tab content through Metro and Circuit with an actual
host LifecycleRegistry; rendering is replaced by typed state recorders. They cover
all recorded Home ready values, pending and queued cancellation, callbacks while
stopped/before start, STARTED versus RESUMED, retry, and noncooperative old success,
failure or cancellation arriving while newer work is pending or complete.
Cancellation is asserted before advancing recomposition, qualifying the lifecycle
callback rather than a rendering-dependent gate. Existing presenter cancellation
and tab-lifetime checks still run through the same native fixture.

These host checks do not qualify OS Activity-event delivery, navigation-button
interaction, Activity recreation or process restoration. Android Nearby's visible
timer/location lifetime, optional Shared Home and iOS scene lifetime remain
separate decisions and runtime checks. This PR does not silently apply Home's new
policy to those consumers.
