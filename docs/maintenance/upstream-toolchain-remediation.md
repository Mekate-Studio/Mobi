# Upstream Toolchain remediation rehearsal

This manual adapter compares the production wrapper against one reviewed candidate in `maintenance-kotlin-toolchains.json`. It retains Mobi's bridge configuration, native shells, minimum/target OS policy and compiler plugin declarations. The measured scope is module/delegated dependency graphs, successful compiler invocations and selected plugin fingerprints, Android host tests/debug APK, and ARM device/simulator KLIB compilation. Xcode tests, framework consumption, SwiftPM, device and release execution remain separate gates.

```sh
./scripts/dev/dependency_updates.sh prepare-kotlin
./scripts/dev/dependency_updates.sh rehearse-upstream --experimental --store upstream-remediation
```

Normal execution requires the configured release age. `--experimental` allows a young reviewed release only for assessment; its result retains `release_age` and never authorizes adoption. Unknown candidates, future publication, changed baseline wrapper bytes, unsupported compiler producers, missing graph scopes and altered producer summaries refuse execution or verification.

The 0.13.0 wrapper-only candidate encountered Compose 1.12.1 AAR minimum compile SDK 37 against Mobi's compile SDK 36. Preserve that attempt. A fresh supported rehearsal can add only the reviewed compile SDK patch:

```sh
./scripts/dev/dependency_updates.sh rehearse-upstream --experimental --compile-sdk 37 --store upstream-remediation
```

This requires the reviewed Android application baseline: compile/minimum/target SDK 36. It changes compile SDK only inside the candidate; installed SDK inputs are fingerprinted from a private copy. Application adoption would require SDK 37 provisioning on clean clones and CI, checks for use of APIs above minimum SDK 36, Android runtime tests and full retained-bridge iOS tests/builds. No SDK installation or production declaration change is implicit.

Toolchain 0.13.0 also requires Xcode first-launch readiness. A read-only preflight refuses another cold pair if `xcodebuild -checkFirstLaunchStatus` fails. Machine-wide first-launch setup is a separate authorized host action; the rehearsal neither runs setup nor accepts a license. A candidate that stops there has no credited Native compiler or SwiftPM execution. On the assessed host, license readiness passed but first-launch readiness exited 69. The user separately authorized first-launch setup, installation succeeded, and the readiness check then passed; the earlier failed attempt remains intact.

Inspect the complete pair before collecting providers:

```sh
./scripts/dev/dependency_updates.sh compatibility-report RUN_ID --store upstream-remediation
./scripts/dev/dependency_updates.sh review-advisories RUN_ID --phase baseline --store upstream-remediation
./scripts/dev/dependency_updates.sh review-advisories RUN_ID --store upstream-remediation
./scripts/dev/dependency_updates.sh compatibility-report RUN_ID --store upstream-remediation
```

Both exact selected query sets receive fresh OSV batches and full finding records. Partial, paginated, stale, failed or malformed evidence stays incomplete. Findings require triage; removed IDs mean absence in that measured lookup, not proof of exploit mitigation or a complete dependency surface. Compiler files retain fingerprints without invented Maven coordinates. The prior independent plugin-attribution evidence is not automatically transferred to a new compiler version.

The 0.13.0 delegated settings classpath exposes bundled files instead of Maven components. `compatibility-report` detects this loss of identity and compares each unique bundled file against verified baseline Maven artifacts by SHA-256 and byte length. Only a unique component byte match supplies a reference identity for the expanded provider lookup; filenames, changed bytes and ambiguous matches cannot establish coordinates. This is reference attribution, not proof that the candidate resolved that Maven component or variant. Both producer sets and the report derivation code hash are bound to the result.

In the [completed assessment](upstream-toolchain-assessment.md), 183 of 215 bundled files have unique baseline byte references; 32 remain unassigned. The expanded fresh lookup reports 16 of 17 baseline finding IDs, while the missing KAPT ID remains outside complete attribution. The report stays `attribution_incomplete` with `remediation_verified: false`. A prior named-only provider receipt is archived before replacement, preserving the misleadingly smaller 399-query/seven-finding lookup for review. Recovering byte identities and completing provider requests do not establish exploitability or fix the remaining dependency-surface gaps.

The separate [bundled attribution follow-up](bundled-input-attribution.md) verifies all 215 file bytes against the pinned distribution, accounts for those 32 identities and refreshes the lookup to 547 queries with all 17 baseline IDs. It preserves this earlier report instead of rewriting its measured scope.

```sh
./scripts/dev/dependency_updates.sh recover RUN_ID --stop --store upstream-remediation
./scripts/dev/dependency_updates.sh cleanup RUN_ID --apply --discard --store upstream-remediation
./scripts/dev/dependency_updates.sh compatibility-report RUN_ID --store upstream-remediation
```

Recovery checks exact process groups/JVM ownership. Cleanup deletes only disposable owned work after quiescence; control logs, references and provider receipts survive. A failed attempt is preserved separately from any passing patch. Never rewrite a failed receipt or credit an unexecuted capability. See the [SwiftPM scope assessment](toolchain-swiftpm-assessment.md) and [independent retirement gates](bridge-retirement-path.md).

The [retained-bridge adoption-gate guide](toolchain-adoption-gates.md) extends this default build-input profile with separate native, Android packaging, optimized iOS simulator and unsigned device archive pairs, an API 36 runtime supplement and version-bound plugin attribution. See its [measured assessment](toolchain-adoption-assessment.md) for the new scope and remaining blockers.
