# IOS-14 Nearby Swift repository success — 2026-11-08

Base: main `28aa47a220ac4314f7e834f6cc9ee92750481438`, after
[PR #93](https://github.com/Mekate-Studio/Mobi/pull/93).
This follows the [Home repository qualification](2026-11-06-ios14-home-repositories.md)
and [Nearby raw-state ownership](2026-11-07-nearby-raw-state-isolation.md).

## Scope and code cost

One native test file adds a stateless Swift `KotlinBase, NearbyFleetRepository`
double and one MainActor test. The double implements the protocol already emitted
by the selected exporter. Its async method constructs a fresh FleetSnapshot from
the received request, with an identifiable sequence and vehicle ID. It stores no
Kotlin references, mutable request recorder, callback or fixture result.

The test first calls the actual Kotlin service and requires its loaded result,
before the native client's generic failure fallback can interpret anything.
It checks request coordinates and time via the returned snapshot. A second call
uses the same service through the maintained native client and maps its result
with the actual native State. It checks semantic snapshot equality, camera/rider
coordinates, vehicle ID/position, overlay and retry/interaction admission. Snapshot
sequence and vehicle IDs are payload identity checks, not Swift wrapper-object
identity or proof that arbitrary Kotlin aliases may cross actors safely.

This follows the official
[reverse-import pattern](https://kotlinlang.org/docs/native-swift-export.html#cross-language-inheritance)
using the actual generated protocol and runtime base, as Home already does.
The method does not promise MainActor execution for arbitrary reverse callbacks;
its result is built from that operation's request without retaining shared Swift
state. The test and native client retain their checked MainActor ownership.

This is new success-path coverage, not fixture retirement or an application
repository replacement. Production code, shared policy, generated source, compiler
flags, dependency versions and the reviewed module graph are unchanged. The
existing Kotlin-origin error/cancellation controls and runner registration remain.
No preconcurrency import, unchecked Sendable conformance or extra Swift module is
introduced. Android behavior is unchanged.

## Required qualification and update workflow

Run the normal staged quality/native gates and hosted CI. Require the full native
suite, including the new test, to preserve all existing assertions and limits.
The generated graph must remain eight Swift modules in Debug, one Kotlin runtime,
with existing constructor, switch-exhaustiveness and actor-ownership controls.
Inspect both supported compiler logs for new ownership warnings as well as passing
runtime tests. Final counts and compiler results are recorded on the review PR.

IOS-14 stays open for ordinary Nearby Swift errors and typed domain exception
identity. Home's typed exception export-surface expansion remains unqualified;
this success test does not make that decision. Kotlin-origin cancellation and
uncaught errors independently qualify the forward bridge and must remain.

On Kotlin/Toolchain/Swift/Xcode updates, recheck the emitted repository witness,
async callback recipe and supported inheritance pattern against the official
Swift-export docs and selected sources. Requalify the actual service/client round
trip before simplifying the test double or removing a compensating fixture.
No new workaround is introduced by this test. IOS-02's caller-isolated profile,
IOS-08 strict support, and IOS-17 Job inheritance keep their own retirement checks.
