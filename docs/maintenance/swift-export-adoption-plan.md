# Swift export adoption handoff

This plan scopes a later app/CI wiring patch. Candidate implementation and
passing checks do not select it. Review the [candidate guide](swift-export-candidate.md)
and fresh run reports before making an integration decision. The deferred
[dependency maintenance and architecture archive follow-ups](swift-export-follow-ups.md)
track future Swift 6 alignment and the broader Toolchain adoption story.

Current handoff, 2026-10-13: the opt-in pilot files have been reviewed and its
published-clone and hosted native-only cold/replay qualification passed.
The later production integration should supersede the alternate pilot path;
the pilot PR remains unmerged. The fresh
[production risk review](swift-export-production-risk-review.md) identifies
generated coroutine/error API holds, a checked-import recipe candidate, a
Medium exporter-input advisory and five findings outside the older Toolchain
risk decision. These are concrete production requirements; no risk approval or
production selection was applied by that review.

Proposal update, 2026-10-14: the [production integration proposal](../../openspec/changes/production-swift-export-integration/proposal.md)
and [critical decision review](../../openspec/changes/production-swift-export-integration/decision-review.md)
make state-evolution maintainability the first gate. The current pilot's manually
coordinated numeric tags and Swift decoders are not an approved replacement for
the visitor trade-off. The first work is an isolated comparison with real
variant/payload changes and deliberately omitted mappings, before selecting the
production state boundary. All critical production choices remain review-required.

The first [state-boundary comparison](swift-export-state-boundary-review.md) now
has fresh typed-export/compiler controls and concrete evolution patches. It
supports generated sealed-state copying directly into native Home presentation
without a second handwritten transport enum. D1 remains proposed; async/lifetime
integration and the held rollback macro-validation preflight are not resolved by
those compiler results.

The [ownership comparison, 2026-10-15](swift-export-ownership-review.md) adds
closed native compiler clients and 32 Home/Nearby simulator checks comparing
polling with payload-free completion notification. Completion notification is
recommended for D2 review, with the extra Swift module contract and generic
listener/cleanup machinery highlighted as maintenance costs. Actual app/Shared
UI wiring, production membership, resource measurements and the rollback hold
remain pending; D1/D2 have no maintainer disposition yet.

Review cadence agreed later on 2026-10-15: proceed with provisional integrated
code and review actual feature changes in the draft PR before final acceptance.
The [composition/build review](swift-export-composition-review.md) and
[Home feature source](../../ios-app/interop/README.md) track that work. Candidate
implementation is authorized; production/default adoption and risk acceptance
remain pending.

| Decision | Required review input | Production selection |
| --- | --- | --- |
| Accountable maintainer | Person responsible for custom exporter/compiler coupling, diagnostics, recovery and replay | Jorge Castro, explicitly assigned |
| State boundary and maintainability | Actual Home/Nearby variant/payload evolution patches, missing-mapping failures, one authoritative contract and generation/upgrade cost | Generated typed copying proposed after compiler comparison; maintainer review pending; unchanged handwritten pilot tags/decoders remain rejected |
| Native dependency tuple | Review the [two-pin macro termination repair](swift-export-macro-repair.md), Perception major-version compatibility and fresh advisories; repeat applicable cold/replay after selection | Repair approved/applied; current native hosted qualification passed; fresh risk packet keeps production adoption held |
| Language profile | Compare `coroutine-swift5` and `generated-swift5` on the same tool tuple | Unselected |
| Repository policy | Audit every native, Compose and Kotlin caller of the exact Nearby repository cohort | Unselected |
| Transport/lifetimes | Closed facade admission, schema, synchronous Main copying, safe async seam, single-scene parent/route ownership | Candidate contract; adoption pending |
| Runtime limits | Parent reservations, separate per-owner Kotlin jobs, polling/backoff, soft shutdown and busy/retry UX | Diagnostic values only |
| Diagnostics | Tuple/emitter/message/location fingerprints; coroutine inheritance, casts/target, generated Swift and MapLibre/SwiftUI findings | Current cold/replay findings classified; import-check candidate rehearsed locally; production API/control dispositions remain pending |

The adoption patch must cite the Executor source/plan/execution-file bindings,
descriptor identity, installed compiler/SDK/JDK tuple, exact delivery identity,
module language modes, native lock revisions/binary checksums and fresh
post-cleanup replay receipts. A changed input requires applicable requalification;
warning totals and annotation opt-ins cannot substitute for that evidence.

The maintained matrix describes its recorded historical inputs. Current native
published-clone and hosted evidence is recorded separately. A changed production
graph needs fresh applicable cold/replay and hosted checks, actual devices,
minimum supported runtime, Android behavior/parity and current compiler/plugin
advisory evidence. Release/archive/signing qualification is a separate authorized
stage. The native-only simulator result cannot close those production gates.

If adoption is approved, scope a small app composition/build adapter patch and
repo-owned CI command. Keep workflow orchestration thin, public identity
`studio.mekate.mobi`, and Toolchain delegated Android bootstrap. Name migration
and rollback steps with a fresh complete snapshot of the working direct path,
including the approved macro repair and matching Xcode package constraint.
Revision `50ae26e4a40c3bc83fe10a2ad05645088330aa63` identifies the historical
direct baseline; restoring it alone would omit the subsequent repair.
The published equivalent is `ca3174dec9a295e24d0c40986652dcd92c2631e8`;
both revisions have the same Git tree before the repair.
Do not reintroduce the retired iOS
Gradle bridge or describe rollback as a flag switch alone.

No builder/default, credentialed delivery, dependency-risk or signing decision
is applied by this plan.
