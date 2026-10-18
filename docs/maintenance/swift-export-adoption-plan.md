# Swift export adoption handoff

This plan scopes a later app/CI wiring patch. Candidate implementation and
passing checks do not select it. Review the [candidate guide](swift-export-candidate.md)
and fresh run reports before making an integration decision. The deferred
[dependency maintenance and architecture archive follow-ups](swift-export-follow-ups.md)
track future Swift 6 alignment and the broader Toolchain adoption story.

| Decision | Required review input | Production selection |
| --- | --- | --- |
| Accountable maintainer | Person responsible for custom exporter/compiler coupling, diagnostics, recovery and replay | Jorge Castro, explicitly assigned |
| Native dependency tuple | Review the [two-pin macro termination repair](swift-export-macro-repair.md), Perception major-version compatibility and fresh advisories; repeat cold matrix/replay after selection | Two-pin repair and matching Xcode constraint approved/applied; all four cold cases and guarded replays passed locally; broader compatibility/risk review remains |
| Language profile | Compare `coroutine-swift5` and `generated-swift5` on the same tool tuple | Unselected |
| Repository policy | Audit every native, Compose and Kotlin caller of the exact Nearby repository cohort | Unselected |
| Transport/lifetimes | Closed facade admission, schema, synchronous Main copying, safe async seam, single-scene parent/route ownership | Candidate contract; adoption pending |
| Runtime limits | Parent reservations, separate per-owner Kotlin jobs, polling/backoff, soft shutdown and busy/retry UX | Diagnostic values only |
| Diagnostics | Tuple/emitter/message/location fingerprints; coroutine inheritance, casts/target, generated Swift and MapLibre/SwiftUI findings | No risk disposition approved |

The adoption patch must cite the Executor source/plan/execution-file bindings,
descriptor identity, installed compiler/SDK/JDK tuple, exact delivery identity,
module language modes, native lock revisions/binary checksums and fresh
post-cleanup replay receipts. A changed input requires applicable requalification;
warning totals and annotation opt-ins cannot substitute for that evidence.

First review the maintained cold source-to-app matrix and post-cleanup relocated
replay. Then qualify hosted macOS/clean-checkout behavior, actual devices,
minimum supported runtime, Android behavior/parity and relevant compiler/plugin
advisories independently. Release/archive/signing qualification is a separate
authorized stage. Local simulator success cannot close these gates.

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
