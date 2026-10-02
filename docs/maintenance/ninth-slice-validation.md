# Ninth slice validation

Status: this record describes the historical working-snapshot measurement. The review implementation was subsequently committed locally as `9f730ef`, with the full pre-commit gate passing as recorded in [slice 10](tenth-slice-validation.md). Production dependency pins and Renovate policy are unchanged. The retained bridge remains selected. The [revised candidate](bridge-adoption-review.md) has separate evidence; dependency adoption needs a named decision.

## Implemented behavior

`bridge-review` extends the common executor with Toolchain graph introspection and all project/buildscript configurations of the iOS Gradle bridge. It retains nodes, dependency edges, selected variants, artifact byte hashes and Native distribution tree fingerprints. It inventories non-resolvable configurations and preserves controlled partial graphs on resolution failure. It uses the same four mobile jobs, resource ownership, recovery and cleanup as `bridge-mobile`.

The verified report compares paired graphs and emits normalized Maven package/version queries, with unsupported scopes and provider state explicit. It neither queries advisories implicitly nor authorizes adoption. Existing watch and direct profiles keep their scopes. The common source collector now separates Git stdout and stderr so a macOS warning cannot silently remove the first source file.

## Retained failures and corrections

1. The first baseline collector tried to read the Kotlin/Native distribution directory as a file. Its incomplete graph stopped the run before a candidate comparison. The correction hashes a sorted directory manifest of relative names, file bytes/executable state and in-bundle symlink targets.
2. The second baseline resolved its graph but the validator rejected Gradle's buildscript component identity `root`. The correction accepts that exact identity and retains strict refusal of host paths/unknown identities.
3. The third run passed the complete baseline, including 12 Swift tests. The candidate graph stopped at Kotlin 2.4.10's newly exposed SwiftPM lock-file metadata project artifact. It had no unresolved dependency edges, but the artifact did not exist because resolution does not execute its producer. Versioned Kotlin source identifies `serializeSwiftPMDependenciesMetadataForLockFiles`; the collector now runs that existing producer before fingerprinting. No file-presence check was waived.
4. An attempted contract run inside a restricted macOS sandbox failed process ownership checks because `ps` was unavailable. The full suite was rerun with normal macOS process access; sandbox failures remain local evidence. A separate source-collector regression injects a Git stderr warning and checks that the source is still captured and drift detected.

These outcomes are not relabeled as dependency incompatibilities or erased after a successful correction. Each has its own immutable result and cleanup evidence.

## Acceptance and limits

The final contract suite passes 194 tests (rechecked after the read-only report/query refinements). All five pinned static analyzers pass; the final warm static run took 5.219 seconds. Strict OpenSpec validation passes all 14 items, and whitespace checks pass. The graph contracts include unresolved/missing target scopes, artifact/tree identity, root components, selected variants/node closure, content/variant differences and advisory packaging normalization. Report contracts reject a nominally successful review without its graph references and retain `not_queried` for generated advisory requests.

The optional Renovate proposal was validated with the pinned repository-config validator using `--strict --no-global`; it exited zero. The installation's existing missing native RE2 addon triggers a fallback-to-RegExp warning, so this is schema/policy validation rather than proof of native RE2 behavior. The bounds remain a review-only artifact.

Local working-snapshot evidence is not a clean GitHub clone or hosted CI result for this slice. No commit-mode check is claimed before staging/approval. Raw native command logs, host/resource identities and full upstream responses remain under ignored `.maintenance/`; public receipts retain hashes, capability summaries and controlled diagnostics. Device execution, signed release packaging and direct-path retirement remain open.

## Completed paired rehearsal

The corrected run is `331034d527ef9bfe96a08c86992d0b4a`, from `2026-10-02T05:41:38Z` to `06:07:14Z`. Its state is `checks_passed`; all nine required cells passed in each phase, all 12 Swift cases ran in each phase, and source preservation is verified. The source HEAD is `3e6f1d5ad579e1e9ba1a3169a1b434dc74ee2d50`; the frozen working-snapshot SHA-256 is `0e06c07bb58bedcf72d0b926bffe99be1da0db5274f8a95e9b88aa6c3cce0a5f`. The exact adapter patch identity is `eee1dc6625c2c5dab53ac5c3b6c36684b8eabe7e619220e751989d7b61455151`.

Recovery verified quiescence and explicit cleanup removed both owned workspaces/caches while retaining immutable evidence. All four slice-9 attempts are cleaned; the three earlier outcomes remain in the [receipt](evidence/2026-10-02-slice-9.json). Reporting during an active cleanup correctly refused its held lease; reporting after cleanup verified the complete digest chain again. Historical stores outside this slice retain their earlier documented ownership limits.

The final reader excludes Toolchain constraint labels from advisory query generation and closes only `complete_bridge_target_graph` when both verified graphs exist. These read-only review refinements and final documentation were applied after the frozen native measurement; the receipt records both reader hashes. The exact queried package set remains unchanged, verified against the six fresh OSV response batches. Collection/native inputs did not change. This is a historical snapshot plus current review, not a claim that the final documentation tree was compiled. An authorized adoption must verify current preimages and validate its resulting snapshot.

The [review packet](ninth-slice-review.md) records the three stable Kotlin releases, ten Metro releases and two SKIE releases inspected; fresh platform assessment; graph/artifact deltas; two moderate advisories; exact proposed patches; recovery; and untested assumptions. The newer fixed tuple remains unqualified and SKIE 0.10.15 remains age-blocked until `2026-10-02T17:59:28Z` at this review time. No adoption, commit, push, publishing, new schedule or default change occurred.
