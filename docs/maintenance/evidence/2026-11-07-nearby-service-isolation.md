# Nearby checked service isolation — WARN-01 / IOS-02

Base: main `fa8257887fb5091a3290fe46cd3878fb153f9851`, after Home's
[PR #91](https://github.com/Mekate-Studio/Mobi/pull/91).
This follows [ADR 0019](../../adr/0019-ios-home-checked-service-isolation.md);
it qualifies service captures, not retained raw-state sendability.

## App change and review cost

Nearby's eight existing client closures and service initializer are MainActor
bound. Its client has checked `Sendable` conformance and normal `MobiCore` /
`MobiNearby` imports. The reducer replaces `@Reducer` with explicit
`@MainActor Reducer` conformance, using the same supported Swift contract as Home.
The reducer implementation, shared state, location/timer policy, cancellation and
error handling remain. No wrapper, registry, new state or Kotlin source is added.

The producer adds **MobiNearby** to the caller-isolated async profile, making four
modules: KotlinCoroutineSupport, MobiCore, MobiHome and MobiNearby. All Swift
consumers rebuild together; there is still one Kotlin runtime. This changes the
Swift wrapper's execution/ABI and is an explicit review decision, following
[SE-0461](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md)
and [SE-0470](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0470-isolated-conformances.md).

The [official Kotlin guide](https://kotlinlang.org/docs/native-swift-export.html#coroutine-dispatchers)
still selects Dispatchers.Default. The selected exporter starts the coroutine
UNDISPATCHED, so the prefix before suspension now runs on MainActor for native
Nearby. The current service validates location/builds its request, then the
simulated repository suspends with `delay(150 ms)` before updating its sequence.
Future blocking work before suspension requires execution-policy review; this
change does not force Kotlin Main or make async work automatically nonblocking.

## Actual source and required qualification

The generated Nearby Swift source has SHA-256
`53eb3ba9801d80070f264c767aaa95dc3e6342e95d41fe029a9fa14a36027cdb`.
On local Xcode 27.1 / Swift 6.4, compiling that unchanged source with the merged
three-module profile rejects actor-owned refresh: both `state` and `self.service`
risk a data race when sent to its concurrent async method. Adding the fourth
module's caller-isolation setting makes the same Swift 6 SIL contract pass.
Generated source is not patched. This micro-check is supporting evidence; actual
app/test builds and their compiler contracts are the adoption check.

The merged baseline's raw local compiler log has eight Nearby service-capture
diagnostics at eight sites. The actual local candidate passes all 77 native tests
with zero failures/skips and zero Nearby/Home service-capture diagnostics. Require
the same result at the final head; staged and hosted results are recorded in the review PR.
The full native suite must preserve precise/blocked/degraded location, snapshot
identity, expiry/retry, supersession, late results, tab/scene/timer lifetime and
Kotlin/Swift cancellation and error meanings with existing limits/assertions.

The normal `check_swift_export.rb` gate now requires generated actor-owned Nearby
refresh and all eight actor-bound client operations to compile. Actual-app SIL
controls reject off-actor initial/loading/refresh-query and reducer calls. Reports
record the exact four-module profile and `raw_state_sendability: unchecked_retained`.
Ordinary service/state captures remain separately checked without app exceptions.

## Remaining constraint and update workflow

`NearbyVehicleMapFeatureState` keeps its existing unchecked Sendable extension.
The state file's preconcurrency imports and renderer actor assertion remain.
This PR does not qualify safe raw-state transfer, equality or every retained alias.
IOS-02 stays open; IOS-08 Swift 5 support and IOS-17 Job inheritance stay open too.
Android calls Kotlin directly, so this is platform-specific under MOB-07.

On Kotlin/Toolchain/Swift/Xcode updates, inspect actual generated async annotations
and language defaults. Retire redundant producer flags only after equivalent
semantics pass the complete graph, required Home/Nearby actor contracts and native
behavior checks on both supported compilers. Retire raw-state exceptions through
their separate ownership/equality/lifetime qualification. The release watch points
to these checks and never turns an available probe into retirement authorization.
