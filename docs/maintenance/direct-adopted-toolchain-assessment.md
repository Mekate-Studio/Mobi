# Direct path after Toolchain adoption

Date: 2026-10-04. The bounded direct round trip, fresh build-input pair and
compiler-plugin attribution passed against locally adopted Toolchain **0.13.0**,
Kotlin **2.4.20** and Metro **1.4.5**. Bridge retirement remains deferred.
The [local adoption record](toolchain-adoption-risk-review.md) carries the scoped
risk and early-age decisions; those decisions do not approve a direct default
or physical bridge deletion.

## Executed evidence

| Check | Result |
| --- | --- |
| Integrated baseline and bridge-unavailable round trip | Run `96942bc52fc76b115913cf5011cc6bf4`, store `adoption-direct`, passed Android/iOS tests and debug builds, warm-cache Kotlin-to-Swift propagation, changed framework bytes and exact bridge restoration followed by passing original consumers. |
| Fresh selected build inputs | Run `a0e38241252627d396a90e99f0c57368`, store `adoption-direct-inputs`, passed both phases: dependency resolution, Android tests/debug builds and ARM device/simulator Kotlin libraries. Each phase recorded 37 compiler invocations, two selected plugin files, two delegated builds and 1,828 configuration entries; 612 configurations remain uncollected. |
| Compiler-plugin attribution | Run `ac0aa5d8f09fa1341cf0234b2bde0b15` in the same input store joined both selected fingerprints to Metro compiler 1.4.5 and Kotlin Compose compiler plugin 2.4.20 through independent resolver graphs in both phases. |
| Bundled settings inputs | All 215 fresh files in each phase exactly match verified 0.13.0 reference bytes: 183 Maven reference files, nine independently attributed Maven files and 23 registered source-module correspondences. Candidate Maven resolution/variants and source-binary reproducibility are not inferred from these joins. |
| Fresh advisories | One candidate-bound, complete 549-query lookup covers the identical derived phase query sets. It retains 17 known findings: two Critical, eight High and seven Moderate. No new IDs or severity drift were observed; no remediation or global exposure clearance is claimed. |
| Owned execution cleanup | All three runs recovered to quiescence, discarded only disposable workspaces/caches and passed report replay after cleanup. |

The [round-trip/adoption receipt](evidence/2026-10-04-toolchain-adoption-validation.json)
and [fresh direct-input receipt](evidence/2026-10-04-direct-adopted-toolchain.json)
bind source snapshots, commands, result hashes, artifact identities, provider
responses and manual query derivation. The latter explicitly replays an older
verified attribution producer and joins every fresh measured bundled file by
exact bytes; it does not relabel the older producer as a new resolution.
Both phase query sets are identical, so a duplicate baseline provider lookup
was not performed. Complete query responses cover this bounded inventory only.

The direct candidate uses an isolated typed facade with regular Objective-C
export. Its bridge absence covers direct stages before restoration. Production
Swift adapters, native targets and the Gradle iOS default remain current.
Initial upstream SwiftPM support is still documented but unexecuted.

## Remaining retirement gates

The next work is typed API and behavior parity: exhaustive sealed-state adapters,
typed payloads, DI, resources, generic export and cancellation/failure/lifecycle
behavior. ARM library compilation does not establish physical-device execution
or the exact minimum-OS window. Direct release/archive/signing, both native test
plans and macro handling, public clean-clone onboarding and cold hosted operation
still require their own evidence. General artifact, shaded/native-bundle and
non-Maven dependency surfaces remain incomplete.

These results close the local simulator/incremental/rollback and bounded
selected-input follow-up for the adopted tuple. They do not close the complete
capability matrix. Follow the [retirement path](bridge-retirement-path.md): a
reviewed reversible default switch comes before a separately approved physical
removal. Removing the hand-maintained iOS bridge leaves the measured delegated
Android settings inputs unchanged and cannot be described as fixing their
vulnerabilities.
