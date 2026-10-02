## Context

The compatibility runner already isolates source/homes/caches, guards caller identity, tracks native resources and verifies result/log/reference hashes. Its typed-facade experiment removes the bridge in the candidate build copy. See `proposal.md` for motivation. Current accepted ADRs require native targets, typed shared states and explicit composition roots.

## Goals / Non-Goals

**Goals:** distinguish initial direct success, incremental behavior propagation, authored-source restoration and rebuilt bridge consumers. Make failures recoverable with existing commands and retain every attempted stage.

**Non-Goals:** dependency adoption, production facade changes, default selection, physical-device/release/signing claims, new CI schedules or private services. True clean-clone onboarding and cold hosted CI remain separate from a fresh owned local snapshot on a prepared host.

## Decisions

1. Add `direct-roundtrip` alongside existing profiles. The unchanged baseline still runs first; only the candidate performs the direct experiment. Reusing repo-owned jobs keeps native test/build behavior aligned. A separate ad-hoc build script would drift from those jobs.
2. Add an isolated Kotlin object with one string-returning method and a native Swift Testing assertion. Change both the method's return and Swift's expected value with existing caches/products retained. A stale Kotlin binary fails the new native expectation. Record pre/post source and framework identities. Repeating an unchanged build alone would not prove invalidation.
3. Capture original authored bytes and modes before transforming the copy. Validate all expected authored inputs, symlink boundaries and bridge absence before restoration. Restore only changed/deleted inputs and remove additions. Clear the owned `build/` tree before bridge validation so direct products cannot supply a false rollback pass. Ordinary cache reuse is distinct from product reuse.
4. The report verifier requires measured stage cells, verified test-case references, changed framework identities and restoration matching the original source manifest. Close only `incremental_direct_build` and add an explicit passing local rollback capability. Remaining retirement gates and authorization stay visible. A successful executor summary alone is insufficient.
5. Keep ADR 0003/0006 accepted. A proposed ADR records conditional transition gates and the typed-facade tradeoff; no switch or removal is implied. Fresh primary sources remain leads, independently of local evidence.

## Risks / Trade-offs

- Synthetic probe coverage is narrow → retain all original native cases and disclose generic/cancellation/lifecycle limits.
- Xcode and framework artifacts can vary for unrelated reasons → require the changed Swift assertion in addition to byte differences; do not interpret hashes as performance or full provenance proof.
- Restoration failure can leave a partial owned copy → classify non-passing, preserve logs/resources and use existing recovery/cleanup; caller content is never restored or overwritten.
- Extra builds can exceed runtime budgets → use a longer bounded profile timeout within the existing outer deadline; timeouts remain inconclusive.
- Security review from slice 9 is still relevant → current compiler/advisory findings are not cleared by this experiment and remain adoption gates.

## Migration Plan

Ship only the manual evaluator, contracts and evidence documents. Run a paired local rehearsal and retain its source-bound receipt after quiescence/cleanup. If broader parity later passes, review a named reversible default patch separately, then consider physical bridge removal with its own complete matrix and approval. Rollback after an authorized production removal would restore the exact reviewed prior revision and rerun its native jobs; this local round trip does not authorize that operation.
