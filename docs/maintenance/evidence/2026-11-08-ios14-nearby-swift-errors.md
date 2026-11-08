# IOS-14 Nearby ordinary Swift errors — 2026-11-08

Base: main `f6d9493e8e0b293c53fc3b163ca7698ea9c5f026`, after
[PR #95](https://github.com/Mekate-Studio/Mobi/pull/95).
This extends [Nearby Swift success](2026-11-08-ios14-nearby-success.md) using the
same reverse-import seam as the [Home repository tests](2026-11-06-ios14-home-repositories.md).

## Scope and ownership

The existing Swift repository double gains one immutable optional native error
and a one-case Swift Error type. Its success path still constructs a fresh
FleetSnapshot from the request; no Kotlin request, snapshot or result is stored
in Swift fields. There is no mutable fail-once flag, request recorder, actor
wrapper, preconcurrency import or unchecked Sendable conformance.

A parameterized MainActor test supplies only a native Bool to Swift Testing and
constructs the existing ready/loaded fixtures inside the test actor. It calls
the real Kotlin service first and requires typed Unexpected state. A bridge error
that escapes the service fails the throwing test before the client's generic
fallback can map it to the same native failure reason. Expected failed states
use the existing public generated cases, not a new export helper.

The same service is then called through the native client. Both snapshot-absent
and cached cases preserve rider location and map content. The cached snapshot
is inside the existing stale window: its native overlay is stale and its map
remains interactive. Without a snapshot, the Unexpected blocking message is
shown. Both permit manual retry. This tests retry admission, not a Swift fail-once
recovery policy; the existing Kotlin-origin retry/cancellation controls remain.

This adds test coverage and native fixture configuration. Production code,
shared error policy, Kotlin fixtures, dependencies, generated source, compiler
settings and the reviewed export surface are unchanged. No fixture is retired.
Typed domain exceptions remain a separate public export/identity qualification.

## Required qualification and update workflow

Run the normal staged quality/platform gates and hosted CI, preserving existing
assertions and time limits. Require both new failure cases, the success round trip,
all native error/cancellation/lifetime tests and the actual-app compiler ownership
controls to pass. The Debug graph remains eight Swift modules and one Kotlin
runtime. Inspect supported local/hosted compiler logs for new ownership findings;
final head, test counts and actual results are recorded in the review PR.

On Kotlin/Toolchain/coroutines/Swift/Xcode updates, inspect actual reverse async
error conversion and requalify the direct service result before native fallback.
The selected behavior is measured through the real app's service/client boundary;
it is not a universal promise about every Swift error or concurrency context.
Retain Kotlin-origin uncaught-error and cancellation controls, whose forward
bridge purpose differs from these ordinary Swift repository errors. IOS-14 stays
open for typed domain errors; IOS-02, IOS-08 and IOS-17 keep separate retirement
checks. An upstream release note alone does not qualify fixture retirement.
