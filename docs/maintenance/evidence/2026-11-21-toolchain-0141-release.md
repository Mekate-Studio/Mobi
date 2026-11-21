# Toolchain 0.14.1 unsigned Release qualification — 2026-11-21

**Local unsigned Release product checks passed; 0.14.1 is not adopted.** This
follows merged [#129](https://github.com/Mekate-Studio/Mobi/pull/129), source
`e62aee8fa45667dde27d66e740f895244e3459c9`. The app stays on 0.13.0. The
[compact receipt](2026-11-21-toolchain-0141-release.json) binds the actual products,
source/run identities, comparison tools, retained raw evidence and cleanup.

The existing [0.14.1 qualification exception](2026-11-21-toolchain-0141-qualification.md)
applies. Selection stays `experimental`, `age_blocked`, and
`adoption_authorized: false`; normal eligibility remains November 26 at
17:46:59 UTC. Kotlin/exporter 2.5.0-RC, Metro 1.5.0, Swift package locks, app
sources and platform floors stayed fixed. Both phases use the reviewed explicit
Temurin host JDK selection from the [native CI review](2026-11-21-native-ci-jdk.md).
No release lane, app pin, producer implementation or optimization setting changes.

## Unsigned iOS simulator Release

The existing guarded snapshot runner manually selected `ios-build-release` on
0.13.0, then on 0.14.1. This is an explicit Release selection, not execution of
every job in the automatically classified staged plan. Each snapshot was cleaned
before the next phase. Only the candidate's reviewed wrapper pair changed in
this isolated checkout; exact original wrapper/index restoration was verified
before the Android run. The final documentation commit uses its normal gate.

| Inspected product fact | Both versions |
| --- | --- |
| Bundle ID / minimum | `studio.mekate.mobi` / iOS 26.0 |
| Mach-O architecture / platform / SDK | ARM64 / simulator (7) / 27.2 |
| Generated modules / project KLib inputs | Seven / six |
| Native optimization / producer mode flag | `-opt` / Swift-export flag present |
| `MobiTestSupport` producer input | Absent |
| Defined Kotlin-runtime-symbol-bearing images | One: `ios-app` |
| Native icons / asset catalog | 42 entries / matching catalog SHA-256 |
| Xcode signing flags / signing files and profile | Disabled / absent |

The seven modules are `ExportedKotlinPackages`, `KotlinRuntimeSupport`,
`KotlinCoroutineSupport`, `MobiCore`, `MobiHome`, `MobiNearby` and `MobiIOS`.
Actual project records must match the selected wrapper and compiler. Test-support
exclusion applies to producer inputs: Toolchain may still compile native test
tasks that are not packaged into this Release app.

The direct Swift-export mode constant remains **unobserved in the optimized
image** because its symbol is absent on both versions. The checked producer flag
and single runtime-symbol image are separate observations. No symbol-retention
flag, optimization change or inspection shim was added to preserve a Debug
probe. Re-evaluate supported optimized-product observability on compiler/exporter
updates; this result does not retire IOS-10 or other active interop mechanisms.

Both retained Xcode/forwarded producer outputs contain **43 warning lines across
16 distinct texts**, with matching text sets. Existing generated/runtime/package
warning categories remain under the [warning follow-ups](../compiler-warning-follow-ups.md).
This is that captured output's population, not a repository-wide diagnostic
inventory or a warning-debt closure. Raw logs and the comparison remain ignored.

## Unsigned Android Release APK and current AAB helper

Baseline-first run `4e86e53e1ba9a959ca508d364c3d4e85` used the existing executor,
source guards, SDK seed and owned-resource lifecycle. Each private copy applied
the same temporary `settings.android.signing.enabled=false` overlay; original
module bytes were restored before the phase completed. No production signing
credentials were supplied. The sole version change was the reviewed wrapper pair.

Each phase ran the existing logging wrapper for
`build -m android-app -p android -v release`, then the **current**
`scripts/ci/build_android_aab.sh`. Its published
`build/releases/android/android-app-release.aab` exactly matched Toolchain's final
artifact. The [0.14.1 Android guide](https://github.com/JetBrains/kotlin-toolchain/blob/f53674bce744f0b5e9ff235110dcc1d565d2c114/docs/src/user-guide/product-types/android-app.md#packaging)
still documents the command and temporary final path. The helper's existing
supported-artifact-reporting replacement condition remains; no Gradle cache-path
fallback is added. This is unsigned helper qualification, not the separate
synthetically signed release-candidate lane or store publication.

| Inspected product fact | Both versions |
| --- | --- |
| APK identity / min / target / compile API | `studio.mekate.mobi` / 36 / 36 / 37 |
| APK debuggable / signature | Absent / unsigned verifier refuses |
| APK bytes | Identical SHA-256; 110 matching entry payloads |
| AAB structure / signature | Required configuration, manifest/resource protobuf and DEX entries; unsigned |
| AAB helper publication / R8 mapping | Matches final artifact / captured |

The AAB archive hashes differ. Entry comparison found **114 matching payloads**
and two differing protobuf entries: `base/resources.pb` and the library dependency
inventory. The inspection-only Bundletool 1.18.3 JAR was verified against its
[publisher asset digest](https://github.com/google/bundletool/releases/tag/1.18.3).
Its public protobuf classes decode both bundles: resource messages match after
clearing only `source_pool`; dependency messages match after replacing only six
exact owned project prefixes. All other fields, digests, references, repositories
and unknown fields remain; each inventory has 113 records. The produced AABs were
not rewritten. This is scoped content agreement, not whole-bundle reproducibility,
runtime execution or newly attributed release-graph advisory evidence.

## Retention, cleanup and remaining qualification

Full logs, product/entry identities, decoder output and one-off inspection code
remain in ignored storage; bulk inventories and binaries are not committed.
Existing recovery verified the Android processes were quiescent before removing
only the two owned workspaces. Verified owned retained product/tool/binary copies
were then removed after evidence capture. Original wrappers, index and signing
inputs were restored; no user cache was cleared.

The next focused check is 0.14.1 warm manifest/resource edits and reverts.
Version-bound cold/relocated delivery, the signed fixture lane, optimized runtime
execution, device/signed delivery and retained dependency/attribution/transform
gaps remain separate. Release age and a risk/adoption decision still apply;
successful packaging does not accept advisory risk or lift publication holds.
The final PR comment records normal staged and hosted documentation-only results;
the native Release products above were qualified locally, and native tests were
not rerun by this increment.
