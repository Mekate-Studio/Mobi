# Toolchain 0.13.0 retained-bridge adoption assessment

Date: 2026-10-03. Decision: **local retained-bridge functional evidence advances; adoption remains deferred**. Production remains Toolchain 0.12.2, Android compile/minimum/target SDK 36, minimum iOS 26.0 and the Gradle bridge. No dependency adoption, bridge removal, release-default change, schedule, commit, push or publishing occurred.

This follows the [completed bundled attribution](bundled-input-assessment.md). Every run captures a working snapshot at HEAD `ba8270fabed862ae52a09e918e9803390d0fd8cb`; snapshots differ as maintenance code was added. The [public receipt](evidence/2026-10-03-toolchain-adoption-gates.json) records each source, tool, patch, producer and output identity. These are local working-snapshot results, not clean-commit or hosted candidate validation. The [manual command guide](toolchain-adoption-gates.md) explains execution and recovery.

## Verified facts

| Gate | Baseline 0.12.2 | Candidate 0.13.0 | Evidence boundary |
| --- | --- | --- | --- |
| Android host tests / debug APK | 38 tests pass / produced | 38 tests pass / produced | Repository jobs; retained bridge |
| Xcode native tests / Debug app | Same 12 original cases pass / produced | Same 12 original cases pass / produced | Home and NearbyVehicleMap; macro validation enabled |
| Minimum-major iOS simulator | Owned iOS 26.5 | Owned iOS 26.5 | Actual runtime is later than exact minimum 26.0 |
| Android minimum-runtime smoke | API 36 install and launch pass | API 36 install and launch pass | Mobi UI visible; bounded crash buffer has no fatal entry |
| Android release APK / AAB | Both produced | Both produced | Synthetic signing fixture; no Play delivery |
| Optimized iOS simulator app | Release build passes | Release build passes | Unsigned ARM simulator build; no runtime execution |
| iOS device archive | Archive passes | Archive passes | Unsigned ARM64 device product; no execution/export/upload |
| App deployment metadata | Minimum iOS 26.0 | Minimum iOS 26.0 | Product Info.plist bytes verified before cleanup |
| Candidate SDK provisioning | Host SDK copied | Missing private API 37/tool packages downloaded and installed | Host accepted licenses copied; empty-host onboarding unproven |

Native run `2921588f6b5ecf1c3223fab649486952` executes framework compile/link and the existing Android/Xcode jobs. Android packaging run `dc70801fd0e15391cd68b9eb3500d531`, unsigned device archive run `07ff73c082fb97abad306ff735d867da` and Release simulator run `063f4a86089fd39bb1470a4ee95e182b` provide separate bounded packaging pairs. Each passed pair verifies original source preservation. Artifact fingerprints and selected ARM architecture/minimum-OS metadata are retained. Packaging does not execute native tests or device code.

Candidate compiler/Compose defaults are Kotlin 2.4.20 and Compose 1.12.1, compared with Toolchain baseline 2.4.10 and 1.11.1. The reviewed candidate patch raises only application compile SDK to 37. Android minimum/target remain 36; package inspection on the emulator confirms those installed declarations. The bridge tuple remains Kotlin 2.4.20, Metro 1.4.5, SKIE 0.10.15 and Compose 1.9.0, with existing Swift sealed-state adapters and Xcode targets. The candidate's Android/KLIB compiler differs from the separate retained Gradle compiler stack.

Runtime run `74cdc3706063a1b0be91281b81d9b530` installs the exact debug APK fingerprints from the native pair. Both launch waits report `Status: ok` and the UI contains Mobi's package. It uses an owned API 36 ARM image, private AVD/cache/keys and a foreground ADB server on a nondefault port. Explicit permission grants and synthetic coordinates are test fixtures; this does not verify permission UI or broader feature correctness. The executed scratch helper hashes are bound in the receipt. The repository-owned guarded controller added afterward is syntax-checked, not credited with that earlier end-to-end execution; it requires a fresh source-matching native producer before reuse.

Fresh plugin resolver run `f0d6207beefc5d95faa0793e1a9a5a4e` binds retained upstream compiler run `ee4c6a7e32a1db3782ec81933a02522d`. Both independent resolver phases join all 37 retained compiler invocations to their selected artifact sets by SHA-256 and byte length. Baseline Compose compiler 2.4.10 and candidate 2.4.20 have distinct measured fingerprints; Metro 1.4.5 matches in both. The candidate [mapping](https://raw.githubusercontent.com/JetBrains/kotlin-toolchain/v0.13.0/sources/frontend/schema/src/org/jetbrains/amper/frontend/kotlin/CompilerPluginConfig.kt) and [JVM runtime/classpath filter](https://raw.githubusercontent.com/JetBrains/kotlin-toolchain/v0.13.0/sources/amper-cli/src/org/jetbrains/amper/compilation/KotlinArtifactsDownloader.kt) come from separately pinned 0.13.0 primary sources. No compilation was rerun by this resolver. Historical 0.12.2 attribution still replays. Shaded code and unmeasured native test/compiler inputs remain outside this bounded join.

The resolver incorporates the verified bundled-attribution queries and its newly attributed candidate plugin inputs. Its fresh lookup covers **549 exact Maven pairs** and retains the same 17 finding IDs. Neither attributed candidate plugin adds a finding. Provider collection returned `triage_required` (exit 2), preserving the risk decision; this is not a transport failure.

A fresh expanded bundled review still covers 547 exact Maven pairs and reports **all 17 baseline advisory IDs**. No finding was removed by verified remediation. Two Critical-classified Bouncy Castle findings remain. The affected bundled Kotlin Gradle Plugin remains 2.2.10: upgrading the Toolchain compiler to 2.4.20 does not prove that the separate KAPT build-tool finding was fixed. See [condition and owner triage](direct-advisory-triage.md) and the pinned attribution receipt. Passing tests, private caches and build-tool ownership do not establish vulnerable-function absence, application exploitability or a waiver.

The subsequent [condition and mitigation review](advisory-mitigation-review.md)
reproduces both critical BC conditions in byte-verified 1.79 library fixtures;
an independent 1.85 control corrects those bounded conditions. Jetifier's actual
XML helper expands an owned canary, including with a 2.0.6.1 JDOM control;
explicit entity hardening prevents fixture expansion. Twenty-eight selected
owner artifacts join identical candidate bytes. This narrows consumer behavior
without establishing application reachability, installing a mitigation or
clearing any of the 17 findings. Release-age maturity alone is insufficient.

## Preserved failures and recovery

The combined packaging run `066cdd4fbeab3c4aab7c9e68ae05e1a1` completed baseline packaging but was deliberately interrupted during the candidate to avoid exceeding the existing overall budget. Its outcome remains interrupted/inconclusive. New separate Android, iOS release and iOS archive pairs supply their own evidence; they do not rewrite it or raise execution limits.

The API 36 smoke required three separately preserved inconclusive attempts: `64352b4b026ddd39a3cf6be42547aa08` used an unsupported ADB listen-address form; `b31e75033e593c7466d085272f0f2232` encountered the permission-controller UI; `827413b9636e8d346ae27966d412fbfd` had a candidate launch timeout during concurrent packaging. Concurrency is observed context, not a proven cause. The successful fresh retry uses supported private ADB listening, explicit permission/location fixtures and bounded UI/crash observation. No failed attempt supplies a passing cell.

All completed runs recovered to quiescence and discarded disposable workspaces. Control receipts, originals and failure logs remain. Report/hash replay passes after deletion. Native recovery now also recognizes detached private compiler and Xcode children, verifies process identity and executable fingerprints before signaling, and refuses changed identities. This is scoped ownership proof, not a universal host-process cleaner.

A native-resource contract initially failed because macOS killed a copied `/bin/sleep` fixture before observation. A small compiled fixture corrected the test. Final validation passes 254 repository contracts, existing pinned static analyzers, and 21 strict OpenSpec items. The PATH failure caused by an incompatible inherited Git was preserved and rerun with system Git; it is not an application failure.

## Blockers and untested assumptions

| Gate | Current state | What closes it |
| --- | --- | --- |
| Release age | Age-blocked experimental evidence | Refresh release/provider evidence after 2026-10-08T06:36:56Z; no new schedule |
| Advisory decision | Triage required; 17 findings retained, including Critical matches | Owner-supported remediation or concrete condition/mitigation evidence and an explicit policy-compliant risk decision; no automatic exception |
| Clean clone / hosted SDK 37 | Private provisioning passed with existing licenses | Fresh public onboarding and cold hosted candidate checks with documented SDK/license prerequisites |
| Exact minimum iOS 26.0 / physical devices | Not executed; host offers 26.5 for minimum-major proof | Available exact-floor runtime or explicit documented limit, plus required physical-device checks |
| Full Android runtime / permission flow | Bounded install/launch only | Relevant feature/instrumentation and permission-flow checks at the supported minimum |
| Signed release delivery | Unsigned iOS archive and fixture-signed Android package only | Separately authorized signing/export/delivery validation; no credential assumptions |
| Shaded code / Native bundle and test compiler inputs | Not completely attributed | Separate producer-specific inventories and attribution; no inference from the two selected plugin files |
| Adoption integration | Reviewed candidate mapping exists; only rehearsal patch preview prepared | Reviewed wrapper/maintenance/compatibility baselines, provisioning docs/jobs, final age/risk review and source-bound rollback checks |

The [unapplied patch preview](evidence/2026-10-03-toolchain-rehearsal-preview.patch) changes only `kotlin`, `kotlin.bat` and application compile SDK. Temporary A→B→A verification checks byte preimages/postimages and file modes. It is explicitly a **rehearsal patch preview, not a complete adoption packet**; production inputs remain unchanged. A future approval must explain compiler/Compose changes, compile SDK provisioning, retained minimum/target support, residual advisory risk and all integration/rollback changes.

Bridge retirement remains **deferred**. These profiles intentionally retain the bridge and original Swift shell; they do not prove a bridge-unavailable direct path. Toolchain 0.13.0 initial SwiftPM support remains [documented but unexecuted](toolchain-swiftpm-assessment.md). The independent [retirement capability gates](bridge-retirement-path.md) continue to govern direct consumption, adapters, plugins, native tests, onboarding and release parity.

The later [Jetifier condition and owner-remediation assessment](jetifier-condition-assessment.md)
adds a fresh build-input pair with effective disabled options and no observed
Jetifier actions. Its source differs from these native/packaging receipts.
Security policy and adoption blockers remain open; neither the bounded disabled
condition nor newer AGP declarations constitute a complete remediation.
