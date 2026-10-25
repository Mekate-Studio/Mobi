# ADR 0012: iOS Nearby location revalidation on view entry

Status: Accepted via [PR #67](https://github.com/Mekate-Studio/Mobi/pull/67).

## Decision

The retained Nearby store rechecks location on each view task. A previously
visible location is treated as cached until that request resolves. The map keeps
its snapshot visible with a "Checking location" banner, while manual refresh,
visible timer refresh and vehicle interactions are disabled. Without a snapshot,
the view waits for location. Known blocked decisions keep their blocking display.

State stores one native value: preparing, checking with the retained shared state,
or ready with shared state. This replaces the optional stored shared value; the
existing `sharedState` property becomes a read-only projection. There is no second
snapshot/location cache or independent checking flag. The checking case retains
the previous location even when no snapshot exists. Replacing that location with
shared Resolving would otherwise discard the position needed by temporary-loss
fallback.

Shared Kotlin still owns the precise, blocked and temporarily-unavailable
transitions. A result unwraps the checking value through those existing client
operations and returns to ready. Precise results keep the existing immediate
refresh behavior. Temporary failure can reuse the previous position; known
blocked state cannot supply a visible position. No shared state algebra or
service API changes.

Starting a new check cancels the old refresh effect and uses existing shared
cancellation normalization so its Loading/Refreshing value cannot leave retry
stuck after a temporary location result. The existing TCA cancellation identifier
is reused. The reducer rejects refresh results while location is being checked.
The simulation button honors the existing interaction predicate.

## Costs and boundaries

- A small native enum adds an explicit presentation phase around one shared value.
  The typed case is preferable here to a boolean plus a separate previous-value
  cache. It is ordinary native presentation design, not a Swift-export workaround.
- TCA owns refresh effect cancellation and suppresses sends from cancelled effects.
  No UUID, request registry, new client operation or dependency is introduced.
- The retained store is unchanged. This does not adopt Android's retained cache
  mechanics or change iOS work lifetime merely to match Android.
- The initial decision gated current-location use. Failure aging on re-entry is
  covered by the focused follow-up below.
- Existing IOS-02 unchecked shared-state crossings remain unchanged and retain
  their existing retirement checks in the interop registry.

## Qualification

Reducer/store checks cover retained maps, no-snapshot fallback, action/timer
admission, blocked decisions, precise resolution, temporary failure, and an old
provider completing after the check begins. Existing exhaustive TestStore cases
continue to qualify shared-result and reducer transitions.

These checks drive actions in the owning TCA runtime. They do not qualify
CoreLocation delivery, permission dialogs, actual tab/view task scheduling,
SwiftUI rendering, background/foreground behavior or process restoration. Those
remain separate from this increment's source and simulator test evidence.

## Follow-up: failure aging on re-entry

Proposed for review with the failure-aging increment.

Before beginning a new location check, the reducer sends a visible-location state
through the existing shared `stateAfterTimePasses` policy. The client adds only
that adapter operation. The checking case retains the aged value, so temporary
location fallback cannot restore an expired stale overlay. Snapshot data, failure
reason and manual retry remain shared behavior. Healthy and snapshot-absent states
keep the existing shared policy; no native expiry threshold is added.

Known blocked or unresolved location bypasses aging. Applying failure aging
unconditionally could replace a location-blocking overlay with a stale banner
while the cached snapshot remains inside its stale window. The Android entry
path already has this same visible-location boundary.

Reducer-owned epoch timestamps now use the existing TCA date dependency, whose
live value still reads the system date. Deterministic checks freeze that date at
the shared stale-window boundary and one millisecond beyond it, preserving the
last snapshot and failure reason through fallback and retry. This adds no package,
state cache, scheduler or Swift-export workaround. Platform delivery and scene/
process lifetime limits above remain unchanged.
