## Context

See proposal.md for motivation. Adoption PR #35 carries revision `349e07e`; the Gradle bridge remains the production default. The existing executor can run baseline-first `direct-facade` pairs, verify source preservation, retain native case identities and recover only owned resources. Original Swift feature tests exercise mocked clients, leaving the real exported suspend seam unmeasured.

## Goals / Non-Goals

**Goals:** Measure identical typed/async fixtures in both paths, preserve original consumers and publish a reproducible, source-bound review of the observed behavior.

**Non-Goals:** Change cancellation policy, add generic production state, replace the existing facade, expand supported platforms, close device/release/onboarding gates or authorize a direct default/removal.

## Decisions

1. Add two fixture files to a separate source snapshot based on the adopted commit, then use the existing owned profile. This keeps production source and risk-bound maintenance code unchanged. A new profile would add unnecessary evaluator and source-binding drift for this bounded manual assessment.
2. Run six named Swift cases: native state payload adapters; an explicitly typed generic box retaining payload identity; real suspend client success/domain/unexpected failures; thrown Kotlin cancellation and current client mapping; Swift task cancellation versus pending Kotlin work; explicit completion and a second fresh continuation cycle. Mock-only reducer tests cannot establish those seams.
3. Keep a Kotlin standard-library continuation controlled by an explicit completion method and bound the wait for startup. Each native case uses its own instance; cleanup completes pending work. Report cancellation as observed behavior, including an existing limitation shared by both paths, rather than silently fixing the feature client.
4. Verify both original test identities and all six named cases from actual native logs, fixture hashes in each phase's source manifest and original fixture-source byte preservation. Retain the ordinary report's complete producer chain; a manual derived receipt states its extra verification and does not relabel the profile as broader parity proof.
5. Recover to quiescence, discard only owned generated copies/caches and replay the report after cleanup. Retain failed runs and corrected fixture revisions separately if a compiler/setup issue appears. The initial baseline fixture lacked a direct coroutines dependency in shared DI; its corrected lifetime fixture uses the standard continuation API without changing module declarations.

## Risks / Trade-offs

- Export syntax differs between bridge and direct headers → preserve compiler failures and distinguish fixture adaptation from candidate incompatibility.
- Existing task cancellation does not necessarily cancel Kotlin work → measure before asserting equivalence; retain the limit even on a passing pair.
- One generic class and controlled continuation do not establish all generic or lifecycle semantics → leave universal parity, deallocation/leak behavior, device runtime and release/hosted direct operation open.
- A prepared local host can hide bootstrap gaps → adoption hosted checks and empty-host/direct onboarding remain independent.

## Migration Plan

Prepare and hash the fixture source. Execute the existing paired profile, verify case identities and fixture/source/report chains, recover/cleanup/replay, then publish the bounded result. Production needs no rollback because fixture additions stay in isolated copies. Review remaining architecture/API and operational gates before proposing any default patch.
