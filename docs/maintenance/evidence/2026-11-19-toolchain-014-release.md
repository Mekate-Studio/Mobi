# Toolchain 0.14.0 unsigned Release check — 2026-11-19

**Result: local unsigned Release checks passed for the measured iOS simulator and
Android command paths.** The app remains on Toolchain 0.13.0. Signed/device
execution, cold/relocated delivery and dependency-risk acceptance remain separate.

Base: `556ab821c0892fa7cab3cbe6d3d2194488a74bb6`, merged PR #117. The existing
[0.14.0 qualification age exception](2026-11-18-toolchain-014-qualification.md)
applies; the receipt retains `age_blocked` and normal eligibility on November 23.
Kotlin/exporter 2.5.0-RC, Metro 1.5.0, Swift package locks and platform floors stayed
fixed. No app pin, release lane or producer implementation changes are included.

## Unsigned iOS simulator Release

Both wrappers passed the existing `ios-build-release` job with
`CODE_SIGNING_ALLOWED=NO` and `CODE_SIGNING_REQUIRED=NO`, followed by product
inspection. Manual job selection reused the existing guarded snapshot runner;
it is not a claim to execute every job in the automatically classified staged plan.
Each iOS snapshot was cleaned before the next iOS phase, bounding disk use.
The final documentation commit has its own normal commit checks.

| Product fact | 0.13.0 | 0.14.0 |
| --- | --- | --- |
| Bundle ID / minimum | `studio.mekate.mobi` / iOS 26.0 | Same |
| Mach-O architecture / platform / SDK | ARM64 / simulator (7) / 27.2 | Same |
| Generated Swift modules / project KLib inputs | Seven / six | Same |
| Native archive optimization | `-opt`; Swift-export producer flag enabled | Same |
| `MobiTestSupport` producer input | Absent | Absent |
| Images with defined Kotlin runtime symbols | One: `ios-app` | Same |
| Compiled native asset catalog | 42 icon entries | Same count and catalog hash |
| Signing files / provisioning profile | Absent | Absent |

The seven modules are `ExportedKotlinPackages`, `KotlinRuntimeSupport`,
`KotlinCoroutineSupport`, `MobiCore`, `MobiHome`, `MobiNearby` and `MobiIOS`.
The actual project KLib records must match the selected wrapper and compiler.
This checks absence of the test-support *producer input*; Toolchain's build command
can still compile/link native test tasks that are not packaged in this app.

### Optimized runtime observation limit

The Debug runtime-init marker and mode constant are absent from the optimized
Release image. The first baseline build succeeded, but reusing that Debug
inspection produced an inconclusive observation. Its logs and original observer
bytes were retained, and the completed pair was rerun with Release-appropriate
inspection.

The receipt distinguishes one runtime-symbol-bearing image, the checked producer
flag and **unobserved direct optimized-image mode value**. It does not infer a
successful constant read from compilation. No symbol-retention flags, optimization
changes or delivery shim were added to preserve the Debug probe. Existing Debug
runtime/actor checks remain unchanged. On Kotlin/Swift-export updates, recheck
supported optimized-product observability; this gap does not authorize retiring
IOS-10 or other interop mechanisms.

## Unsigned Android Release APK and AAB

Each owned copy used the same temporary
`settings.android.signing.enabled=false` overlay. No release credentials were
supplied, and the original module bytes were restored afterward. The sole
baseline/candidate version change was the reviewed 0.14.0 wrapper pair.

The existing logging wrapper ran `build -m android-app -p android -v release`, then
`package -m android-app`. Both commands are documented for
[0.13.0](https://github.com/JetBrains/kotlin-toolchain/blob/v0.13.0/docs/src/user-guide/product-types/android-app.md#packaging)
and [0.14.0](https://github.com/JetBrains/kotlin-toolchain/blob/v0.14.0/docs/src/user-guide/product-types/android-app.md#packaging).
APK inspection requires the expected application ID, API 36 minimum/target, API 37
compilation, no debuggable flag and signature verification refusal for the unsigned
product. AAB inspection requires its configuration, manifest/resource protobuf and
DEX entries, unsigned verification output, no certificate metadata and R8 mapping
outputs. These are package/configuration observations, not device execution,
whole-product equivalence or complete release-graph advisory coverage.

| Product check | 0.13.0 | 0.14.0 |
| --- | --- | --- |
| Release APK identity / APIs | `studio.mekate.mobi`; min/target 36, compile 37 | Same |
| APK debuggable flag / signature | Absent / verifier refuses unsigned artifact | Same |
| APK bytes and R8 mapping | Captured | Same SHA-256 values as baseline |
| Final AAB structure / unsigned verification | Passed | Passed |

The AAB archive hashes differ. Entry-level comparison found 114 matching payloads
and two differing protobuf entries: `base/resources.pb` and the library dependency
inventory. A retained follow-on AAB pair at the same source/pins was decoded using
the publisher-digest-verified [Bundletool 1.18.3](https://github.com/google/bundletool/releases/tag/1.18.3)
public protobuf classes. It introduced no app or workflow dependency.

Resource messages match after clearing only `source_pool`, which the
[public AAPT schema](https://github.com/aosp-mirror/platform_frameworks_base/blob/master/tools/aapt2/Resources.proto)
defines as developer source paths excluded from final binary ARSC. Dependency
messages match after replacing only six exact owned project prefixes in local
artifact paths. All other fields, including dependency digests/references,
repositories and unknown fields, remain intact; 113 metadata records are compared.
These file-based records are not a newly attributed Maven advisory inventory.
The follow-on bundles' per-phase payloads also match the full build pair except
for that run-root-dependent inventory. This is scoped content agreement, not
whole-AAB reproducibility. No produced AAB was rewritten; normalization affected comparison messages only.

The initial baseline APK build succeeded, but the one-off observer expected the
older AAPT minimum-SDK field name. The corrected pair uses the installed tool's
`minSdkVersion` field and actual unsigned-verifier output. A subsequent observer
refused Gradle's intermediate bundle as a competing product; final selection is
bound to the documented top-level AAB. The protobuf follow-on's first coordinator
refused a check-name mismatch. All corresponding builds succeeded; these are
retained observation/setup diagnostics, not app regressions.

### Simplification follow-up for the existing lane

`scripts/ci/build_android_aab.sh` manually locates Gradle under `wrapper/dists`.
That lookup does not cover 0.14.0's Toolchain extraction cache. This assessment
uses the documented packaging command, so it **does not qualify the current
Fastlane helper integration**. The follow-up is a small real-code PR replacing
that helper's manual Gradle invocation with the qualified public command while
preserving output publication/discovery and signing policy. Recheck those actual
contracts on Toolchain updates instead of adding cache-layout variants here.
Toolchain's delegated Android Gradle/AGP bootstrap remains required.

## Evidence and remaining work

The [compact receipt](2026-11-19-toolchain-014-release.json) binds the source,
manual iOS plans/results, Android execution result, exact unsigned overlays,
product identities and raw log hashes. Full logs, symbol output and product-input
metadata remain in ignored local assessment storage. No bulk inventory or new
maintained runner is introduced. Owned cleanup and source/index restoration were
verified, with unrelated caller working files preserved.

The [manifest/resource warm check](2026-11-19-toolchain-014-invalidation.md) remains
separate, as do its starter-resource cleanup and the
[dependency findings and attribution/transform gaps](2026-11-18-toolchain-014-dependencies.md).
No warning-debt closure is claimed; raw Release diagnostics are retained.
Cold/relocated delivery, signed/device archives, Release runtime behavior and
advisory acceptance remain open. These results do not change any publication hold
or grant Toolchain adoption.
