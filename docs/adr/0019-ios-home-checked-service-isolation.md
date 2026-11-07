# ADR 0019: Checked iOS Home service isolation

Status: Accepted in [PR #91](https://github.com/Mekate-Studio/Mobi/pull/91), 2026-11-07. Extends ADR 0009 and IOS-02.

## Decision and code cost

Home's existing client closures and service initializer are `@MainActor`.
The client remains a Sendable value holding Sendable closures; its normal
`MobiHome` import replaces `@preconcurrency`. Home's reducer has an explicit
`@MainActor Reducer` conformance. This replaces the `@Reducer` macro's ordinary
nonisolated conformance; keeping both produces a redundant-conformance error.
No wrapper, actor class, request registry or new state is introduced.

The producer enables `NonisolatedNonsendingByDefault` for **MobiHome, MobiCore and
KotlinCoroutineSupport**. This is a shared compiler-profile decision, despite
Home being the first native consumer migrated. All generated Swift consumers
are rebuilt together. Kotlin declarations, compiler version, one-runtime layout
and AppServices' native/Shared Compose service identity stay unchanged.

## Execution trade-off and supported contracts

[SE-0461](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md)
implements caller-isolated async semantics in Swift 6.2. The flag changes execution
and Swift ABI, not diagnostic severity: Home's Swift wrapper stays on its caller's
actor across suspension. The [official Kotlin guide](https://kotlinlang.org/docs/native-swift-export.html#coroutine-dispatchers)
still places exported Kotlin work on `Dispatchers.Default`; Swift actor isolation
does not move that work onto Kotlin Main. A profile change requires a complete
Swift graph rebuild, including reverse repository callbacks.

The selected exporter starts that coroutine `UNDISPATCHED`: code before its
first suspension runs on the calling thread, now MainActor for native Home.
The current fake repository starts with `delay(150 ms)` before its calculation.
A future repository doing blocking work before suspension would block the UI;
caller isolation is not a background-work guarantee. This is an execution-policy
review point, not a reason to alter the shared repository in this increment.

[SE-0470](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0470-isolated-conformances.md)
supports the actor-isolated conformance. The pinned [TCA Reducer protocol](https://github.com/pointfreeco/swift-composable-architecture/blob/e2fa1df6cd9eec6fa6314aa20513e47da576f24e/Sources/ComposableArchitecture/Reducer.swift)
is nonisolated. Explicitly isolating Home's conformance lets its synchronous
reduction call the client safely. Reducer construction/body use now requires
MainActor, matching AppServices and the actual Store owners. At Home adoption,
other reducers retained their contracts; the later Nearby follow-up is linked below.
This Swift-only change has no Android behavior delta.

## Actual graph qualification

Base: main `2293754bd789afd29ba8315e3aa69cb275bcff29`, Kotlin 2.5.0-Beta2,
coroutines 1.11.0, Xcode 27.1 / Swift 6.4, iPhone Air simulator iOS 26.5.
Generated sources were not edited.

| Profile | Result |
| --- | --- |
| Unchanged producer + actor-owned Home service | Rejected: async service transfer risks a data race |
| Caller isolation in Home only | Generated Home rejected at `withKotlinContinuation` |
| Home + coroutine support | Actor micro-check passes; actual app rejects reverse repository calls in MobiCore, including Nearby's repository |
| Home + Core + coroutine support, explicit client/reducer isolation | Actual app and 77 native tests pass; one Kotlin runtime and all six exhaustive/omission controls pass |

Local raw compiler logs contain three Home service-capture diagnostics at the
base and zero in the candidate. Nearby's warnings remain. Actual-app Swift 6 SIL
checks accept actor-bound synchronous calls and off-actor awaited refresh; they
reject off-actor initial/loading calls and reducer-body access. The normal gate
now requires these contracts and reports the three-module profile in
`build/logs/swift-export-checks/report.json`. The Swift cancellation test starts
its request with `Task.detached`, then cancels and requires exact prior-state recovery.
Final staged and hosted qualification is reported on the implementation PR.

## Remaining scope and simplification

The later [Nearby service qualification](../maintenance/evidence/2026-11-07-nearby-service-isolation.md) extends the profile and service actor contract. IOS-02 remains open for retained Nearby state. Generated service/state objects are still
non-Sendable; raw Sendable-capture controls continue to reject them. IOS-08's
Swift 5 support exception and IOS-17's Kotlin Job inheritance warning remain.
Support-profile changes also affect generated Flow/reverse-async surfaces;
Mobi's app checks do not qualify general Flow usage outside this app.

On Kotlin/Toolchain/Swift/Xcode updates, inspect generated async annotations and
language defaults. Remove explicit flags only when equivalent supported semantics
pass the actual module graph, required Home actor contracts, native cancellation,
failure/retry/ordering/lifetime and native/Shared Compose composition tests on all
supported compilers. Keep the actor ownership contract; remove redundant producer
configuration when upstream integration supplies it. The release watch requests
reassessment; passing a compiler micro-check never authorizes retirement.
