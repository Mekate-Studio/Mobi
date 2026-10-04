## Context

The [proposal](proposal.md) follows source-bound interop and operational evidence on adopted Toolchain 0.13.0 / Kotlin 2.4.20 / Metro 1.4.5. Production remains on revision `349e07e` with Gradle/SKIE. The successful operational assessment removed the bridge only from generated candidates and used a managed direct Xcode phase. Its fixtures are evidence, not a selected production API.

## Goals / Non-Goals

**Goals:** Prepare a reviewable, source-bound patch; preserve feature meaning and explicit factories; make every caller report and execute the same integration; prove exact reversal and retain gaps honestly.

**Non-Goals:** Applying a production default, committing/pushing the draft, deleting bridge files, changing dependency pins or support floors, redesigning cancellation, inventing generic production state or authorizing signing/delivery.

## State and policy design

Keep Home's four counter states and two typed failure reasons; Nearby Map keeps six rider-location states, six snapshot states, four overlays and five blocked-location reasons. Payload-bearing variants and marker contracts remain in their feature modules. Shared Kotlin owns business transitions; Swift owns projection enums, localized copy and TCA presentation. `shared-di` owns the export facade beside explicit factories and remains reachable from the iOS module. Neither Circuit nor TCA types enter shared Kotlin.

The six visitor contracts comprise 27 exhaustive dispatch branches. A future state/reason case requires an exhaustive Kotlin dispatch update, a visitor method, a Swift adapter/enum update and native consumer tests. No `else` or native default branch is added to hide missing cases.

## Decisions

1. **Explicit visitor boundary.** Promote the measured typed facade shape and rename its Swift helper to `mobiProjection(of:)`. Keep concrete Kotlin payloads and native Swift enums. A loose tag/payload envelope weakens state semantics; a new compiler-plugin/export dependency lacks equivalent evidence. Keep the facade in the measured common `shared-di/src` location for this first migration, avoiding an additional unmeasured source-set move.
2. **Preserve cancellation semantics.** Kotlin services rethrow cancellation. Home's current Swift catch-all returns `Unexpected`; Nearby Map's catch-all returns the input state. The controlled standard-library continuation remains pending after Swift task cancellation until explicit completion. The Home/continuation facts have paired fixture evidence; the Nearby catch-all and absence of reducer cancellation IDs are source review facts. Keep these clients/reducers unchanged. Cancellation propagation, task identity, stale-response suppression and deallocation require a separate behavior change and evidence.
3. **Coherent direct content.** Add the shared-DI module edge, explicit facade and native adapters; use the Toolchain-managed integration phase. Add a separate repo-owned Xcode preflight before that managed phase so a stale Gradle/unknown selector refuses rather than misreporting which builder executed. CI, local validation, raw log wrappers, Fastlane and all GitHub iOS fallbacks select Kotlin in the draft. Explicit repository/environment overrides remain visible and are validated, not changed remotely.
4. **Bounded delivery scope.** Draft the development/test/unsigned transition only. The same content tree cannot truthfully promise a retained SKIE release by leaving one caller's default on Gradle. Credentialed archive/export/TestFlight entry points therefore fail before their signing/API-key work. Their later activation needs separate signed/export evidence and risk authorization. Unsigned simulator and raw unsigned archive assessment stay available; this hold is an explicit breaking scope decision for the maintainer.
5. **Content rollback.** Preserve all bridge/catalog bytes. Bind exact preimages, candidate bytes/modes, added files and patch hash against published `349e07e`. Reverse the full patch only after verifying all current candidate preimages; remove owned generated direct products before rebuilding restored consumers. Never overwrite unrelated caller changes or present `KOTLIN_IOS_BUILDER=gradle` alone as rollback.

## Risks / Trade-offs

- Hand-maintained visitors add an export surface → compile exhaustiveness and native protocol/enum checks accompany every new case; document the ownership in the feature blueprint.
- Regular export changes enum spellings and exposes Kotlin wrapper types → keep spelling adapters explicit, scope generic/lifetime claims to measured fixtures, and preserve concrete payloads.
- Retained SKIE and direct content have different integration assumptions → reject incompatible selectors in the draft and restore complete content for rollback.
- Credentialed lanes would otherwise use an unreviewed direct archive/export path → hold them before credential use; approve the unsigned scope or complete signing evidence before a broader default.
- Candidate changes touch risk-bound README/pre-commit inputs → the existing source acceptance must refuse a production scope extension until exact bindings and the maintainer decision are reviewed; its original expiry is not reset.
- Earlier hosted evidence used experimental helper names and no new preflight → reuse it only as supporting evidence; validate the exact new draft locally and require exact-revision hosted integration after approval.

## Migration Plan

1. Complete facade/cancellation/caller review and publish the unapplied draft and byte/mode receipt.
2. Validate the candidate's static gate and original Android/iOS tests/debug builds; exercise invalid/Gradle selector and signed-lane refusals without credentials. Check application and reversal against source manifests.
3. Obtain an exact maintainer decision on facade, cancellation preservation and the development/unsigned default scope with credentialed lanes held. Refresh bounded source/risk/advisory decisions as required; do not infer this from the current exception.
4. Apply/commit only reviewed content, run exact-source integration and both test plans/unsigned products, then collect a PR gate at the exact head. A default proposal does not inherit the old hosted run's approval.
5. Keep physical/exact-floor execution, broad Compose/resource/onboarding coverage and signed/export delivery gates explicit. Review bridge deletion only after a separately approved default and complete applicable parity evidence.

Rollback restores all reviewed source preimages and modes, removes only owned generated products and reruns restored native consumers. The review receipt distinguishes exact byte reversal from a future integrated native rollback execution.
