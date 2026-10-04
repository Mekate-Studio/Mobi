# Toolchain 0.13.0 upstream remediation assessment

Date: 2026-10-03. Decision: **build-input rehearsal passes; advisory remediation and adoption remain open**. Production remains Toolchain 0.12.2 with the Gradle bridge. No application dependency adoption, bridge removal, release-default change, commit or push occurred. The user separately authorized Xcode first-launch setup; installation succeeded and readiness subsequently passed.

Subsequent [native, minimum-runtime, unsigned packaging and fresh plugin validation](toolchain-adoption-assessment.md) passes its bounded local gates while adoption remains deferred.

Subsequent [bundled-file attribution](bundled-input-assessment.md) accounts for the 32 files left unassigned below and restores the KAPT finding. All 17 baseline IDs remain reported; the original rehearsal and its narrower lookup remain historical evidence.

The final owned pair is `ee4c6a7e32a1db3782ec81933a02522d`, source snapshot `17c60686a9c1313150fec613dc9f4f30f2e8d4afe8fd1195322f7b708752fa01`, at HEAD `ba8270fabed862ae52a09e918e9803390d0fd8cb`. This is working-snapshot evidence, not clean-commit or hosted-CI validation. The candidate was explicitly experimental: [0.13.0](https://github.com/JetBrains/kotlin-toolchain/releases/tag/v0.13.0) becomes seven-day age-eligible on **2026-10-08T06:36:56Z**.

## Verified execution

| Measured input or check | Baseline | Candidate |
| --- | --- | --- |
| Toolchain | 0.12.2 | 0.13.0 |
| Executed Kotlin compiler | 2.4.10 | 2.4.20 |
| Effective Toolchain Compose version | 1.11.1 | 1.12.1 |
| Android compile SDK | 36.0 | 37.0, isolated patch |
| Android minimum / target SDK | 36 / 36 | 36 / 36 |
| Android host tests / debug APK | 38 pass / produced | 38 pass / produced |
| Five shared libraries, ARM device and simulator KLIBs | Compile passes | Compile passes |
| Successful compiler invocations / selected plugin files | 37 / 2 | 37 / 2 |
| Delegated Android builds / configuration entries | 2 / 1,828 | 2 / 1,828 |
| Uncollected delegated configurations | 612 | 612 |
| Module main/test compile/runtime platform roots | 92 | 92 |

The production bridge tuple stays Kotlin 2.4.20, Metro 1.4.5, SKIE 0.10.15 and Compose 1.9.0. Those bridge declarations are separate from the Toolchain compiler/Compose defaults above. This profile retains bridge configuration; it does not execute the Xcode app/test targets or demonstrate bridge removal. Compiler files remain measured fingerprints, without transferring the prior 0.12.2 plugin-coordinate attribution to the new compiler automatically.

The wrapper-only attempt `0c62f4e800bb332b9e6f11ebcd8a348d` passed its baseline and candidate Android tests, then failed candidate APK assembly. Selected Compose 1.12.1 AAR metadata requires compile SDK 37; Mobi declares 36. Its original runner outcome remains infrastructure-inconclusive because the classifier did not recognize this diagnostic. The specific AAR diagnostic now classifies as a build incompatibility. A fresh `--compile-sdk 37` patch changes only the candidate application compile SDK; it preserves minimum/target SDK, identity and caller files.

The patched attempt `8641a08dac9d8e5210371bdce7e09ada` passed both Android tests/APK, then stopped before candidate Native compilation. The actual host license check passed, but Xcode first-launch status exited 69. The [released readiness task](https://github.com/JetBrains/kotlin-toolchain/blob/v0.13.0/sources/amper-cli/src/org/jetbrains/amper/tasks/ios/XcodeEnvironmentTask.kt) requires that check. Authorized host setup cleared it; the final fresh pair above passed. A read-only adapter preflight now refuses another cold pair when readiness is missing. It never performs setup or accepts a license. Both earlier outcomes and logs remain intact.

## Advisory comparison and coverage failure

| Lookup | Exact queries | Full finding records | Meaning |
| --- | ---: | ---: | --- |
| Fresh baseline module + delegated named Maven inputs | 576 | 17 | Triage required |
| Initial fresh candidate named inputs | 399 | 7 | Reduced coordinate visibility; no remediation conclusion |
| Candidate named inputs + unique baseline artifact byte references | 538 | 16 | Triage required; attribution incomplete |

Toolchain 0.13.0 [passes distribution JARs to its Android integration](https://github.com/JetBrains/kotlin-toolchain/blob/v0.13.0/sources/amper-cli/src/org/jetbrains/amper/tasks/android/AndroidDelegatedGradleTask.kt). Captured generated settings use file dependencies. Gradle exposes 215 unique settings-classpath files as opaque inputs. Their fingerprints are collected, but they no longer carry the baseline's Maven component identities. The named delegated pair count drops from 273 to 83. The initial seven findings therefore do not establish that ten findings were fixed.

Repository-owned report derivation matches 183 bundled files to a unique baseline Maven component by **SHA-256 and byte length**. It expands candidate lookup with those reference identities, without inventing candidate Maven resolution, variants or coordinates from filenames. Changed bytes or ambiguous component references remain unassigned. The derivation binds both verified producer sets and its own code hash; it runs over retained evidence after compilation and does not rewrite the original result.

Fresh expanded lookup reports 16 of the original IDs, including the two Critical-classified Bouncy Castle findings. The KAPT ID `GHSA-r937-wjx7-w2jp` is absent from that lookup, but the bundled main Kotlin Gradle Plugin file is among **32 unassigned files**. Its absence is not a verified fix. New or differently packaged files, including Toolchain-owned modules, remain outside that attribution. The report records `attribution_incomplete` and `remediation_verified: false`; provider completeness is not dependency-surface completeness or executed exploitability evidence. Existing [condition and owner triage](direct-advisory-triage.md) remains applicable to the measured unchanged artifacts.

## Untested assumptions and blockers

Initial SwiftPM support has a separate [source-bound assessment](toolchain-swiftpm-assessment.md). Its documented direction imports Objective-C-visible Swift-package APIs into Kotlin. No SwiftPM package execution, Kotlin framework distribution, TCA/macro migration or Xcode ownership parity was measured here.

At this historical build-input stage, 32 bundled files and all Xcode/runtime/packaging gates were still open. The [bundled attribution follow-up](bundled-input-assessment.md) accounts for those files; the [adoption-gate follow-up](toolchain-adoption-assessment.md) supplies fresh Xcode app/tests, API 36 install/launch, unsigned packaging and selected plugin attribution. Release age, advisory owner/condition decisions, clean-clone/hosted SDK 37 provisioning, exact iOS 26.0 runtime, physical devices and signed delivery remain open. General shaded-code and Native bundle/test-input attribution remain unproven.

Bridge retirement still requires the independent [retirement gates](bridge-retirement-path.md). Neither this build-input profile nor the SwiftPM announcement closes them. Future review should present the concrete compiler/Compose, SDK provisioning and native validation implications before requesting adoption.

## Preservation and verification

The executor verified caller source/modes, HEAD and index through execution. A post-execution comparison confirms production inputs remain unchanged; only the five documented report-derivation/test files changed before publication. The original execution snapshot and later derivation hash are distinguished in the [public receipt](evidence/2026-10-03-upstream-remediation.json).

All three attempts recovered to quiescence and completed explicit owned cleanup. Control producers, failure logs and full provider receipts remain; final report replay passed after disposable deletion. Validation passed 240 repository contracts, existing pinned static gates and 19 strict OpenSpec items. See the [repeatable command guide](upstream-toolchain-remediation.md).
