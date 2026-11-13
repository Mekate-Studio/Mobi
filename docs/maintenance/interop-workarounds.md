# iOS interop changes and retirement

This inventory separates application improvements from temporary integration
mechanisms. The [registry](../../maintenance-interop-workarounds.json) names each
workaround, its affected code, replacement, recheck triggers and removal checks.
It includes the maintained direct app and unmerged work from PRs #37/#38;
listing a candidate mechanism does not adopt it. The actual app integration and
its selected defaults are described in [ADR 0009](../adr/0009-generated-swift-export-for-native-features.md).

## Recorded status after PR #97 — 2026-11-09

The registry records **9 active requirements, 2 qualified removals and 6 historical
experiments**. These are reviewed dispositions, supported by the linked PRs,
not results of a fresh toolchain or upstream-source qualification. An active
entry can contain a completed simplification while its remaining mechanism
still needs requalification. Counts describe registry items, not equal amounts
of code or maintenance cost.

`disposition`, `disposition_note` and `disposition_evidence` are maintained in
`maintenance-interop-workarounds.json` and carried into `workarounds.json`,
digest-bound watch snapshots and the dependency-update summary. `scope` retains
its original app/pilot/candidate meaning. Source presence, an eligible release
or an available CI check never assigns or changes a disposition.

### Active app requirements

| ID | Mechanism and recorded disposition | Evidence |
| --- | --- | --- |
| IOS-02 | Explicit caller-isolated async profile: Four-module caller-isolated async flags remain. Checked clients and retained state replaced unchecked crossings; Home test import exceptions are also removed. | [#91](https://github.com/Mekate-Studio/Mobi/pull/91), [#92](https://github.com/Mekate-Studio/Mobi/pull/92), [#93](https://github.com/Mekate-Studio/Mobi/pull/93), [#97](https://github.com/Mekate-Studio/Mobi/pull/97) |
| IOS-07 | Generated implementation-only import checking: CheckImplementationOnly remains in the maintained producer; candidate whole-feature placement was not adopted. | [#44](https://github.com/Mekate-Studio/Mobi/pull/44) |
| IOS-08 | Swift 5 coroutine-support compilation: Generated support still requires the Swift 5 exception. Strict Swift 6 support remains blocked; no suppression or fallback qualifies removal. | [#80](https://github.com/Mekate-Studio/Mobi/pull/80), [#82](https://github.com/Mekate-Studio/Mobi/pull/82) |
| IOS-10 | Custom Swift-export producer and profile plumbing: Custom generation/build integration and project preflight remain. The extra exporter runtime dependency and repository are removed. | [#44](https://github.com/Mekate-Studio/Mobi/pull/44), [#75](https://github.com/Mekate-Studio/Mobi/pull/75), [#84](https://github.com/Mekate-Studio/Mobi/pull/84) |
| IOS-12 | Private JVM temporary directories: Private JVM temporary directories remain a scoped dependency-risk control; no fresh graph/advisory clearance is claimed. | [#39](https://github.com/Mekate-Studio/Mobi/pull/39), [#44](https://github.com/Mekate-Studio/Mobi/pull/44) |
| IOS-13 | Serialized native feature tests: Serialized TestStore lifetimes and scoped virtual-clock advances remain native test-library constraints. | [#43](https://github.com/Mekate-Studio/Mobi/pull/43), [#84](https://github.com/Mekate-Studio/Mobi/pull/84) |
| IOS-14 | Typed repository-failure fixtures and Kotlin-origin bridge controls: Swift repository success and ordinary-error paths are qualified. Typed domain-failure fixtures remain; Kotlin-origin cancellation/uncaught-error controls retain a separate purpose. | [#83](https://github.com/Mekate-Studio/Mobi/pull/83), [#94](https://github.com/Mekate-Studio/Mobi/pull/94), [#96](https://github.com/Mekate-Studio/Mobi/pull/96) |
| IOS-16 | Explicit closure for native test observation: The explicit Observations closure remains for the supported hosted compiler IR-generation failure; the original test behavior is preserved. | [#82](https://github.com/Mekate-Studio/Mobi/pull/82) |
| IOS-17 | Generated SwiftJob uses unsupported Job inheritance: Generated SwiftJob still delegates unsupported Job inheritance. The diagnostic receipt and update checks remain; no new inheritance opt-in is used. | [#90](https://github.com/Mekate-Studio/Mobi/pull/90) |

### Qualified removals

| ID | Mechanism and recorded disposition | Evidence |
| --- | --- | --- |
| IOS-01 | Handwritten sealed-state visitors replaced in the app: Visitors and projection adapters were deleted from the actual Home/Nearby integration; exhaustive generated-case checks remain. | [#44](https://github.com/Mekate-Studio/Mobi/pull/44) |
| IOS-15 | Test constructors replaced by public generated nested cases: Kotlin test-only state constructors and runner registration were deleted with Beta2; public generated-constructor checks remain mandatory. | [#82](https://github.com/Mekate-Studio/Mobi/pull/82) |

### Historical experiments (not adopted)

| ID | Mechanism and recorded disposition | Evidence |
| --- | --- | --- |
| IOS-03 | Numeric wire tags and decoders: Unmerged pilot wire protocol; never adopted by the maintained app. Source absence is not a qualified removal. | [#37](https://github.com/Mekate-Studio/Mobi/pull/37) |
| IOS-04 | Request-owner facades around suspend calls: Unmerged candidate request-owner facades; the maintained app uses direct generated async clients. | [#38](https://github.com/Mekate-Studio/Mobi/pull/38), [#44](https://github.com/Mekate-Studio/Mobi/pull/44) |
| IOS-05 | Opaque Nearby state handles: Unmerged candidate state-handle dictionary and UUID ownership; the maintained app retains actor-owned generated state. | [#38](https://github.com/Mekate-Studio/Mobi/pull/38), [#93](https://github.com/Mekate-Studio/Mobi/pull/93) |
| IOS-06 | Custom completion and drain transport: Unmerged candidate completion/drain transport; its experimental accounting policy was not adopted by the maintained app. | [#38](https://github.com/Mekate-Studio/Mobi/pull/38), [#44](https://github.com/Mekate-Studio/Mobi/pull/44) |
| IOS-09 | Runtime MainActor assertions and cancellation relay: Unmerged candidate TCA runtime assertions and cancellation relay; current clients use checked actor ownership. The MapLibre delegate contract is separate. | [#38](https://github.com/Mekate-Studio/Mobi/pull/38), [#91](https://github.com/Mekate-Studio/Mobi/pull/91), [#92](https://github.com/Mekate-Studio/Mobi/pull/92) |
| IOS-11 | Explicit macro-validation invocation override: Unmerged candidate invocation override; maintained package locks, macro approvals and refusal checks remain ordinary build controls. | [#38](https://github.com/Mekate-Studio/Mobi/pull/38) |

Removed mechanisms keep their replacement targets, release triggers and
executable regression checks in the registry. Partial removals remain visible
under the active item: IOS-02 retains its async profile, IOS-10 retains build
integration, and IOS-14 retains typed domain-failure fixtures. The historical
entries describe unmerged PRs #37/#38; their absent source is not a qualified
removal and does not imply that an equivalent mechanism exists in the app.

`retirement_state: unverified` and `retirement_authorized: false` describe this
watch run: it executed no retirement probes and grants no new removal approval.
They do not erase the recorded removal evidence. Eligible releases still request
reassessment for every declared trigger, including regressions in replacements;
unknown provider coverage stays explicit. Dispositions and evidence participate
in the existing digest and comparison rules: registry edits change the source
scope and request a fresh observation; unchanged same-scope observations stay
quiet. No history, schedule or notification policy is replaced.

“Facade” is a pattern name, not a defect category. The request/wire facades above
compensate for integration limitations or candidate representation choices.
An ordinary feature client or composition root can remain useful after those
workarounds disappear. Native presentation types, `@MainActor` isolation,
compiler checking, package locks and macro approvals are not removal targets
merely because a temporary bridge uses them.

The normal iOS test job checks the actual generated modules. It verifies complete
switches and omitted-case rejection, requires public nested constructors after
IOS-15's removal, and reports strict generated-support availability. IOS-02 also checks the real native Home value,
generated service/raw-state Sendable captures and a Home actor-owned async call.
These partial isolation checks emit SIL so ownership diagnostics run; type checking
alone can miss an unsafe async transfer. An actor annotation by itself does not
qualify the generated async boundary. Home and Nearby now require actor-owned
refresh to compile and check their actual app clients/reducers with legal and
rejected off-actor calls. The report records the four-module profile and Nearby state as non-Sendable,
requiring MainActor Store reads and rejecting client/Store state transfers and an
unsafe Sendable container in the actual app. The strict-support check retains the producer's
upcoming-feature settings while testing Swift 6. Passing results only identify a retirement
candidate: actual reducer transitions, shared Home/Compose service ownership,
equality, cancellation and cross-runtime lifetime still need qualification before
removing an exception. Reports are in `build/logs/swift-export-checks/` and uploaded from PR jobs even
when the checks pass.
IOS-17 records the actual generated coroutine source hash, Job delegation,
inheritance diagnostic count and compiler opt-ins/diagnostic controls. A missing
warning requests source and contract review; it does not prove safe inheritance.
The release watch marks these checks `available_in_ci`; it does not pretend to
have run them or turn a passing probe into retirement authorization.

IOS-10 also includes the read-only
[project preflight](../../scripts/ci/check_ios_project.rb). It protects the reviewed
producer/search/link graph and shared test scheme from persisted IDE/project
rewrites. See [recovery and reproduction evidence](../reference/local-development.md#ios-project-integrity).
The guard detects drift; it does not make Toolchain-managed framework integration
a supported Swift-export path or automatically repair project files.

When reviewing Toolchain, its IDE plugin, Xcode or Swift-export updates, run project
management only in disposable copies. Then qualify actual IDE reopen, resync and
branch switching with an already-open project, preserving both app and appTests,
the local clock-test product, explicit test plans, supported generated modules and
one Kotlin runtime in Debug/Release builds. Record **retained**, **removal-ready**
or **incomplete**, with the exact tuple, before/after project model, commands and
native results. Remove replaced custom producer/preflight assumptions only after
supported integration replaces their contracts and the normal gates pass. Preserve
ordinary app/test/scheme regression assertions. The live IDE writer remains unattributed in the current evidence; command-line
management controls alone do not close that interactive check.

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

The historical candidate included admission, handle and drain policies that were
not adopted by the maintained app. The app now uses generated cases and direct
async clients with checked ownership; its remaining integration costs are listed
above. Development-test qualification does not grant signed-delivery or dependency risk
approval.

Android applicability and executable follow-ups for ordinary application
improvements are tracked in [cross-platform mobile feature follow-ups](mobile-feature-follow-ups.md).
Those items stay separate from IOS-prefixed bridge workarounds; fixing one native
consumer does not qualify the other consumer's lifecycle or effects.

## Readable Swift is an acceptance condition

`guard`, `try` and `do/catch` are normal Swift tools; their number is not evidence
of safety or modern design. The historical candidate spread transport failures,
state-handle checks and cleanup across feature branches. That cost must not be
reintroduced into the maintained reducers.

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
| IOS-17 | Selected coroutine template, official integration and coroutines Job inheritance contract | Inspect actual Native diagnostic receipt and any new opt-in; qualify an upstream-supported replacement with real error/cancellation/lifetime tests |
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

### IOS-08 source and compilation recheck recorded 2026-11-04

The [focused recheck](evidence/2026-11-04-ios08-strict-support.md) retains IOS-08:
the actual Kotlin 2.4.20 support graph fails strict Swift 6 compilation on Xcode
27.1, while the unchanged producer builds all eight Debug modules. The matching
upstream [KT-90266](https://youtrack.jetbrains.com/issue/KT-90266) is In Progress
with no available version recorded. Its ownership/sendability diagnostics now
provide a specific removal lead beyond the fixed coroutine milestones. The
official sample has moved to 2.5.0-Beta2; its new integration does not qualify
this exception's removal or Mobi's Toolchain path. The evidence records the exact
tuple, source revisions, separate module controls and required removal gates.

### IOS-15 removal with the reviewed Beta2 tuple — 2026-11-05

The [actual app update](evidence/2026-11-05-beta2-ios15.md) replaces the 43-line
Kotlin constructor helper with ordinary public generated constructors in the
existing Swift tests. The same compile contract refuses the retained 2.4.20
modules and passes on Beta2. It is now a required regression check. The update
uses Toolchain's supported compiler setting and Metro's minimum supported 1.5.0
companion, with the configuration and maintenance-review cost visible in that
record. Other interop mechanisms remain separately tracked; constructor
availability does not qualify their removal. Native results are recorded in the
app PR. Automatic inventory reports still do not authorize retirement.

### IOS-14 Home fixture simplification — 2026-11-06

The [Home-only recheck](evidence/2026-11-06-ios14-home-repositories.md) moves
success and ordinary unexpected-error repository doubles to Swift. The existing
tests check the actual Kotlin service result before native client fallback,
then check native payloads. Their Kotlin helper branches are removed.
IOS-14 remains open for typed repository-unavailable fixtures: exposing the
exception introduces a ninth Swift module in the measured candidate graph.
That broader export surface needs its own review and validation. Kotlin-origin
delayed work, cancellation and uncaught-error controls remain intentional bridge
tests. The file and its runner registration remain; no complete retirement or
new compiler capability compared with 2.4.20 is claimed.

### IOS-14 Nearby Swift repository success — 2026-11-08

The [Nearby success qualification](evidence/2026-11-08-ios14-nearby-success.md)
adds a stateless Swift implementation of the existing repository protocol to the
actual native suite. The real Kotlin service consumes its fresh snapshot, then
the native client and map presentation preserve the request-derived payload.
This adds success-path coverage; no Kotlin fixture is removed. Ordinary Swift
errors and typed domain failures need their own qualification, while Kotlin-origin
cancellation and uncaught-error controls continue to test the forward bridge.

### IOS-14 Nearby ordinary Swift errors — 2026-11-08

The [error qualification](evidence/2026-11-08-ios14-nearby-swift-errors.md)
extends the existing Swift double with immutable native error configuration.
The direct Kotlin service must return typed Unexpected state before native
fallback, for both snapshot-absent and cached states. Native presentation retains
cached content and manual retry availability. This qualifies another reverse
bridge path; typed domain exceptions and Kotlin-origin cancellation/uncaught-error
controls retain their separate purpose and no Kotlin fixture is removed.

### IOS-10 exporter runtime simplification — 2026-11-06

The [actual producer comparison](evidence/2026-11-06-ios10-exporter-runtime.md)
removes the explicit IntelliJ coroutines runtime and its repository. Beta2
generation succeeds using the compiler's standard transitive runtime, with
identical Swift/Kotlin/C bindings, the same eight Debug modules and the same
verified Kotlin archive. The resolved exporter graph excludes the extra runtime.
This retires one dependency workaround; IOS-10 remains open for custom build
integration. On updates, require clean generation logs and actual app checks;
do not reintroduce a runtime override automatically. No upstream fix or new
capability relative to an older Kotlin version is claimed.

The [OpenTelemetry owner assessment](evidence/2026-11-13-exporter-opentelemetry-review.md)
retains the two named Moderate findings and distinguishes the external exporter
dependency, compiler relocation and Toolchain launcher copy. On owner updates,
apply its [manual checks](dependency-review-playbook.md#exporter-opentelemetry-owner-review)
alongside generation/runtime qualification. No extra runtime or transitive override
is introduced, and this triage does not retire IOS-10 or accept the findings.

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

### Kotlin 2.5.0-RC source assessment — 2026-11-11

The [RC assessment](evidence/2026-11-11-kotlin-250-rc-assessment.md) maps the
Beta2-to-RC source changes to the actual producer and all nine active mechanisms.
It records the age gate, unverified Metro companion, unchanged coroutine support
and a bounded qualification plan. No dependency or workaround removal is adopted.

The subsequent [actual-app qualification](evidence/2026-11-11-kotlin-250-rc-qualification.md)
uses an explicitly approved RC age waiver. Both tuples pass the same five mobile
jobs, including unsigned Release. RC's runtime anchor gains retained external
visibility, but strict support still fails at KotlinError/KotlinBase diagnostics.
All nine active mechanisms remain; IOS-15's removed constructor workaround stays
removed and its regression check passes. Unchanged advisory findings and missing
coverage remain review inputs, separate from successful functional checks.

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

## Review increments against maintained code

The original sequence has delivered generated state/async boundaries and focused
correctness, ownership and lifetime improvements in the actual app. The tables
above replace that sequence as the current maintenance view. Future increments
should select one active mechanism and its existing replacement/removal checks,
or requalify a removed mechanism's replacement on an updated tuple. Historical
candidate machinery is not an adoption backlog.

Each PR explains its concrete before/after behavior and cost, and includes
short author comments on changed lines for non-obvious choices. Every workaround
comment cites its registry ID and removal condition. Experiments may gather
facts privately; review and adoption happen through changes to maintained code.
