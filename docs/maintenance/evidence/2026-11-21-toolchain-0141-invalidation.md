# Toolchain 0.14.1 Android warm-build check — 2026-11-21

**Result: 0.14.1 applies and reverts the checked manifest and string edits;
0.13.0 leaves stale APK content in the same fresh sequence.** This confirms an
Android development benefit on the current app source. The app stays on 0.13.0;
dependency risk, adoption and interop retirement remain separate decisions.

Base: `aef46d5cbfa6215494bcaae48f9e7286f3ffb072`, merged PR #130. The
[0.14.1-only early-qualification exception](2026-11-21-toolchain-0141-qualification.md)
covers this isolated check. The receipt preserves `age_blocked` and normal
eligibility of `2026-11-26T17:46:59Z`; passing does not waive dependency risk.

## Packaged observations

Run `97ee1f085b36b78e034850885d873788` compared baseline 0.13.0 with candidate
0.14.1 using the existing Android Debug validation job. Both used the same
Kotlin/exporter 2.5.0-RC, Metro 1.5.0, platform floors and application identity
`studio.mekate.mobi`. Each phase had private source, SDK, home, build and cache
roots. Only the reviewed candidate wrapper pair differed between phases.

Before the first build, both copies received the same temporary module-level
`android-app/res/values/mobi_invalidation_probe.xml`, containing string
`mobi_invalidation_probe` with value `Mobi resource baseline`. The manifest edit
changed only `android:label="Mobi"` to `"Mobi manifest probe"`; the resource edit
changed only the fixture value to `Mobi resource probe`, with the manifest restored.
The unchanged stage did not rewrite source. Build/cache locations remained fixed
through all six stages, with no clean between them.

| Stage | Expected APK label / string | 0.13.0 actual | 0.14.1 actual |
| --- | --- | --- | --- |
| Initial | Mobi / baseline | Mobi / baseline | Mobi / baseline |
| Unchanged warm | Mobi / baseline | Mobi / baseline | Mobi / baseline |
| Manifest edit | manifest probe / baseline | manifest probe / baseline | manifest probe / baseline |
| Manifest revert | Mobi / baseline | **manifest probe / baseline** | Mobi / baseline |
| Resource edit | Mobi / resource probe | **manifest probe / baseline** | Mobi / resource probe |
| Resource revert | Mobi / baseline | **manifest probe / baseline** | Mobi / baseline |

The table abbreviates the full probe strings above. All 12 build commands exited
successfully. The baseline manifest revert left the edited label; the resource
edit was absent from its APK. At resource revert, the baseline string was already
unchanged because the edit never reached the package, and the stale label remained.
This is one ordered sequence per version, not an isolated clean resource test or
a claim about every baseline edit.

Installed AAPT2 37.0.0 inspected every actual APK's identity, label and resource
table. Identical copied APKs were deduplicated by SHA-256; distinct competing app
products would refuse inspection. Compiled `AndroidManifest.xml` and
`resources.arsc` were hashed separately. On 0.14.1, the manifest edit changed only
the manifest entry and the string edit changed only the resource-table entry;
**both entries matched their initial hashes after each revert and the unchanged
build**. This verifies packaged output without asserting whole-APK reproducibility
or equality between Toolchain versions.

## Upstream relationship and update checks

The pinned [0.14.1 Android build task](https://github.com/JetBrains/kotlin-toolchain/blob/f53674bce744f0b5e9ff235110dcc1d565d2c114/sources/amper-cli/src/org/jetbrains/amper/tasks/android/AndroidBuildTask.kt)
registers `androidFilesForPackaging(...)` as additional inputs. Its
[helper](https://github.com/JetBrains/kotlin-toolchain/blob/f53674bce744f0b5e9ff235110dcc1d565d2c114/sources/amper-cli/src/org/jetbrains/amper/tasks/android/inputFiles.kt)
includes manifest, resource, asset and JNI paths, plus Release signing and ProGuard
inputs. The [0.13.0 task](https://github.com/JetBrains/kotlin-toolchain/blob/v0.13.0/sources/amper-cli/src/org/jetbrains/amper/tasks/android/AndroidBuildTask.kt)
lacks that override. The measured difference is consistent with those inputs;
this full-version comparison does not isolate a single upstream commit.
The fixture uses the [documented module-level resource layout](https://github.com/JetBrains/kotlin-toolchain/blob/f53674bce744f0b5e9ff235110dcc1d565d2c114/docs/includes/module-layouts/android-app.md).

This is an upstream build benefit, with no app workaround, dependency override,
forced-clean policy or new maintained runner added. Future Toolchain reviews
should retain packaged edit/revert checks when assessing input tracking. Assets,
JNI and Release signing/ProGuard invalidation were not exercised. The existing
synthetically signed release-candidate lane still needs a 0.14.1 check; this Debug
sequence does not qualify the AAB helper's warm or signing behavior.

## Evidence and limits

The [compact receipt](2026-11-21-toolchain-0141-invalidation.json) binds source,
index, implementation, plan, policy, selection, inspector, all 12 observations and
the per-phase raw evidence hashes. The raw executor's `checks_passed` means the
observation completed; baseline failed packaged expectations remain explicit.
Full build and inspection logs remain in ignored local storage, checked against
their evidence hashes. No bulk inventories or binaries are committed.

Both phases restored authored inputs and removed the fixture. Existing ownership
checks verified quiescent resources before cleaning only the two disposable
workspaces, retaining logs and receipts. Native tests were not rerun by this
observation. Cold/relocated delivery, runtime/device and credentialed signing
remain separate from this check and the earlier
[unsigned Release products](2026-11-21-toolchain-0141-release.md).
The [dependency findings and attribution limits](2026-11-21-toolchain-0141-dependencies.md),
[delegated-owner findings and Gradle 9.8 observer gap](2026-11-21-toolchain-0141-delegated.md),
and [warning debt](../compiler-warning-follow-ups.md) remain open.
