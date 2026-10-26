# ADR 0011: Android Nearby state across native tab switches

Status: Accepted via [PR #66](https://github.com/Mekate-Studio/Mobi/pull/66).

## Decision

Nearby retains its snapshot and location/failure decision across native tab
switches within the same app shell/service instance. Requests and the visible
timer remain composition-owned and cancel when the tab leaves. The keyed Circuit
provider and stable Circuit/service identity follow
[ADR 0010](0010-android-home-tab-state-lifetime.md).

On return, a previously visible location enters the existing shared `Resolving`
state. The cached snapshot remains visible with a "Checking location" banner;
shared admission and interaction predicates disable actions until a new location
result arrives. The location-loss demo button also honors the existing interaction
predicate. A known blocked decision keeps its existing blocking presentation.
A blocked location does not use the cached-map display fallback.

The existing UI location effect runs on each entry. It publishes a missing-
permission result before launching the permission prompt. A precise result keeps
the existing immediate refresh behavior, including repeated coordinates. Temporary
location loss can reuse the retained last position; blocked results cancel queued
or active request work and preserve the shared blocking state. The timer restarts
at its normal interval and continues to use shared admission/freshness rules.

## State and work ownership

Like Home, Nearby keeps one retained typed value and one composition-owned visible
value. Nearby's cache has a different normalization policy: every accepted state
write stores `cancelledRefreshState()` in the retained cell. Loading therefore
caches Initial, and Refreshing caches Loaded with the same snapshot. Existing
ready failures and blocked/degraded decisions are preserved. Starting a retry
normalizes its cache using the existing Nearby cancellation policy, rather than
Home's exact previous-error restoration.

A local `applyState` function owns both writes and rejects callbacks whose
composition scope is no longer active. The existing per-request `ensureActive()`
checks separately reject superseded jobs while the composition still exists.
These checks protect different lifetimes; no request registry or additional
state flags are introduced. Jobs, presenters, callbacks and map views are not
retained.

On entry, visible-location failures use the shared service's existing
`stateAfterTimePasses` policy before rendering. This accounts for a failure's
stale window expiring while hidden. A temporary-unavailability result restores
only the cached location into that current state, preserving the aged failure
and overlay. Known blocked state bypasses this visible-location aging path.
No freshness thresholds or failure rules are duplicated in native code.

## Costs and review decisions

- One additional typed cache cell and a local state-write function distinguish
  retained values from visible loading and work.
- The existing Resolving variant now has a native cached-map presentation.
  Its "Checking location" banner describes cached data; actions remain disabled.
- A blocked result cancels pending requests as well as updating typed state,
  preventing an earlier queued precise result from replacing that decision.
- Nearby's shared cancellation normalization deliberately differs from Home's
  exact ready-state restoration. This preserves existing Nearby policy.

The selected Circuit APIs already exist in 0.34.0. This is ordinary native
lifetime/presentation design, with no new dependency, shared API, serializer,
interop workaround or retirement condition. Future Circuit/Compose simplification
must preserve the lifecycle checks; AND-01 still governs the host-test harness.

## Evidence and remaining scope

The shared native-tab fixture uses the production destination-content function,
Metro's real factories and Circuit's Android lifecycle registry. Only rendering
is replaced by typed state recorders. Home's existing checks continue to run.
Nearby checks cover retained data and decisions, disabled actions during
revalidation, precise and fallback location, failure expiry, hidden initial/
manual/automatic cancellation, timer restart, queued location ordering, and old
responses/callbacks after re-entry.

Location results are driven through the production event sink in host tests.
OS permission dialogs, platform location delivery, native map rendering,
navigation-button interaction, Activity foreground/recreation and process
restoration remain unqualified here. Optional Shared Home remains separate.
iOS already retains its stores and rechecks location; its cached-map action gating
and expiry-on-re-entry need their own runtime qualification before adopting this
Android presentation policy.

## Host timer follow-up

Accepted via [PR #70](https://github.com/Mekate-Studio/Mobi/pull/70).

The timer waits for STARTED, stops on ON_STOP/disposal, and restarts a full interval
on return without replaying missed ticks. Paused-but-visible hosts keep cadence.
The first slice changed scheduling only and left admitted requests composition-owned.

[ADR 0014](0014-android-nearby-visible-request-lifetime.md) extends that decision to
request cancellation and location revalidation. It consolidates the separate timer
scope/effect into one start/stop owner with separate timer/request children, retaining
location supersession and shared admission. The original scheduling-only behavior
is superseded by that follow-up; its timer regression cases remain covered.
