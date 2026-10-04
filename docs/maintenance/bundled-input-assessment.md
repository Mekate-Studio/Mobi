# Toolchain 0.13.0 bundled-file assessment

Date: 2026-10-03. **All 215 measured settings-classpath files are accounted for at the top-level file scope; all 17 baseline advisory IDs remain reported.** This closes the earlier file identity gap, not advisory remediation or adoption readiness. Production remains Toolchain 0.12.2 with the Gradle bridge and compile/minimum/target SDK 36.

## Verified facts

This follow-up replays passing upstream run `ee4c6a7e32a1db3782ec81933a02522d`, original source snapshot `17c60686a9c1313150fec613dc9f4f30f2e8d4afe8fd1195322f7b708752fa01`, at HEAD `ba8270fabed862ae52a09e918e9803390d0fd8cb`. It adds attribution over retained compiler/delegated producers; it does not rerun compilation or claim native app/test execution. Its separate collection snapshot, configuration, source receipts and derivation hash appear in the [public evidence packet](evidence/2026-10-03-bundled-attribution.json).

| Measured files | Attribution | Count |
| --- | --- | ---: |
| Previously matched files | Unique verified baseline Maven artifact SHA-256 and byte-length references | 183 |
| Previously unassigned third-party files | Independent Maven Central artifact bytes match exactly | 9 |
| Previously unassigned Toolchain project files | Pinned distribution membership, embedded module metadata and registered versioned source declarations agree | 23 |
| Total | Distribution file bytes and settings-classpath membership independently verified | 215 |

The nine independent third-party matches are:

| Maven artifact | Version |
| --- | --- |
| `org.jetbrains:annotations` | 26.1.0 |
| `net.bytebuddy:byte-buddy` | 1.10.9 |
| `net.bytebuddy:byte-buddy-agent` | 1.10.9 |
| `org.jetbrains.kotlin:kotlin-compiler-embeddable` | 2.2.21 |
| `org.jetbrains.kotlin:kotlin-daemon-embeddable` | 2.2.21 |
| `org.jetbrains.kotlin:kotlin-gradle-plugin` | 2.2.10 |
| `org.jetbrains.kotlin:kotlin-reflect` | 2.3.20-RC2 |
| `org.jetbrains.kotlin:kotlin-script-runtime` | 2.2.21 |
| `org.jetbrains.kotlin:kotlin-stdlib` | 2.4.0 |

These are distribution/build-integration inputs. They are distinct from the executed Kotlin 2.4.20 application compiler and retained bridge tuple. In particular, the bundled Kotlin Gradle Plugin is the ordinary published 2.2.10 JAR. Changing its packaging from named Gradle resolution to a bundled file did not establish a version upgrade or remediation. The prior baseline had named variant resolution; this follow-up establishes exact reference artifact bytes without inferring a candidate Maven resolution or variant.

The 23 release-owned modules include the Android integration API/plugin, shared frontend/schema, parsers, events/telemetry and supporting libraries. Every filename, module path, embedded metadata digest and versioned module source pin is listed in [the reviewed configuration](../../maintenance-bundled-inputs.json). The [released layout implementation](https://github.com/JetBrains/kotlin-toolchain/blob/v0.13.0/build-sources/amper-distribution/src/lazyClasspaths.kt) explains copied/deduplicated JARs and classpath indices. These source correspondences are not reproducible-build attestations.

## Advisory result

| Lookup | Exact queries | Distinct full finding records |
| --- | ---: | ---: |
| Refreshed baseline | 576 | 17 |
| Earlier named-only candidate | 399 | 7 |
| Earlier baseline-byte-reference candidate | 538 | 16 |
| Fresh candidate plus independent reference artifacts | 547 | 17 |

The new lookup restores `GHSA-r937-wjx7-w2jp` for Kotlin Gradle Plugin 2.2.10. No baseline finding ID is removed and no new ID is added. Both Critical-classified Bouncy Castle findings remain reported. Reduced coordinate visibility explained the earlier apparent drop; the complete measured lookup supplies **no evidence of advisory remediation**. Full affected conditions and build-tool ownership still require the [existing advisory triage](direct-advisory-triage.md). Reported build-tool matches do not establish application exploitability.

The original partial attribution and advisory receipts remain historical. The new report records `measured_file_identities_accounted_for`, provider state `triage_required`, comparison `review_required`, and `remediation_verified: false`. Those states describe file accounting and provider review; they do not mark the candidate ready for adoption.

## Untested assumptions and remaining gates

Source-to-binary reproducibility, copied/shaded third-party code and complete Native/compiler-plugin/test-input coverage remain unproven. The project-owned files are not covered by invented Maven package queries. Existing uncollected delegated configurations remain outside the measured scope.

Before an adoption decision, review owner-supported remediation or documented mitigations for the retained findings, and present any residual risk explicitly. Complete real release-age admission, retained-bridge Xcode app/tests, minimum-OS runtime behavior, SDK 37 clean-clone/CI provisioning and relevant release/rollback validation. Toolchain 0.13.0 reaches the configured seven-day threshold on **2026-10-08T06:36:56Z**. Compilation success and file identity do not themselves prove API-36 runtime safety.

SwiftPM remains [documented and unexecuted](toolchain-swiftpm-assessment.md); [bridge retirement](bridge-retirement-path.md) retains its independent gates. No dependency adoption, bridge removal, default change, schedule, commit or push follows from this assessment.

## Verification and cleanup

The producer verifies caller source/modes, HEAD and staged-entry identity through collection. Owned temporary binary downloads were deleted before successful replay; original build/control evidence and public-safe attribution/provider receipts remain. An initial transport/identity refusal is retained separately from later verified collection. Repository checks cover changed artifact bytes, incorrect mappings/endpoints, source/metadata drift, missing or duplicate inputs, altered proof/provider bindings and caller drift.

Validation passed 246 repository contracts, the pinned static gates and all 20 strict OpenSpec items. Exploratory binary copies were also removed; retained receipts and final report replay require no downloaded binary workspace. Native application, minimum-OS runtime and hosted execution were not added by this data-attribution follow-up.

Use the [repeatable command guide](bundled-input-attribution.md) to reproduce or refresh this assessment. Existing passing upstream build evidence remains in [the original assessment](upstream-toolchain-assessment.md).

The later [adoption-gate assessment](toolchain-adoption-assessment.md) adds retained-bridge Xcode tests/builds, minimum-major iOS and API 36 runtime evidence, unsigned packaging and fresh version-bound compiler-plugin joins. Its expanded 549-query review still retains all 17 IDs; release age, risk decisions, cold onboarding/hosted and signed delivery remain open.
