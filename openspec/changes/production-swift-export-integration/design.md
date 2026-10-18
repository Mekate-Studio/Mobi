## Context

See [proposal.md](proposal.md) for motivation. The direct path uses six Kotlin visitor interfaces and six Swift projection adapters in `shared-di/src/MobiInteropProjection.kt` and `ios-app/src/MobiInteropProjection.swift`. The pilot instead encodes state in `shared-ios-export/src/HomeFacade.kt` and `NearbyFacade.kt`, then decodes it in `ios-app/pilot/swift/NativeHomeAccess.swift` and `NearbyWireDecoder.swift`. Numeric tags, payload validation and native enums are manually coordinated today.

The [risk review](../../../docs/maintenance/swift-export-production-risk-review.md) establishes a narrower synchronous Main-confined caller path, unresolved generated coroutine/error findings, a locally active import-check candidate and incomplete production dependency coverage. The [hosted qualification](../../../docs/maintenance/swift-export-native-qualification.md) covers native-only `coroutine-swift5` / `main-confined`, not production Shared UI, actual minimum-runtime execution, devices or releases. Runtime settings remain experimental.

This design chooses a staged assessment and integration process with explicit acceptance conditions. It does not select the shipping state representation in advance of the maintainability comparison. The alternatives below must satisfy the same [behavior contract](specs/production-swift-export-app/spec.md); an alternative that requires changing that contract requires a revised proposal and review.

## Goals / Non-Goals

**Goals:**

- Make ordinary shared-state changes easy to understand, with one authoritative state contract and visible failures for incomplete handling.
- Keep Kotlin business transitions separate from Swift presentation and transport/isolation machinery.
- Reuse proven components where they reduce total maintenance burden, including upgrade and debugging work.
- Prepare concrete decisions and source-bound evidence through provisional integrated code before production/default adoption.

**Non-Goals:**

- General export of arbitrary suspend, Flow, mutable Kotlin objects or Kotlin errors.
- A new generic serialization framework or automatic migration to newer dependencies.
- Removing Shared UI, changing product state semantics, or adding another Kotlin graph to simplify interop.
- Stable binary ABI, library evolution, multi-scene support or credentialed release operation by implication from simulator results.

## Decisions

The [decision review](decision-review.md) tracks the critical choices, their evidence and maintainer dispositions. Proposed choices are not approved choices. Jorge Castro is the accountable maintainer; technical findings and successful tests cannot write an acceptance on his behalf.

Review cadence, agreed 2026-10-15: implement the proposed direction provisionally
for code-based evaluation. Assess the actual composition/build, integrate Home
first, then Nearby and Shared UI, and prepare a draft PR once a meaningful slice
passes exact commit gates. Show feature-evolution diffs and generic bridge code
separately, with critical choices linked beside their implementation. Acceptance
is evaluated against integrated code; candidate work must not silently change
defaults, accept dependency risk or remove the verified recovery path.

### D1 — Shared-state boundary: production selection requires an evolution comparison

Assessment update, 2026-10-14: the [compiler comparison](../../../docs/maintenance/swift-export-state-boundary-review.md)
demonstrates generated sealed-state exhaustiveness for the real feature sources
and direct Main-actor copying into the existing native Home presentation without
an intermediate handwritten transport enum. This supports the typed-state
direction for review. Actual app/lifetime/API closure, delivery mismatch and
runtime qualification remain pending; no D1 acceptance is inferred.

**Proposed direction:** use compiler-generated typed state when it satisfies the isolation and lifetime contract with the selected tools. If it cannot, compare a constrained value facade whose variant/payload contract and cross-language bindings come from one authoritative declaration. Typed state now has bounded compiler and lifecycle evidence; the mechanically derived fallback has not been assessed. The current tag-based pilot is the comparison baseline, not the selected production representation.

| Alternative | Potential benefit | Maintenance cost or blocker | Treatment |
| --- | --- | --- | --- |
| Generated typed state, with a narrow native copying boundary where needed | Avoid a separately maintained state protocol | Must demonstrate variant coverage, invalid handling, Main confinement and safe copying on the exact exporter tuple; Kotlin wrappers must not escape across suspension | Assess first; do not assume direct sealed-state export is sufficient |
| Constrained value facade with mechanically derived bindings | Keep asynchronous Kotlin execution behind a closed API | Additional generation/schema machinery, diagnostics and upgrade responsibility; prove it is smaller and clearer than the workaround it replaces | Assess only if direct typed state fails the safety criteria |
| Promote pilot's handwritten numeric tags and decoders unchanged | Small initial promotion diff; existing runtime evidence | Parallel tables and nullable payload combinations still demand coordinated Kotlin/Swift edits and allow maintenance drift | Rejected as a production contract |
| Reintroduce handwritten visitors/projections | Existing direct baseline works | Recreates the trade-off that prompted this investigation | Rejected as the migration target; preserve only as historical/rollback content |
| Defer migration | Avoid adding an unsatisfactory permanent abstraction | Retain the known baseline until a qualifying option exists | Valid review outcome if the candidates fail |

In an owned copy, compare candidates on actual Home and Nearby state, not a toy enum. Add a state variant and a payload field, reorder declarations, and remove or rename a case. Record the diff, files and independent declarations changed, required reader knowledge, errors seen when each adaptation is deliberately omitted, and effects on Android/Shared UI. Do not invent an approved lines-of-code threshold. The maintainer must be able to inspect the actual patch and resulting failures.

Variant discrimination and payload shape must have one authoritative source. Generated bindings must be reproducible and stale/edited outputs must fail the repo gate. Stable wire identifiers, if required, must not depend on enum ordinals; protocol/version skew must refuse explicitly. Native rendering may have its own presentation enums and exhaustive handling, but it must not recreate a parallel transport registry. Unknown or malformed input must not become `.unexpected`, `.initial`, a dropped case or a crash-only feature contract.

The new-variant exercise must surface a missing consumer mapping at compile time or through a mandatory deterministic contract gate before the application can treat it as a valid state. Reorder tests alone are insufficient. Include the owner, dependency on custom generation, upgrade procedure, and removal path in the D1 decision. If a new tool or generator recreates comparable coordination burden, defer rather than declare the migration complete.

### D2 — Asynchronous ownership and exported API: narrow synchronous access is a candidate

Assessment update, 2026-10-15: the [ownership comparison](../../../docs/maintenance/swift-export-ownership-review.md)
passed 32 Home/Nearby simulator controls with both polling and payload-free
completion notification. A separately emitted native Swift module admits native
async clients without raw module search paths and refuses raw imports/public
Kotlin leakage. Completion notification is the proposed alternative for review:
it wakes a Main-confined synchronous result copy, while parent-owned cleanup
retains capacity until actual completion. The additional module contract and
listener/disposal machinery are critical maintenance costs, not accepted choices.
Actual app/Shared UI composition, public failure handling and production target
membership remain pending.

**Proposed direction:** retain synchronous Main-confined facade access with native value copies as the initial safety baseline while comparing simpler qualified alternatives. Kotlin owns feature execution; native tasks own observation/cancellation. Export/caller membership must constrain the supported API; an import ban or text search alone is insufficient evidence of general bridge safety.

Alternatives are a repaired upstream async bridge with demonstrated error/Sendable/cancellation semantics, or a constrained callback/event bridge with explicit lifetime ownership. The callback alternative now has the bounded assessment above; upstream async repair remains unqualified. Compare setup, code ownership, cancellation acknowledgements, drains, CPU/energy/latency and debugging cost. Do not permanently select polling merely because the pilot passed. Fixture read/wait counts do not establish resource measurements or production settings.

Generated `SwiftJob` inheritance and `KotlinError` remain explicit findings. A closed supported API must demonstrate that callers cannot use the broader bridge; any remaining generated/linked implementation still needs its own disposition. Do not describe source-call absence as whole-binary unreachability, patch generated code with unchecked Sendable, or silence diagnostics.

Preserve close-admission retirement, stale-result fencing, parent-owned cleanup and release of capacity only after actual completion. Cancelling a waiter must not cancel cleanup. Background/tab transitions preserve route ownership. Noncooperative operations must remain accounted for after soft shutdown observation expires. A transport change must pass these same failure and lifetime controls.

### D3 — Repository concurrency and Shared UI: one graph is fixed; policy remains reviewed

**Established requirement:** preserve all three main-app flows, one Kotlin delivery, one app composition root and the exact same Home service for native Home and Shared UI. Nearby owners share the declared repository cohort. Compose must participate in qualification and source/graph attribution; native-only evidence cannot substitute.

**Proposed policy candidate:** `main-confined`, because it has current bounded hosted evidence. Audit every native, Compose and Kotlin entry/resumption on the exact repository instances. Main confinement permits suspension overlap and is not whole-operation serialization. Compare `shared-operation-mutex` if real interleavings require complete-operation serialization, including UI/cancellation/starvation cost. Do not apply an independent Swift lock to only one caller subset or impose serialization without evidence.

Composition identity checks and integration tests must show native/Compose work using the same service rather than merely equivalent output. Preserve shared business rules and Android behavior; transport-specific declarations belong at the iOS boundary.

### D4 — Compiler/build recipe: promote checked behavior, then requalify

**Proposed candidate:** `coroutine-swift5` with Swift 6 native consumers and actively checked implementation-only imports. Compare other profiles when the selected tuple permits a smaller supported design. The local `CheckImplementationOnly` probe is a candidate, not a hosted qualification or permanent approval of an experimental flag.

Record a per-module recipe, all selected source/artifact/tool hashes, target, resources, macros and graph. Require a positive checker control that compiles under the baseline and fails under the checked recipe, plus actual production app compile/link/runtime. Preserve diagnostics by source/tuple/emitter/message/location, with unknown findings requiring review; no count-based warning allowlist.

Alternatives are a fully strict Swift 6 support graph or a supported upstream production integration. Their availability/suitability must be measured, not inferred from documentation or version names. Include custom producer/flag upgrade ownership and a tested recovery path in the decision.

Production orchestration lives in repo-owned commands used by local gates and thin CI. Reuse qualified delivery/provenance components where possible rather than build a second pipeline. Candidate builds use owned source copies until adoption. Fail an unsupported tuple or missing native lock/macro approval before consuming a delivery; no implicit compiler-profile or builder fallback.

### D5 — Dependency risk: exact selected graph and controls before disposition

**Proposed direction:** prefer a supported repaired dependency cohort after bounded rehearsal. If remediation is unavailable, present a concrete source/artifact/control/expiry decision for maintainer review; do not preselect acceptance or silently replace vendor JARs.

Collect the actual selected production Toolchain/exporter/Compose/native graph and separate build-time, app-runtime, host-tool and embedded components. Refresh authenticated GitHub and independent OSV acquisition, retaining canonical package-name positive controls, pagination, hashes and explicit missing coverage. Historical 549-query inventory is a lead, not current production attribution. At a risk decision, evidence must meet the repository's freshness policy, including the risk review's 24-hour advisory window; refresh if elapsed.

The October 13 packet contains five IDs outside the old 17-ID grant, including LZ4 findings, and an exporter OpenTelemetry match. Existing Critical/High findings and missing embedded/host coverage must remain visible. Private JVM temp handling must be verified for every affected production launch and descendant JVM, including owner/mode/property; the version-only probe does not prove those paths and does not fix decoder/allocation findings. Record unmeasured reachability without converting it into mitigation.

An approved exception, if chosen, must bind exact findings, source and selected artifacts, controls, maintainer, scope, expiry and invalidation triggers. Changed findings/source/scope invalidate carry-forward. General diagnostic decisions, dependency risk acceptance and production adoption are separate records.

### D6 — Runtime settings and adoption: measure first, keep scope explicit

**Proposed direction:** use declared experimental settings only to measure candidate behavior. Compare polling/event observation and backoff where relevant. Measure real navigation, retry, cancellation, background/foreground, overlapping native/Compose owners, sustained work, retained jobs/objects, latency and resource use. Energy or memory-byte claims require suitable instruments; test poll counts alone cannot establish them.

Present the measurement traces and failure behavior before approving reservation/job limits, observation intervals, backoff and shutdown deadlines. No fixture constants or arbitrary timeout increases become production budgets. Rejected work needs explicit native presentation and retry behavior, not hidden loss or uncontrolled backend queuing.

Adoption selects an exact profile, API, policy, settings, dependency/diagnostic decisions and target scope after fresh qualification. Default switching and removal of obsolete app wiring happen only within that approved scope. Development/unsigned adoption and signed release remain independently qualified; unqualified surfaces stay held and the proposal cannot be called complete while its required gates remain open.

## Risks / Trade-offs

- A different adapter reproduces the visitor maintenance burden → inspect real evolution patches and failed omissions before choosing D1; a passing runtime suite is insufficient.
- A generated schema becomes another framework to own → include bootstrap, errors, regeneration, upgrade and removal work in D1/D4; reject a disproportionate solution.
- Polling and drains become permanent complexity → compare qualified observation alternatives and measure real app cost before D2/D6 approval.
- A narrow caller API is mistaken for a safe complete generated bridge → maintain separate API enforcement and diagnostic/reachability evidence.
- Shared UI changes the graph and concurrency → cold build/test and replay with Compose enabled, one service identity and complete cohort checks.
- Previously accepted risk is carried into a new graph → exact source/artifact/finding binding and fresh provider controls; no automatic acceptance.
- Pilot and production drift into two apps → consolidate app composition and remove redundant app wiring after adoption while retaining generic qualification controls and historical evidence.

## Migration Plan

1. Capture a fresh complete direct-path content snapshot, including current dirty/untracked inputs, file modes, native macro repair and project constraint. Restore and run direct build/tests in an owned copy; preserve evidence independently. A historical revision alone is insufficient.
2. Assess D1/D2 with actual feature-evolution and lifecycle comparisons in isolated copies; collect D3 cohort and D4 recipe alternatives. Prepare evidence before requesting decisions. Do not promote unresolved boundary choices into shipping membership.
3. Record provisional choices and unresolved costs in [decision-review.md](decision-review.md). Implement the candidate in owned builds for integrated code review; collect D5/D6 evidence alongside integration. Incompatible candidate findings require a revised design rather than an ad hoc workaround. Final maintainer acceptance remains pending.
4. Wire Home, then Nearby and Shared UI in the provisional app closure; repeat source-bound cold original/reordered and guarded relocated post-cleanup replay, adding the new variant/payload controls. Verify app resources, native package macros, failure/cancellation/drains, service identity and Android parity. Prepare the draft PR once a meaningful slice passes commit gates so review can occur before qualification is complete; label missing evidence explicitly.
5. Publish/requalify the exact reviewable source through clean-clone and hosted paths, with actual deployment-floor runtime and physical-device evidence. Stage intended content only when preparing a commit and run the exact staged plan/gate. Device and credentialed release operations require their own authorized scope.
6. Review exact production adoption and rollback scope. Apply the approved default/composition changes; retire obsolete visitors/projections and pilot-only app selection, update the feature blueprint and superseding ADR, then rerun the gates for the final bytes. Keep release held until its separate qualification/authorization closes. Do not merge PR #37 as a shortcut to this decision.
7. For recovery, restore the complete verified content closure in an owned copy first, remove only transition-owned outputs, verify hashes/modes and direct smoke tests. A live restoration of the user's checkout requires explicit scope. Preserve historical receipts and durable public summaries; archive only through a separately requested completion process.


Qualification order confirmed 2026-10-15: Native Home and Nearby first, with
Shared UI qualification following separately. This orders candidate work; it
does not remove Shared UI, the same Home service or one-delivery requirements
from final adoption. The provisional closed module now contains both native
features; see the [native integration review](../../../docs/maintenance/swift-export-native-integration-review.md).
