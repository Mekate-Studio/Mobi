# iOS interop changes and retirement

This inventory separates application improvements from temporary integration
mechanisms. The [registry](../../maintenance-interop-workarounds.json) names each
workaround, its affected code, replacement, recheck triggers and removal checks.
It includes the maintained direct app and unmerged work from PRs #37/#38;
listing a candidate mechanism does not adopt it. The actual app integration and
its selected defaults are described in [ADR 0009](../adr/0009-generated-swift-export-for-native-features.md).

## Workarounds first

| ID | Mechanism | Retirement or simplification target |
| --- | --- | --- |
| IOS-01 | Former Kotlin visitors and Swift projections, removed by the app integration | Generated exhaustive state handling in real consumers; delete both handwritten layers |
| IOS-02 | Unchecked raw-state sendability and preconcurrency service captures | Checked actor ownership/native values; remove unsupported crossing assertions |
| IOS-03 | Pilot numeric tags, wire facades and decoders | Delete the duplicate protocol as actual feature slices replace it; no upstream release is needed to reject this design |
| IOS-04 | Home/Nearby request-owner facades | Qualified direct async or a smaller operation owner; remove redundant request registries and facade API |
| IOS-05 | Nearby state IDs, owner UUIDs and adopt/release calls | Qualify retained actor-owned state; delete the state dictionary and manual ownership protocol |
| IOS-06 | Custom polling/completion/listener and drain transport | Qualified async ownership; remove redundant transport while preserving unfinished-work accounting |
| IOS-07 | Closed generated API, whole-feature module placement and experimental import checker | Supported narrow module/import enforcement; remove unnecessary placement and flag coupling |
| IOS-08 | Swift 5 coroutine-support module | Strict Swift 6 after the actual generated support graph passes without suppression or fallback |
| IOS-09 | TCA client `assumeIsolated` assertions and cancellation relay | Compiler-expressed isolation and simpler feature effects; this is also a TCA/design constraint |
| IOS-10 | Custom exporter, bridge producer and module/profile plumbing | Supported Toolchain/build integration; keep validation, remove replaced custom production machinery |
| IOS-11 | Explicit macro-validation invocation override | Reliable validation in the scoped environment; keep exact approvals and negative refusal control |
| IOS-12 | Private JVM temp handling for affected tool inputs | Exact-graph dependency remediation/risk review; temp handling does not fix unrelated vulnerabilities |
| IOS-13 | Serialized Home/Nearby test suite | Parallel execution after TCA provides per-test executor isolation; preserve overlapping-request regression checks |
| IOS-14 | Kotlin-owned live-client repository fixtures | Recheck native error round-trips; preserve typed Kotlin failure meaning and cancellation coverage |
| IOS-15 | Test-only Kotlin constructors for internal generated nested aliases | Public generated case constructors; delete the helper constructors without mangled aliases |

“Facade” is a pattern name, not a defect category. The request/wire facades above
compensate for integration limitations or candidate representation choices.
An ordinary feature client or composition root can remain useful after those
workarounds disappear. Native presentation types, `@MainActor` isolation,
compiler checking, package locks and macro approvals are not removal targets
merely because a temporary bridge uses them.

The normal iOS test job checks the actual generated modules. It verifies complete
switches and omitted-case rejection, then reports strict generated-support and
nested-constructor availability. IOS-02 also checks the real native Home value,
generated service/raw-state Sendable captures and a Home actor-owned async call.
These partial isolation checks emit SIL so ownership diagnostics run; type checking
alone can miss an unsafe async transfer. An actor annotation by itself does not
qualify the generated async boundary. Passing results only identify a retirement
candidate: actual reducer transitions, shared Home/Compose service ownership,
equality, cancellation and cross-runtime lifetime still need qualification before
removing an exception. Reports are in `build/logs/swift-export-checks/` and uploaded from PR jobs even
when the checks pass.
The release watch marks these checks `available_in_ci`; it does not pretend to
have run them or turn a passing probe into retirement authorization.

## Changes with a different purpose

| Change | Classification | What must survive simplification |
| --- | --- | --- |
| Reject an old refresh after a newer location decision | Correctness improvement | A delayed result cannot undo blocked/current location state |
| Handle cancellation without leaving loading stuck | Correctness improvement | Deliberate restoration and explicit cancellation timing |
| Show repository failure, retry and integration failure distinctly | Presentation/correctness improvement | No swallowed error or silently substituted domain state |
| Replace unchecked crossings with checked isolation | Safety improvement | Compiler/runtime evidence for the actual boundary |
| One composition, same Home service, native map, Shared UI | Preserved requirements | Do not count existing architecture as a new benefit |
| Parent admission limits, per-owner limits, shutdown budgets | Experimental policy | Separately justify limits; no fixture number becomes a product requirement |
| Mutex serialization versus Main confinement | Concurrency policy | Choose from repository behavior; Main isolation does not serialize suspension |
| Evidence receipts, probes, duplicated pilot/candidate files | Assessment infrastructure | Useful evidence is not an adopted app improvement or a permanent second app |

The maintainer tolerates the interim guarded implementation while requiring a
readability improvement. This is not blanket approval of production adoption,
bridge diagnostics, dependency risk or experimental policies.

Android applicability and executable follow-ups for ordinary application
improvements are tracked in [cross-platform mobile feature follow-ups](mobile-feature-follow-ups.md).
Those items stay separate from IOS-prefixed bridge workarounds; fixing one native
consumer does not qualify the other consumer's lifecycle or effects.

## Readable Swift is an acceptance condition

`guard`, `try` and `do/catch` are normal Swift tools; their number is not evidence
of safety or modern design. The current reducer spreads transport failures,
state-handle checks and cleanup across feature branches. That is a cost to remove.

The real-app readability slice should:

- Keep valid synchronous domain/presentation transitions nonthrowing where their
  inputs and ownership make failure impossible. Do not invent a fallible handle
  protocol and then make every feature branch catch its failures.
- Validate external inputs at the boundary. Translate actual bridge failures to
  a small native error model once, and handle them at a deliberate effect/UI edge.
- Keep cancellation distinct from domain failure; use scoped `defer` cleanup
  where appropriate. Preserve real failures instead of `try?`, generic success
  fallbacks, forced casts or silent error substitution.
- Prefer compiler-expressed actor contracts and typed outcomes. Typed throws
  may help where the whole seam supports it; neither typed throws nor `Result`
  alone reduces the number of responsibilities.
- Show before/after code in the actual reducer/client. Count supporting owners,
  registries and callbacks too; moving clutter into a helper is not completion.

Swift's [error-handling language rules](https://docs.swift.org/latest/documentation/the-swift-programming-language/statements/)
and [actor-isolation migration guidance](https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/commonproblems/)
are language references, not qualification of the Kotlin bridge.

## Required upstream source review

The primary sources for Swift-export evolution are JetBrains' official
[Swift-export implementation/design docs](https://github.com/JetBrains/kotlin/tree/master/docs/swift-export)
and the [published user guide](https://kotlinlang.org/docs/native-swift-export.html).
Review both for every Swift-export dependency/tool update and before proposing
workaround removal. Check the docs at the selected release/tag as well as current
upstream changes; `master` is a discovery source, not the selected release's contract.
Record disagreements rather than assuming either document is current in every detail.

Use the [official sample](https://github.com/Kotlin/swift-export-sample) to inspect
actual build configuration and consumer code. Its version catalog and build files
must be read alongside the README. Treat example code as implementation guidance;
its error/cancellation/isolation handling still needs evaluation in Mobi's real
feature. Keep the retired iOS Gradle bridge retired: a Gradle example is not
qualification of Mobi's Toolchain path.

Use [KT-64572](https://youtrack.jetbrains.com/issue/KT-64572) as the first-release
milestone and navigation point. Follow relevant linked work, including
[KT-80305](https://youtrack.jetbrains.com/issue/KT-80305) for coroutine support,
and inspect specific issues for each encountered failure. Record state, affected
versions, available/fixed version, reproduction and applicability. A fixed parent
milestone cannot close all bugs in that feature. If no matching issue is verified,
record that gap; do not label a broad milestone as the exact bug. Prepare a minimal
reproducer and proposed report for review before publishing upstream.

| Workaround IDs | Upstream review focus | Required Mobi check |
| --- | --- | --- |
| IOS-01, IOS-03 | Sealed-state mapping, generated cases and real sample consumers | Actual feature uses exhaustive generated handling without handwritten tags/visitors |
| IOS-02, IOS-05, IOS-09 | Generated reference ownership, Swift concurrency, selected Swift/TCA contracts | Real reducer/map/equality/lifetime and off-actor rejection; handle/relay machinery justified separately |
| IOS-04, IOS-06, IOS-08 | Coroutine docs and KT-80305; follow cancellation/exception issues, not just the parent status | Real success/error/cancellation/late completion, strict support compilation and unfinished-work ownership |
| IOS-07, IOS-10 | Architecture, standalone execution, compiler bridges, module export and sample build configuration | Narrow generated API, one Kotlin image, correct module graph and supported cold Toolchain delivery |
| IOS-11, IOS-12 | Relevant Xcode/macro documentation and exact dependency/advisory evidence | These environment/risk controls cannot be retired from Swift-export milestones alone |
| IOS-14, IOS-15 | Reverse async exception identity and public generated nested constructors | Real repository-failure round-trip and native tests after deleting compensating fixtures |

IOS-13 is a native test-harness constraint, not a Swift-export limitation. The
pinned [TCA TestStore](https://github.com/pointfreeco/swift-composable-architecture/blob/e2fa1df6cd9eec6fa6314aa20513e47da576f24e/Sources/ComposableArchitecture/TestStore.swift#L471-L477)
uses a process-wide executor hook, installed at initialization and restored at
deinitialization. A shared serialized parent prevents Home and Nearby store
lifetimes from overlapping. The ordering test still runs two requests together
and completes the newer request first; serializing test functions does not
remove concurrency from the behavior being checked. Reassess the parent suite
on TCA/Swift/Xcode updates, and remove it only after the registry's cold, parallel
and negative-control checks pass. Native dependency release discovery remains an
explicit coverage gap in the current watch.

The implementation docs' symbol-stability guide is also relevant when an update
changes generated symbol expectations: inspect whether the difference is intended
before updating expected output. A refreshed golden file is not a behavior check.

### Source review recorded 2026-10-18

- Reviewed all six implementation/design documents at
  [Kotlin `5827df9172f0`](https://github.com/JetBrains/kotlin/tree/5827df9172f0a7cee5eda8dac6439a35100a6ac7/docs/swift-export).
  The README warns of documentation lag and unstable standalone APIs. Its
  [language mapping](https://github.com/JetBrains/kotlin/blob/5827df9172f0a7cee5eda8dac6439a35100a6ac7/docs/swift-export/language-mapping.md)
  still excludes suspend functions, whereas the published guide documents async
  and Flow support. That mismatch is a source-freshness finding, not evidence to
  preserve an async facade. Selected-release compilation/runtime checks remain open.
- Inspected sample configuration, version catalog and Swift consumer at
  [sample `d21f61f4d05a`](https://github.com/Kotlin/swift-export-sample/tree/d21f61f4d05ab7cb57d62d7e008ec3e6f1a69e48).
  It selects Kotlin 2.4.10 and coroutines 1.11.0, configures multi-module export
  through Gradle, and calls async/Flow APIs. Its consumer includes forced error
  handling and a catch that does not distinguish cancellation from other failures;
  those choices do not qualify Mobi's error policy. No sample build was run.
- Read the public YouTrack issue API because the issue pages require JavaScript.
  KT-64572 is marked Fixed with availability in 2.2.20-Beta2 and links KT-80305.
  KT-80305 is also marked Fixed and links specific cancellation
  [KT-80970](https://youtrack.jetbrains.com/issue/KT-80970) and exception
  [KT-80971](https://youtrack.jetbrains.com/issue/KT-80971) work. Those links are
  investigation leads; this review has not verified an exact matching issue/fix
  for Mobi's SwiftJob inheritance or KotlinError sendability findings.

For every subsequent review, record the review date, source URLs and immutable
commits/content digests, selected Kotlin/Toolchain/coroutines/Swift/Xcode versions,
changes since the previous review, affected registry IDs, issue applicability,
and the executable Mobi result. If a source is unavailable or inconsistent, keep
that evidence gap visible and leave retirement unverified. Publish the conclusion
beside the affected code in the small update/removal PR.

Documentation, sample and issue changes are currently **manual review inputs**.
The release watch does not poll these repositories or YouTrack, or automatically
complete this review. Changing a source or seeing a fixed issue requests a
recheck; only the registry's actual removal checks can qualify simplification.

## Observable retirement in the update workflow

Run `./scripts/dev/dependency_updates.sh assess-interop-workarounds` for a local
inventory report without release discovery or retirement probes. The existing
`watch-compatibility` command also writes `workarounds.json`, includes the entries
in its digest-bound snapshot and adds a retirement table to its step summary.
No new schedule, dependency adoption or removal automation is introduced.

An eligible release observed by an existing provider marks matching entries
`release_review_due`. A meaningful change emits the existing watch notification;
an unchanged known gap stays quiet but remains in every report. This is a
reassessment request, never a claim that the release fixes the limitation.

The release watch does not execute retirement probes. Entries either say
`probe_state: not_automated` or point to compile checks as `available_in_ci`;
watch results still say `retirement_state: unverified`. Missing provider
coverage, including Swift/Xcode, coroutines and native dependency/risk triggers,
is explicit. Absent pilot/candidate source means `not_in_checkout`, not retired.
The existing watch is bounded release discovery and is not an advisory review.

For each tool/dependency/design update:

1. Complete the required upstream source review above. Read the registry and
   changed watch observations, including uncovered local tool-tuple changes.
   Record affected IDs and source-review evidence in the actual update PR.
2. Recheck the named replacement on the selected source/tool graph. Add the
   executable removal/regression check to the maintained repo gate in that same
   focused PR; a release note or toy probe is not sufficient.
3. Record still needed, simplified or removed with exact evidence, failures and
   remaining gaps. A failed or unrun replacement check keeps the workaround open.
4. When the replacement qualifies, remove the workaround and its redundant tests,
   settings and documentation in an actual app/build slice. Preserve behavior,
   source-bound recovery and explicit adoption/risk decisions where applicable.

## Small PR sequence against maintained code

1. **This PR:** classify the mechanisms and expose retirement work in the current
   update/watch path. No application behavior changes or interop copies.
2. **Nearby correctness/readability:** fix one demonstrated stale-response or
   swallowed-failure case in the existing reducer/client with its regression
   test. Keep product policy and export migration out of that diff.
3. **State boundary:** replace one real feature's visitor consumption, including
   the smallest supported state ownership. Retire applicable IDs in that slice;
   do not add a parallel application tree as the review target.
4. **Async boundary:** qualify and simplify actual refresh ownership, keeping
   cancellation and noncooperative-work checks. Retire applicable facade/listener
   code with the same change.
5. **Build integration/strict modes:** replace one custom producer/profile
   workaround as the supported capability becomes demonstrable. Shared UI and
   one-delivery qualification remain requirements when affected.

Each PR explains its concrete before/after behavior and cost, and includes
short author comments on changed lines for non-obvious choices. Every workaround
comment cites its registry ID and removal condition. Experiments may gather
facts privately; review and adoption happen through changes to maintained code.
