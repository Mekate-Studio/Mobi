# Concurrency Extras assessment — 2026-11-15

Base: `e17cba8b632c9a5d7f89b34d3b117df530cc1278`, merged PR #110.
Candidate: Concurrency Extras **1.3.2 → 1.4.3**, revision
`8a4260f7373493435bd21194585c95b72bfdd401`.

## Source review and actual use

The [complete interval](https://github.com/pointfreeco/swift-concurrency-extras/compare/1.3.2...1.4.3)
contains 20 commits. It adopts a Swift 6 manifest/profile, including
`NonisolatedNonsendingByDefault`; the release notes identify the corresponding
`Result.init(catching:)` isolation change. Small function diffs do not make these
compiler settings behavior-neutral. The other runtime edits include explicit
existential/import syntax and the Swift 6.4 `Task.never()` cancellation changes.
The [1.4.3 release](https://github.com/pointfreeco/swift-concurrency-extras/releases/tag/1.4.3)
was published October 14 and exceeds the seven-day policy; no age waiver is needed.

Mobi directly reexports ConcurrencyExtras for its native tests and uses
`withMainSerialExecutor` in five SwiftUI timer scenarios. TCA also consumes its
`LockIsolated`, `megaYield` and `cancellableValue` APIs. No external `Task.never()`
consumer was found in the checked Mobi/dependency Sources; that upstream fix is
not presented as an observed Mobi bug fix. This is a maintained-library update,
with no new Mobi feature code, native adapter or local compiler exception.

## Package and compiler cost

The package update changes only the existing exact declaration and Concurrency
Extras lock pin. The independent test prerequisite is described below.
Xcode 27.2 / Swift 6.4.2 resolves 16 remote pins with the other 15 identical;
frozen resolution succeeds. Both the old versioned manifest and the candidate's
default manifest select tools version 6.0 locally. The candidate adds six
upcoming-feature settings; the app's compiler settings remain unchanged.
Its iOS 13 package minimum stays below Mobi's unchanged iOS 26 minimum.

The complete local test dependency graph retains all 76 targets and explicit
edges. The new optional `ConcurrencyExtrasTestSupport` product is not linked.
Its `.taskLocal` trait scopes task-local values; it does not replace the
process-wide executor hook. No new dependency/product or test trait is added
to Mobi's targets. Hosted compiler results belong to the review PR; identical
Swift 6.3/6.4 implementations are not assumed from one version pin.

## Qualification and retained requirements

The source-bound baseline is PR #110. Its tested head
`6fd033751d2ac09429ed6f67f11a25649b47ade1` and this merged base have the identical
tree `b5a19ac5b8dce4d454936f9e3de858297ff66010`. That qualification passed local
native gates and [CI #719](https://github.com/Mekate-Studio/Mobi/actions/runs/43646397865).
The local Xcode 27.2 / Swift 6.4.2 / JDK 25 tuple is unchanged. This reuses the
recorded baseline; it is not a newly executed baseline run.

Before the fixture repair below, the candidate passed all 79 native test
functions locally with zero failures/skips.
All five unchanged timer scenarios pass five configured iterations: 25 observed
executions, retaining their one-minute limits and assertions, without retry-on-
failure or scheduler-count overrides. These are not independent cold launches
or long-run reliability evidence. Generated-case, actor and one-runtime controls
pass. The successful Debug warning snapshot remains 29 file/line emissions at
27 distinct locations after normalizing checkout/generated temporary paths;
the existing warning backlog stays open. Release and final staged/hosted results
are recorded in the review PR.

The [first hosted attempt](https://github.com/Mekate-Studio/Mobi/actions/runs/43693564346)
passed 78 functions; `shouldStopConsumingLocationOnCancellation()` exceeded its
unchanged one-minute limit. Its mapped-element signal did not establish a
pending read: the production guard could correctly return `nil` while the test
retained the stream and waited for an unpromised termination callback. This is
not attributed to Concurrency Extras or the separate historical timer flake.

[PR #112](https://github.com/Mekate-Studio/Mobi/pull/112), commit
`2bdcdfce12a2b300879a7382ab0f5fe19c98907c`, repairs coordination and separately
tests a value delivered after cancellation. On the unchanged 1.3.2 pin, forcing
the old map-to-guard window while retaining the stream reproduces the timeout;
the repaired cases pass 20 configured executions, and two deliberate assertion
controls fail. Its normal staged gate passes all 80 native functions. This is a
controlled schedule, not a naturally reproduced unchanged baseline run.
Production code, dependencies and time limits are unchanged in that prerequisite.
The package branch carries the exact repair commit for requalification; review
and merge #112 first. On 1.4.3, the repaired cases also pass 20 configured
executions, and all five unchanged timer cases pass another 25 executions.
Final staged and hosted results for the combined candidate are recorded in #111,
retaining the failed first attempt.

**IOS-13: retained.** The actual `MainSerialExecutor.swift` bytes are unchanged.
The serialized suite and whole-scenario executor scopes remain; task-local test
support is not a supported replacement. No parallel or scope-removal probe is
claimed. Reassess a supported per-test executor replacement with the existing
cold/parallel and negative controls before deleting this requirement.

**MOB-08: retained.** No supported replacement for the pre-start StoreTask owners
was identified. Existing startup, cancellation/recovery and late-result checks
qualify retained behavior; no new cancellation-ID removal control is claimed.
All nine active interop requirements remain, and the historical timer flake is
not attributed or closed. Future relevant updates still request review through
the existing watch and recorded removal conditions.

The authenticated owner advisory feed returned no published records. This is a
bounded provider observation, not full dependency-security clearance or risk
acceptance. Signed delivery, device/exact-floor execution and performance remain
separate. Rollback restores the two package files; no application migration is
required.
