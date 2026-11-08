# Nearby retained-state exception removal — IOS-02

Base: main `e5c3dce736c4309d6a267a6c78372c351721abed`, after
[PR #92](https://github.com/Mekate-Studio/Mobi/pull/92).
This follows [Nearby service isolation](2026-11-07-nearby-service-isolation.md)
and [ADR 0019](../../adr/0019-ios-home-checked-service-isolation.md).

## App change and review cost

Remove NearbyVehicleMapFeatureState's global unchecked Sendable conformance and
use ordinary MobiCore/MobiNearby imports in the State file. The snapshot refresh
Effect.run closure explicitly runs on MainActor, matching its client and Store.
The pinned TCA 1.26.0 API accepts a Sendable async operation; it does not declare
that operation MainActor-isolated. Removing the unchecked declaration alone fails
at the retained loadingState capture. Explicit isolation fixes that actual call.

These are the only three production files changed. No state wrapper, State/Action
rewrite, Kotlin change, new compiler flag or producer profile change is required.
Kotlin reference identity, shared equality and the existing native presentation
remain. Actor ownership is an application safety contract, not a workaround to
remove merely because export integration improves.

State itself is non-Sendable, not globally MainActor-annotated. The checked contract
is that state owned by the actual Store/client cannot escape MainActor through the
qualified calls. Fresh disconnected values can still be transferred safely; this
does not establish thread safety for arbitrary Kotlin aliases or Swift 5 internals.

## Test changes and compiler evidence

Swift Testing requires Sendable parameter inputs. Four existing test matrices now
pass eight native fixture identifiers and construct the existing state inside
their MainActor test bodies. All 16 combinations and assertions remain. This is a
test-only naming enum, not another product state representation or wire protocol.

The existing scene continuation helper no longer requires its result type to be
Sendable. It stores only a checked Sendable continuation under a Mutex, consumes
it once, and accepts a `sending` result. Tests pass fresh fixture results without
retaining aliases across transfer. This follows
[SE-0430](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0430-transferring-parameters-and-results.md),
the same contract used by CheckedContinuation.resume(returning:). All Nearby native
test files now use normal imports; no unchecked test conformance is added.
Cancellation counters, late-result controls, completion cleanup and limits remain.

Two existing test transports also need checked ownership. The late-result test
resumes its continuation with a fresh fixture result and retains only the native
expected map content for its later assertion. The location revalidation test
records requests in an actor-local array and inspects them after the refresh effect
finishes; it no longer sends Store-owned state through AsyncStream. It preserves
the request/location assertions and also requires exactly one request. These
changes remove the two data-race diagnostics exposed by the hosted compiler when
the global state conformance is removed. Require no Nearby native-test data-race
diagnostics in the final compiler logs, with the same suite and limits.

The normal iOS gate emits Swift 6 SIL against the actual compiled app and generated
modules, with warnings as errors. It requires actor-owned Store state reads and
all eight client operations to compile. Negative controls must reject:

- an awaited initialState result returned to a nonisolated caller;
- an awaited Store.state returned to a nonisolated caller;
- raw state stored inside a Sendable container;
- existing synchronous off-actor service and reducer access.

Failures must contain the expected state-specific diagnostics, not just fail for
an unrelated import or type error. The report records
`raw_state_sendability: non_sendable_actor_owned`. Generated-module-only capture
controls remain separate from the app's ownership contracts.

The initial local qualification passes all 77 native test functions with zero
failures/skips on Xcode 27.1 / Swift 6.4. The unchanged suite covers shared equality,
precise/blocked/degraded location, snapshot identity, expiry/retry, supersession,
late results, tab/scene/timer lifetime and cancellation/error meanings. Final staged
gates and hosted compiler/test evidence are recorded in the review PR.

## Remaining workaround and update workflow

IOS-02 now tracks the explicit caller-isolated async profile for MobiHome,
MobiNearby, MobiCore and KotlinCoroutineSupport. Retire redundant settings only
when actual upstream output or language defaults supply equivalent semantics;
rebuild the complete graph and preserve these positive/negative contracts and
behavior checks on supported local/hosted compilers. Upstream availability is a
review trigger, not automatic removal authorization.

IOS-08's generated Swift 5 support and IOS-17's coroutine Job inheritance remain
separate. The MapLibre delegate MainActor assertion is a separate SDK callback
contract. No warning suppression, extra opt-in or global Sendable promise replaces
the removed declaration. Android already calls Kotlin directly; this boundary
change is iOS-specific under MOB-07.
