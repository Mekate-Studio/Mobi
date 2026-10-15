## 1. Baseline and isolated assessment setup

- [x] 1.1 Inventory the current direct and pilot closures, state mappings, generated APIs, composition roots and commands; retain exact source/tool identities and existing evidence limits.
- [x] 1.2 Capture a complete repaired direct-path rollback snapshot including dirty/untracked inputs, modes and project/native lock constraints; verify restore hashes in an owned copy outside disposable build roots.
- [ ] 1.3 Run direct build/tests against the restored copy and retain raw results; refresh the checkpoint if direct inputs change before integration.

## 2. D1 state evolution and D2 ownership comparisons

- [x] 2.1 Assess compiler-generated typed Home/Nearby state on the selected tuple in an owned copy; document variant coverage, native copying/isolation and exact unsupported surfaces without changing shipping membership.
- [ ] 2.2 If typed state cannot meet the contract, assess a constrained value boundary with mechanically derived bindings; compare single-source generation, bootstrap, debugging, upgrade and removal cost against the handwritten-tag pilot baseline.
- [x] 2.3 Exercise added variants, changed payloads, reordered declarations and removed/renamed cases; retain concrete diffs and all required edits across native iOS, Android and Shared UI.
- [ ] 2.4 Deliberately omit each required mapping and introduce stale/generated or invalid/version-skew input; demonstrate compile/mandatory gate failures and explicit boundary errors with no silent known-state substitution.
- [x] 2.5 Compare qualified observation alternatives against polling and exercise cancellation, stale delivery, noncooperative drains and cancelled shutdown waiters; record API closure and remaining generated coroutine/error findings.
- [ ] 2.6 Present D1/D2 comparison evidence and integrated feature-evolution code in `decision-review.md` and the candidate PR; record final maintainer selection, rejection or deferral before production/default adoption. Provisional candidate implementation is authorized for evaluation. If no option meets the contract, revise or defer rather than promote a workaround.

## 3. D3 composition and D4 build recipe assessment

- [ ] 3.1 Inventory every native/Compose/Kotlin caller of the exact repository cohort; exercise suspension overlap and compare Main confinement with complete-operation serialization only where required by observed behavior.
- [x] 3.2 Describe the candidate app closure preserving Native Home, Nearby Map and Shared UI, one Kotlin delivery and the exact same Home service; define identity and bypass failure controls.
- [x] 3.3 Rehearse candidate per-module language/import recipes with an active invalid hidden-type control; record exact tools, custom producer/flag coupling, upgrade procedure and profile alternatives.
- [ ] 3.4 Present D3/D4 evidence beside provisional composition/build code and obtain final maintainer dispositions before production/default adoption; keep local typecheck and hosted production qualification separate.

## 4. Implement the provisional candidate in owned builds for review

- [ ] 4.1 Implement the provisional state boundary and deterministic API/evolution gates, including reproducibility/stale-output controls if generation is chosen; prevent unsupported broader API use and preserve separate diagnostic findings.
- [ ] 4.2 Adapt app composition and native value/presentation boundaries to the provisional design without duplicating Kotlin business transitions; preserve cancellation/drain/admission semantics and make the integrated Home slice reviewable before extending Nearby and Shared UI.
- [ ] 4.3 Integrate Shared UI from the same delivery and Home service; prove identity and cohort coverage through real native/Compose loading, failure, retry, overlap and retirement controls.
- [ ] 4.4 Reuse repo-owned producer/delivery/CI components for the candidate command; preserve explicit selections and refusal behavior, app resources, macro approvals, public identity and delegated Android bootstrap.

## 5. D5 selected-graph and risk evidence

- [ ] 5.1 Attribute the actual selected production Toolchain/exporter/Compose/native graph and artifacts; distinguish build-time/runtime/host/embedded coverage and identify unresolved surfaces instead of treating historical inventory as current selection.
- [ ] 5.2 Acquire fresh authenticated GitHub and independent OSV evidence using canonical package positive controls, pagination/hash checks and repository freshness policy; include new and retained findings.
- [ ] 5.3 Observe every affected production JVM launch and descendant for private temp property, owner and permissions; record unmeasured native-library/reachability paths and separate decoder/allocation findings.
- [ ] 5.4 Rehearse supported remediation candidates where available or prepare a bounded exact finding/source/artifact/control/expiry decision; record actual diagnostic and dependency-risk dispositions without changing the old grant or substituting vendor JARs silently.

## 6. D6 app measurements and provisional settings

- [ ] 6.1 Measure real native/Shared UI navigation, retry, cancellation, background/foreground, overlapping owners, sustained work, retained jobs/objects and latency using explicitly experimental settings.
- [ ] 6.2 Compare observation/backoff costs and collect appropriate resource measurements for any energy or memory-byte claims; expose admission exhaustion and boundary failure behavior in the actual app.
- [ ] 6.3 Present traces, limits, retry behavior and shutdown semantics for maintainer settings disposition; do not promote fixture values or harness timeouts as production budgets.

## 7. Exact candidate qualification and reviewable publication

- [ ] 7.1 Run production candidate cold original/reordered builds and actual app tests with Shared UI enabled; include new variant/payload omission controls, active import checks, app resources and diagnostic fingerprints.
- [ ] 7.2 Verify quiescence and owned cleanup, then run guarded relocated replay of immutable deliveries; independently verify source/tool/delivery bindings, raw runtime results and unchanged source.
- [ ] 7.3 Run Android behavior/parity and direct rollback checks; obtain actual minimum-runtime and physical-device evidence within explicitly authorized device scope, recording missing capabilities without simulator substitution.
- [ ] 7.4 Once a meaningful integrated slice passes exact staged plan and required pre-commit gates, publish the draft candidate PR under the session's commit/push authorization; attach it, highlight unresolved design choices beside actual code, and continue clean-clone/hosted qualification on its exact source. This may precede completion of other qualification tasks; list their missing evidence. Keep the pilot PR unmerged.
- [ ] 7.5 Reconcile evidence and all critical dispositions for the exact reviewed source; refresh stale provider data or changed-input qualification and identify any remaining adoption/release holds.

## 8. Adoption, consolidation and recovery

- [ ] 8.1 Obtain explicit maintainer adoption for the exact API/profile/policy/settings/source and qualified target scope with verified complete rollback; record credentialed release as held unless separately qualified and authorized.
- [ ] 8.2 Apply only the approved default/composition change and remove obsolete visitors/projections and redundant pilot-only app selection while retaining reusable qualification components, original evidence and one maintained app path.
- [ ] 8.3 Update the feature blueprint, reference docs and superseding ADR with state-evolution examples, accepted maintenance costs and recovery instructions; preserve historical decisions instead of rewriting them as the adopted design.
- [ ] 8.4 Requalify final changed bytes through required staged/default/cold/replay/hosted gates and verify restore into an owned copy; do not claim change completion or authorize merge/release from planning status or earlier candidate results.

## Assessment progress, 2026-10-15

See the [state-boundary comparison](../../../docs/maintenance/swift-export-state-boundary-review.md)
for source bindings and compiler-only limits. Task 1.3 is held at the macro
validation preflight; complete content/mode restoration is verified but app
build/tests are not. The snapshot must be refreshed before integration if inputs
change. Task 2.2 remains conditional: generated typed-state compilation passed;
a second schema/generator is not currently proposed. Task 2.4 has case/field and
wrapper-escape controls but still needs stale-delivery and malformed-input
coverage. D1 is a proposed choice with concrete patches, not maintainer acceptance.

The [ownership comparison](../../../docs/maintenance/swift-export-ownership-review.md)
completes 2.5 as a bounded prototype assessment: 32 Home/Nearby simulator checks,
polling versus payload-free notification, closed native compiler clients,
cancellation fencing and independent drains. The existing shutdown algorithm
was exercised with a generic metrics reader. This is not actual app/Shared UI,
production module membership, cold/replay or hosted qualification. The negative
time control does not complete malformed-payload or version-skew coverage in
2.4. Task 2.6 has a concrete recommendation ready; actual D1/D2 maintainer
dispositions remain pending before production/default adoption. The maintainer
authorized provisional integration for code-based review on 2026-10-15; task
2.6 remains open for final acceptance, not as a block on candidate implementation.

The [composition/build review](../../../docs/maintenance/swift-export-composition-review.md)
completes 3.2/3.3 as bounded assessment: actual composition/caller inventory,
identity and bypass controls, the real TCA Home slice with 24 runtime checks,
normal native dependency/private generated import recipe, active hidden-layout
control and a refused strict Swift 6 support alternative. Fresh locked native
products built with explicit macro validation after an unapproved-macro refusal.
Task 3.1 remains open for complete Kotlin/Compose participation; 3.4 remains open
for final dispositions. Tasks 4.1–4.4 have partial Home code, not a finished
production boundary, complete app or repo-owned production entry point.
