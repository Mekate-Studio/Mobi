# ADR 0014: Android Nearby requests and location across host stop/start

Status: Accepted via [PR #71](https://github.com/Mekate-Studio/Mobi/pull/71).

## Decision

Native Nearby requests belong to each STARTED host lifetime. ON_STOP cancels
pending/queued requests and restores the existing cancellation-normalized ready
state synchronously. An initial load returns to Initial; a refresh returns to its
cached snapshot. Repository cancellation while still active keeps its existing
recovery. Paused-but-visible STARTED work may finish.

Every START revalidates location. A previously visible location first enters the
shared Resolving state with its cached snapshot and actions disabled. The existing
shared time policy ages retained failures before that check; known blocked decisions
stay blocked until the new platform result arrives. A precise result immediately
refreshes; temporary unavailability can reuse the cached position. No shared state,
API, threshold or failure policy changes.

## Native ownership and code cost

This extends [Home's ownership pattern](0013-android-home-visible-work-lifetime.md):
one supervised child request scope per STARTED lifetime and one composition-only
nullable handle for synchronous event callbacks. The cache remains typed data.
The child owner stays cancelled permanently after stop, while existing per-request
ensureActive checks reject old noncooperative success, failure and cancellation.
Callbacks while stopped or before the first START cannot change state or launch
work. After restart, retained intent callbacks read the current active owner.

A single LifecycleStartEffect now pairs timer and request ownership. The timer job
is a sibling of the child request scope under the composition scope. Precise or
blocked location updates can cancel request children without killing future ticks.
Both timer and requests cancel on stop/disposal; each START begins a full timer
delay. This replaces #70's separate timer scope/effect rather than adding another
parallel lifecycle protocol. Shared busy/freshness admission still gates ticks.

Location effects are extracted from rendering into one internal composable. The
existing [LifecycleEventEffect](https://developer.android.com/topic/libraries/architecture/lifecycle#lifecycleeventeffect)
checks Android state synchronously on START. Permission callbacks are ignored
while stopped, then START reads the current permission/location state. Visible
callbacks also re-read Android state instead of trusting a grants map that may be
obsolete; the old map-based resolver is removed. No deferred callback payload or
request identifier is stored. Platform location resolution remains synchronous
last-known-location lookup, not a new asynchronous provider.

The automatic permission prompt retains its once-per-composition policy. Its
LaunchedEffect waits for the first START using the existing lifecycle state flow;
subsequent START events recheck access without automatically prompting again.
This prevents stop/start after denial from causing repeated permission prompts.
The initial blocked result is still published before requesting permission.

The production diff adds **19 net lines across four files**, including the new
37-line location-effects file and removal of the old permission-map helper.
It adds one ephemeral scope handle; no retained payload, lifecycle flag, request
registry, dependency or interop workaround is added. This is ordinary native
lifetime handling. AND-01 still tracks the reused host harness.

## Evidence and limits

Checks use production Metro/Circuit content with a controllable LifecycleRegistry.
They cover initial/manual/automatic stop cancellation before recomposition, queued
admission, pre-start/stopped callbacks, location-gated restart, snapshot/failure
fallback, expiry, blocked decisions, retry, and old noncooperative completions
arriving before or after newer work finishes. Existing tab, cancellation, timer
and admission checks remain.

Additional host checks run the production location composable and resolver with
Robolectric's Android permission/location state and a controlled ActivityResult
registry. They cover first-START prompting, no repeat prompt after denial, result
payloads contradicting current permissions in both directions, stopped permission
completion, revocation/regrant and changed coordinates on return. These also
qualify presenter/UI lifecycle ordering in the real composition.

Actual OS Activity-event delivery, permission dialogs/settings interaction, map
rendering, recreation and process restoration remain unqualified. iOS scene work
lifetime and optional Shared Home require separate decisions and checks.
