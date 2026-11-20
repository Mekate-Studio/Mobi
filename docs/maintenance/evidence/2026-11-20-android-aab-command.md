# Android AAB packaging command — 2026-11-20

**Result: replace the helper's manual Gradle invocation with the documented
`kotlin package -m android-app` command.** The existing release-candidate lane
and warm bundle checks pass on both Toolchain 0.13.0 and 0.14.0. This closes the
helper-integration follow-up from the [unsigned Release assessment](2026-11-19-toolchain-014-release.md).
The app remains on 0.13.0; candidate adoption and dependency-risk decisions remain open.

Base: `a233cb809a16a651a098a1fb54400e0dee536e77` (PR #118). Both disposable
copies contain this PR's helper, Kotlin/exporter 2.5.0-RC, Metro 1.5.0 and existing
platform floors. Only the candidate's reviewed wrapper pair differs. The
[approved release-specific age exception](2026-11-18-toolchain-014-qualification.md)
covers qualification; the receipt preserves `age_blocked` and normal eligibility.

## Change and review points

The helper no longer locates Gradle from execution-history/cache directories or
invokes `bundleRelease` itself. Toolchain continues to own delegated Android
Gradle/AGP bootstrap. Fastlane still builds the Release APK and calls the same
helper; upload lanes still find `build/releases/android/android-app-release.aab`.
The helper neither generates signing material nor rewrites signing settings.

Toolchain now owns Gradle process settings. The old helper's 4 GiB heap, 1 GiB
metaspace and two-worker defaults are removed. Nonempty `GRADLE_BIN`,
`ANDROID_AAB_GRADLE_JVM_ARGS` and `ANDROID_AAB_MAX_WORKERS` overrides refuse with a
migration diagnostic. `JAVA_HOME` and `GRADLE_USER_HOME` behavior is retained.

Both official Android-app guides ([0.13.0](https://github.com/JetBrains/kotlin-toolchain/blob/v0.13.0/docs/src/user-guide/product-types/android-app.md#packaging),
[0.14.0](https://github.com/JetBrains/kotlin-toolchain/blob/v0.14.0/docs/src/user-guide/product-types/android-app.md#packaging))
document the command and final `build/tasks/_android-app_bundleAndroid/gradle-project-release.aab`.
They explicitly call that path temporary. The checked commands did not print a
usable artifact path, so the helper retains one explicit locator rather than
parsing progress output or globbing intermediate bundles. The
[update workflow](../compatibility-watch.md#interop-workaround-retirement)
requires rechecking this contract and replacing the locator when a supported
artifact-reporting interface is available. No Gradle cache-layout fallback is added.

## Executed check

Run `47dea10eced3b8c6866249af0ceb12d8` used the existing
`android-build-release-candidate` job, private caches, a copied licensed SDK seed
and generated synthetic Android Debug signing keys. No production credentials,
publication or store delivery were involved. Bundletool 1.18.3 read each final
AAB's manifest/resource protobuf; `jarsigner` verified its synthetic certificate.
The published AAB matched Toolchain's final artifact on every stage.

| Stage | Expected label / probe string | 0.13.0 | 0.14.0 |
| --- | --- | --- | --- |
| Initial lane | Mobi / baseline | Passed | Passed |
| Manifest edit | manifest probe / baseline | Passed | Passed |
| Manifest revert | Mobi / baseline | Passed | Passed |
| Resource edit | Mobi / resource probe | Passed | Passed |
| Resource revert | Mobi / baseline | Passed | Passed |

The probe string was referenced from temporary manifest metadata to keep its
packaged value observable. The first attempt's lane passed, but its unreferenced
raw probe was absent from the AAB; that observer result remains inconclusive.
The corrected pair passed all ten observations. This does not overturn the
separate [0.13.0 Debug APK invalidation finding](2026-11-19-toolchain-014-invalidation.md).

The new standard-library Ruby contracts cover final/intermediate selection,
paths with spaces, unchanged signing configuration, package failure and missing
output without stale publication, redirected output, and retired overrides.
All 20 repository contract suites passed with their required process access;
the initial sandbox-only run could not exercise executor process inspection.

The [compact receipt](2026-11-20-android-aab-command.json) binds the working
snapshot, helper, run and inspection tool. Full logs remain ignored. Authored
inputs and caller index were verified unchanged; owned processes were quiescent
before build/cache cleanup. Normal staged native and hosted checks belong to
this PR. Production signing, cold/relocated delivery, 0.14.0 adoption and security
acceptance remain separate gates.
