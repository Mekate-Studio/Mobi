# Critical production design decisions

Status: D1/D2 assessment ready for review; production choices unapproved. Date: 2026-10-15.
Accountable maintainer: Jorge Castro. Preparing this proposal, assessing
alternatives and provisional integration are authorized; this is not final
acceptance of their trade-offs.

## First review: state evolution, not just a successful build

The current pilot trades visitor adapters for handwritten numeric tags and
decoders. That is a concrete risk of repeating the original maintenance problem.
**D1 is the first design to evaluate through integrated candidate code.**
The recommendation is to assess compiler-generated typed state first, then a
constrained value boundary only if its bindings can be derived from one contract
and its total maintenance cost is acceptable. Typed state now has bounded
compiler and lifecycle evidence; production qualification remains pending.
Promoting the existing tag tables unchanged and adding another handwritten visitor
layer are rejected migration targets. Deferring the migration is valid if no
candidate meets the criteria.

The isolated comparison provides actual patches
for a new Home/Nearby variant, changed payload, reordered declarations and removed
or renamed case. It shows required edits and deliberately incomplete mappings
that fail compilation. The comparison must cover debugging,
upgrade and regeneration burden as well as routine feature work. It must retain
Kotlin-owned domain semantics, native Swift presentation and Shared UI.

## Review queue

| ID | Critical choice | Proposed direction | Evidence required before disposition | Status |
| --- | --- | --- | --- | --- |
| D1 | State representation and evolution | Generated typed sealed state with synchronous native presentation copying; Home can omit a second handwritten Swift transport enum | [Compiler comparison and actual patches](../../../docs/maintenance/swift-export-state-boundary-review.md); generated switches catch new/renamed cases and payload changes; native presentation meaning remains explicit | `review_required`; compiler assessment passed, actual app/lifetime integration pending |
| D2 | Async bridge, observation and lifetime | Payload-free completion notification; synchronous Main-confined copying behind a closed native Swift module | [32 Home/Nearby runtime controls, compiler closure controls and concrete sources](../../../docs/maintenance/swift-export-ownership-review.md); production membership, real app composition and resource measurements still pending | `review_required`; bounded comparison passed; additional module contract and listener/drain ownership require maintainer disposition |
| D3 | Repository concurrency | Continue `main-confined` provisionally; real native cohort allowed overlap of two, mutex serialized to one | [Caller/composition inventory and native cohort checks](../../../docs/maintenance/swift-export-composition-review.md); complete Kotlin/Compose participation, identity and contention effects remain pending | `review_required`; native cohort passed, Shared UI scope not qualified |
| D4 | Profile, producer and import checking | Provisional `coroutine-swift5` / Swift 6 consumer; normal native dependencies, private generated imports and active checker | [Real Home build, compiler/macro controls and upgrade procedure](../../../docs/maintenance/swift-export-composition-review.md); production command/cold/replay/hosted remain pending | `review_required`; local Home compile/link/runtime passed, fully strict support alternative refused |
| D5 | Remediation or bounded dependency/diagnostic risk | Prefer a supported repaired cohort; retain unresolved findings for explicit decision | Actual selected production graph, current provider evidence and coverage gaps, per-launch temp controls, exact findings and control/reachability analysis | `review_required`; old approval cannot cover this scope unchanged |
| D6 | Runtime settings and default adoption | Measure limits first; choose default and target scope after qualification | Native/Shared UI traces, resource/latency measurements, failure behavior, source-bound platform gates and tested complete rollback | `review_required`; pilot settings are experimental |

Shared UI preservation, one Kotlin delivery, the same Home service, public
identity and the retired iOS Gradle bridge are established constraints, not
pending options to relax. See [design.md](design.md) for alternatives and
[tasks.md](tasks.md) for the sequence.

## Concrete D1/D2 review packet, 2026-10-15

**Recommendation:** assess production integration using generated typed state,
direct copying into native presentation, and payload-free completion notification
behind a closed Swift module. D1's actual evolution patches and D2's compiled
prototype sources are linked above. This removes the project's handwritten
feature tag/decoder registry without introducing another visitor contract.

**Costs requiring review:** the build must maintain a separate native boundary
module with restricted app search paths, and the project must own generic
subscription/disposal and independent cleanup logic. Ordinary feature changes
should edit Kotlin state and native presentation meaning, without adding a
transport case table. Home demonstrates that shape; Nearby's assessment model
still needs integration with the existing presentation without a parallel mirror.
Prototype assertions, internal errors and fixture constructors are not the
finished app-facing failure/factory API.

**Alternative:** retain polling while assessing another supported bridge, or
defer integration if module/lifetime complexity is not acceptable. The repaired
upstream async bridge has not been qualified. Generated coroutine/error findings
remain separately review-required whichever observation mode is chosen.

**Disposition:** `review_required`. Final selection, rejection or deferral of
D1/D2 remains pending. On 2026-10-15 Jorge Castro authorized provisional
implementation so the integrated code and realistic feature changes can be
reviewed before acceptance. Task 2.6 remains open for that final decision;
candidate integration and D3/D4 assessment may proceed. Production/default,
dependency-risk and runtime settings decisions remain separate.

## Code-based review cadence agreed 2026-10-15

Proceed provisionally with typed state, completion notification and the closed
native module. Assess actual composition/build, integrate Home, then Nearby and
Shared UI using one graph/delivery, and prepare the draft PR once a meaningful
slice passes exact commit gates. The PR must show the actual code for adding a
state/payload, every required edit, omission failures and the generic code the
project must maintain. Highlight substantial complexity as it appears, without
requiring acceptance of abstract trade-offs at every step. Revising or rejecting
the candidate remains possible before adoption. This is implementation scope
for evaluation, not final design, dependency-risk, default or merge acceptance.

## Required decision record

For each decision, append a concrete record here with:

- ID and status: `review_required`, `approved`, `rejected` or `deferred`.
- Exact selected option and scope, source/configuration identity, selected tool
  and dependency tuple, and applicable target/platform.
- Evidence links, hashes and dates, including failures and missing coverage;
  a changed implementation must not reuse a mismatched receipt.
- Alternatives and why the selected option is maintainable for feature authors.
- Accepted costs, rejected shortcuts, accountable owner and upgrade/removal path.
- Maintainer disposition and date. Record human acceptance only when actually
  given; technical assessment and artifact completion are not acceptance.
- Requalification triggers and expiry where applicable. Keep dependency-risk,
  diagnostic, settings and adoption decisions distinct even when linked.

Reviewers should be able to see the smallest concrete example of a feature
change before accepting D1. A green build, fewer warnings or a smaller promotion
diff does not answer that design question. If evidence makes the proposed
direction untenable, update the proposal/design and dependent tasks before
asking for acceptance of another trade-off.

## Existing evidence and its limits

- [Integrated Home slice and composition/build review](../../../docs/maintenance/swift-export-composition-review.md): 24 real TCA Home/native-cohort runtime checks, normal TCA/private Kotlin import recipe, active hidden-layout control and explicit macro-validation refusal/approved build. Candidate source is reviewable under `ios-app/interop`; Nearby, Shared UI, production orchestration and final dispositions remain open.
- [Ownership comparison](../../../docs/maintenance/swift-export-ownership-review.md): closed native compiler clients and 32 macro-free Home/Nearby simulator cases, with both polling and notification. Real app/Shared UI, production membership, resource measurements and delivery skew remain open. The direct rollback macro hold persists.
- [State-boundary comparison](../../../docs/maintenance/swift-export-state-boundary-review.md): fresh source/export and native/consumer compiler controls with concrete patches. Native Home can copy directly into its existing presentation type. This does not qualify the app, Android SDK, lifecycle or delivery skew. The rollback macro-validation preflight remains incomplete.
- [Production risk review](../../../docs/maintenance/swift-export-production-risk-review.md): technical findings, source bindings, 22 historical build-input advisory IDs and five IDs outside the old grant, plus explicit coverage gaps. Refresh provider evidence when needed; this is not the actual selected production graph.
- [Native hosted qualification](../../../docs/maintenance/swift-export-native-qualification.md): native-only simulator cold/replay evidence for the recorded tuple; no production Shared UI, device or floor-runtime credit.
- [Adoption handoff](../../../docs/maintenance/swift-export-adoption-plan.md): remaining profile, concurrency, measurement, platform and recovery decisions.

No production choice or maintainer risk disposition has been recorded by this
proposal. PR #37 remains the pilot reference; this production work should
supersede its alternate app path rather than rely on merging it first.


Qualification order confirmed 2026-10-15: Native Home and Nearby first, with
Shared UI qualification following separately. This orders candidate work; it
does not remove Shared UI, the same Home service or one-delivery requirements
from final adoption. The provisional closed module now contains both native
features; see the [native integration review](../../../docs/maintenance/swift-export-native-integration-review.md).
