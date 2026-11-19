# Toolchain 0.14.0 Android warm-build check — 2026-11-19

**Result: 0.14.0 packages the checked edits and restores their original values;
0.13.0 leaves stale APK content in the same sequence.** This is a measured benefit
for Mobi's Android Debug path. The selected app stays on 0.13.0; dependency risk
and adoption remain separate decisions.

Base: `d8b12d2898736d5f9ad6df3bf1f74c0f7dc5a938`, merged PR #116. The existing
[release-specific age exception](2026-11-18-toolchain-014-qualification.md)
covers this isolated 0.14.0 qualification. The receipt retains the real
`age_blocked` state and normal eligibility of `2026-11-23T14:49:08Z`.

## Concrete observation

Run `ccda05bffe8a7b3b590d221a2f51fe79` completed both version sequences.
Each used its own source/build/cache directories, the existing Android Debug
validation job and the same fixed Kotlin/exporter 2.5.0-RC, Metro 1.5.0 and platform
floors. Only the candidate's reviewed wrapper pair differed between phases.

A temporary string resource existed before the first build in both copies:

```xml
<!-- android-app/res/values/mobi_invalidation_probe.xml -->
<resources>
    <string name="mobi_invalidation_probe">Mobi resource baseline</string>
</resources>
```

The manifest edit changed only `android:label="Mobi"` to `"Mobi manifest probe"`.
The resource edit independently changed the string to `"Mobi resource probe"`,
with the manifest source restored. Each sequence used six builds in order, without
cleaning or changing its build/cache locations. The unchanged stage did not rewrite
source files; each edit changed only its intended file's bytes.

| Stage | Expected APK label / resource | 0.13.0 actual | 0.14.0 actual |
| --- | --- | --- | --- |
| Initial build | Mobi / baseline | Mobi / baseline | Mobi / baseline |
| Unchanged warm build | Mobi / baseline | Mobi / baseline | Mobi / baseline |
| Manifest edit | manifest probe / baseline | manifest probe / baseline | manifest probe / baseline |
| Manifest revert | Mobi / baseline | **manifest probe / baseline** | Mobi / baseline |
| Resource edit | Mobi / resource probe | **manifest probe / baseline** | Mobi / resource probe |
| Resource revert | Mobi / baseline | **manifest probe / baseline** | Mobi / baseline |

The table abbreviates the two probe strings above. Every build command succeeded.
On 0.13.0, the manifest revert left the edited label, and the later resource edit
was absent. The resource-revert stage still had the stale label; its string value
was baseline because the resource edit had never reached that APK. These are
observations from one ordered warm sequence per version, not isolated clean
resource runs or a claim that every 0.13.0 edit fails.

Installed `aapt2` 37.0.0 read the actual APK's application identity/label and resource
table after every build. The inspector required `studio.mekate.mobi`; identical
copied APKs were deduplicated by content, and distinct competing app products
would refuse inspection. Compiled `AndroidManifest.xml` and `resources.arsc`
entries were independently hashed. On 0.14.0, **both entry identities return to
the initial build after each revert**. This verifies packaged output rather than
relying on source timestamps or a successful build message. It does not assert
whole-APK reproducibility or equality between versions.

## Upstream relationship and resource-layout follow-up

The [0.14.0 Android build task](https://github.com/JetBrains/kotlin-toolchain/blob/v0.14.0/sources/amper-cli/src/org/jetbrains/amper/tasks/android/AndroidBuildTask.kt)
adds `androidFilesForPackaging(...)` as additional inputs. The
[helper](https://github.com/JetBrains/kotlin-toolchain/blob/v0.14.0/sources/amper-cli/src/org/jetbrains/amper/tasks/android/inputFiles.kt)
includes manifest, resource, asset and JNI paths, plus release-only signing and
ProGuard inputs. The corresponding
[0.13.0 task](https://github.com/JetBrains/kotlin-toolchain/blob/v0.13.0/sources/amper-cli/src/org/jetbrains/amper/tasks/android/AndroidBuildTask.kt)
lacks that override. The observed difference is consistent with this input-tracking
change; the comparison does not isolate one upstream commit from the full release.
Assets, JNI libraries, release signing and ProGuard invalidation were not exercised.

The initial baseline inspection found that Mobi's existing
`android-app/src/res/values/strings.xml` was not packaged. Both
[0.13.0](https://github.com/JetBrains/kotlin-toolchain/blob/v0.13.0/docs/includes/module-layouts/android-app.md)
and [0.14.0](https://github.com/JetBrains/kotlin-toolchain/blob/v0.14.0/docs/includes/module-layouts/android-app.md)
document module-level `res/`, so the completed pair used the temporary fixture
there. The existing starter file remains unchanged. **Follow-up:** remove the
unused starter resource or deliberately move and use it through the documented
layout. That cleanup is separate from qualifying the version change.

## Evidence and limits

The [compact receipt](2026-11-19-toolchain-014-invalidation.json) records the source
and run binding, fixture identity, all 12 packaged observations, output hashes,
inspection tool identity, retained unsuccessful attempts and owned cleanup.
`checks_passed` in the raw executor result means the observation completed; the
baseline's stale outputs remain explicit failed value expectations in the receipt.

One setup refusal occurred before building because the one-off script lacked its
YAML import. A subsequent baseline build passed but could not qualify the existing
unpackaged `src/res` string. Both records were retained and their owned work cleaned
before the completed pair. All temporary source changes were restored or removed;
the completed pair's workspaces were verified quiescent and cleaned through the
existing ownership protocol. Full command/inspection logs stay in ignored local
assessment storage, bound by the per-phase evidence hashes. No bulk inventories,
maintained runner, dependency override or private API adapter is added.

This closes the checked manifest/string warm-invalidation case. Unsigned Release,
cold/relocated delivery and broader packaging inputs remain open. The
[owner-specific advisory findings and attribution/observer gaps](2026-11-18-toolchain-014-dependencies.md)
also remain. Passing this check does not accept those risks, change signing or
publication holds, switch the app's Toolchain or retire an interop mechanism.
