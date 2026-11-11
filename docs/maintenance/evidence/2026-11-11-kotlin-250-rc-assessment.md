# Kotlin 2.5.0-RC source assessment — 2026-11-11

**Decision: proceed to bounded qualification when admitted; no adoption or
workaround removal is qualified.** This is a source/policy assessment against
Mobi `8094b25003fcec6fdd3ab8cb62b9a58040ef49b0`, after PR #100. No compiler,
exporter, dependency, producer or app setting changes in this review.

## Eligibility and evidence scope

[RC](https://github.com/JetBrains/kotlin/releases/tag/v2.5.0-RC), commit
`4eeec3a1fba47a3fbd807dcb0f482535fa8503ce`, was published
`2026-11-11T10:19:34Z` as a prerelease. The unchanged seven-day policy reaches
its age threshold at **2026-11-18T10:19:34Z**. It is a visible experimental review
lead, not a selected candidate. The age threshold alone will not authorize adoption.
Main stays on Kotlin/exporter 2.5.0-Beta2, Toolchain 0.13.0, Metro 1.5.0 and
coroutines 1.11.0.

Reviewed the RC release notes and the 44-commit interval from
[Beta2](https://github.com/JetBrains/kotlin/tree/071abf683c83fa8b2a7d1f9ebf4675ae05f7dfd5).
GitHub's comparison file list hits its 300-file cap; it is not complete file-diff
evidence. The separate recursive `native/swift` trees are untruncated: Beta2 tree
`b9c4c770e9aca91373abe8524b042a8af4021142` has 1,444 entries; RC tree
`5c5232c64cc745b044541d2f5d81255393538fb7` has 1,457. Comparing blob identities
finds 41 added/modified files, no removed files: eight production files and
33 test/data files. Reviewed the production changes and relevant commit patches
outside that subtree. This is not a whole-repository source audit.

## Changes mapped to Mobi

| Upstream change | Actual Mobi consequence and required check |
| --- | --- |
| [Release link anchor](https://github.com/JetBrains/kotlin/commit/79acd7242095f32174a54737676ce61945863d19), KT-90738: runtime anchor becomes `package` so it remains externally linkable under Release optimization | `build_swift_export.rb` already supplies `-package-name MobiShared`. No new adapter is indicated by source inspection. Qualify the real unsigned Release link and anchor symbol; a Debug pass cannot establish this benefit. |
| [Reverse bridge binding](https://github.com/JetBrains/kotlin/commit/d8e05c2774924f5b1724903edcbf1acfa122d8d2): context/receiver parameter ordering, property overrides/default witnesses and shared async generation change | Mobi's Swift repositories implement ordinary suspend methods, not these context/extension-property cases. Their generator path still changes, so run the real Home/Nearby Swift-repository success, ordinary/domain-error, cancellation and late-result controls. No typed-error fixture removal follows from argument-binding fixes. |
| [Legacy KLib suspend conversions](https://github.com/JetBrains/kotlin/commit/f931f6699e2812d0408420deb02d0c8ab5204c44), KT-91139, and value-class compatibility fixes | Exercise the actual resolved Native libraries and Shared Compose composition, including `VehicleId`. The release does not establish which older KLib producers occur in Mobi's graph; capture their actual inputs. |
| Compose Native SAM fix KT-90466 and Native Objective-C fake-override fix KT-90589 | Shared UI/Compose and platform libraries are indirect compiler consumers. Keep actual shared/native app compilation and runtime tests; source inspection found no direct Mobi context-parameter or composable-SAM example qualifying these fixes. |
| [Native incremental default](https://github.com/JetBrains/kotlin/commit/4eeec3a1fba47a3fbd807dcb0f482535fa8503ce), KT-91432 | This patch changes KGP's default. Mobi's Toolchain compiler/direct Native producer do not execute that KGP setting path. Inspect their actual arguments and timings during rehearsal; do not add a compensating incremental flag. |
| [Path containment](https://github.com/JetBrains/kotlin/commit/1c7781875803965e45f5608a852081447941fc15), KT-89235, plus subsequent version-hash follow-up | These are KGP metadata/transform/SPM-generation paths, not blanket compiler or Toolchain security clearance. A cached Toolchain 0.13.0 Android classpath index lists KGP 2.2.10. RC compiler/exporter pins alone do not prove that bundled tooling is replaced. Require a fresh resolved build-input/advisory review before claiming applicability or mitigation. |

Other release-note families include Analysis API standalone, JVM reflection,
parser/value-class handling, Java serialization, Lombok, Gradle configuration and
JS/Wasm tooling. Mobi has Android/iOS targets; Lombok and JS/Wasm are not declared
app paths. General compiler and transitive effects remain covered by the paired
real graph and gates, not by a claim that unobserved paths are unaffected.

## Primary source and companion review

All six official design documents at Beta2, RC and current upstream
[`ea398de4c297`](https://github.com/JetBrains/kotlin/tree/ea398de4c297e91f64cc2bb841f7a5ae95534284/docs/swift-export)
have the same blobs recorded in the [November 4 table](2026-11-04-ios08-strict-support.md#upstream-review).
The README still warns about unstable standalone APIs and documentation lag.
The [published guide](https://kotlinlang.org/docs/native-swift-export.html) describes
async/Flow support but still calls the product Alpha. Documentation labels do not
qualify Mobi's delivery or strict Swift 6 support.

The complete resource comparison shows unchanged KotlinCoroutineSupport Swift
(`2bdf3c73b7a6b867f73e33182020a590e99416a9`) and Kotlin
(`56040403dd61d590c37b9f288f348f216bd09680`) sources. RuntimeSupport Swift changes
only the link-anchor visibility/comment; `KotlinError.wrapped` still contains
KotlinBase. Its RC blob is `16b591b4224b76df52f2d9fad72a50d563ff2ca8`.

Public YouTrack API status/version fields were checked on this review:

- [KT-90266](https://youtrack.jetbrains.com/issue/KT-90266): **In Progress**,
  updated 2026-10-15, no planned/available version. Strict Swift 6 remains an
  actual-producer recheck, not a release-note removal.
- [KT-90738](https://youtrack.jetbrains.com/issue/KT-90738): **Fixed**, RC is listed
  as available. This matches the anchor patch, not an unsigned Mobi Release result.
- [KT-64572](https://youtrack.jetbrains.com/issue/KT-64572): **Fixed**, available in
  2.2.20-Beta2. That historical public-release milestone does not close KT-90266.

The official sample remains at
[`654a686070c0`](https://github.com/Kotlin/swift-export-sample/tree/654a686070c07e293679f1c24136be73562df7a1),
selecting Beta2 and coroutines 1.11.0; it supplies no RC runtime qualification.
Metro's [1.5.0 table](https://github.com/ZacSweers/metro/blob/1.5.0/docs/compatibility.md)
and current table at
[`074e6958d4d9`](https://github.com/ZacSweers/metro/blob/074e6958d4d9f05e1f430e96217266062b8829af/docs/compatibility.md)
list Beta2 but no RC entry. This is an unverified companion, not demonstrated
incompatibility. Resolve publisher guidance and actual compiler-plugin behavior;
do not choose a newer Metro merely because it exists. Toolchain's latest five
published release records still begin at 0.13.0; no newer integration was qualified.

## Retirement disposition and next qualification

| Existing mechanism | Disposition in this assessment |
| --- | --- |
| IOS-02 caller isolation; IOS-07 import checking | Keep current main settings. Recheck the full generated graph and existing actor/omission controls; no removal evidence collected. |
| IOS-08 Swift 5 support exception; IOS-17 SwiftJob inheritance | Keep current settings. Support sources and the Swift 6 issue provide no source-level removal lead. Actual strict/diagnostic probes remain unrun on RC. |
| IOS-10 custom producer | Keep it. The RC's Gradle/SPM changes do not provide Toolchain-owned Swift export; existing package naming already accommodates the anchor declaration. |
| IOS-12 private JVM directories | Keep the scoped control. No fresh graph/advisory clearance or risk exception is part of this assessment. |
| IOS-14 typed-domain fixtures and Kotlin-origin controls | Keep them pending the real error round-trip. Reverse-binding fixes do not establish typed exception transport. |
| IOS-13 test ownership; IOS-16 observation closure | Keep them. They are native test/compiler constraints; the known Nearby timer-fixture reliability follow-up stays open. |
| AND-01/02/03 | Android harness/provisioning and the deferred Shared UI rendering gap stay open. A Kotlin compiler RC does not qualify their replacement. Draft #99 stays unadopted. |

After age admission and companion review, qualify one small compiler/exporter
update using the existing Toolchain settings and matched compiler/Native/exporter
versions. Run an unchanged Beta2 baseline first, then the same checks on RC:

1. Resolve/hash the actual graphs and plugin inputs, complete fresh advisory
   review and capture compiler arguments. Record any unresolved companion support.
2. Build the actual export graph with the maintained producer; run
   `ruby scripts/ios/build_swift_export.rb --strict-support` without patches,
   suppression or fallback. A failure keeps IOS-08 open. Count any required API
   adjustment and all supporting code before proposing adoption.
3. Run the normal Android/shared and native iOS test/build gates, all generated
   compile/actor/omission controls, repository/failure/cancellation/lifetime cases,
   and separate unsigned Release link/product inspection for the anchor fix.
   Keep one Kotlin runtime and the existing Debug/Release test-symbol boundary.
4. Preserve the known native timer failure and any new failure. An unchanged
   rerun is diagnostic evidence, not a fixture repair. Compare warnings and
   cold/warm costs; do not hide regressions with retries or larger limits.
5. Review the actual small app/tool diff and any qualified simplification. Keep
   signed delivery, physical/minimum-runtime qualification and further retirement
   claims separate. No new test runner is required by this plan.

No RC dependency graph was resolved and no RC producer or app was run. No full advisory scan,
unsigned Release, device/signed delivery, performance comparison or replacement
probe passed by implication. This assessment changes no selected candidate,
age policy, warning suppression, workaround disposition or adoption authority.
