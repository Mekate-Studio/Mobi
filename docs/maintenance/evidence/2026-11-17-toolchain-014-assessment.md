# Toolchain 0.14.0 source assessment — 2026-11-17

**Decision: candidate for isolated qualification; not qualified for adoption.**
The useful leads are incremental-build correctness and tool dependency updates.
No replacement for IOS-10's Swift-export producer was found. Qualification needs
two reviewed maintenance adaptations before running the candidate; this is not
a wrapper-only update. The selected app remains on Toolchain 0.13.0.

Base: `a77f3524245416b527f8b0d3dda39d084e1fcb48`, merged PR #113.
The [0.14.0 release](https://github.com/JetBrains/kotlin-toolchain/releases/tag/v0.14.0)
is tag commit `95a158010b0afe7cda88251a9f1357dbeb731fac`, published
`2026-11-16T14:49:08Z`. Normal seven-day eligibility is
`2026-11-23T14:49:08Z`. No age waiver, adoption or risk acceptance is granted here.

## Evidence and graph boundary

The [interval](https://github.com/JetBrains/kotlin-toolchain/compare/v0.13.0...v0.14.0)
contains 300 commits. All three 100-commit pages were collected, the fourth was
empty, and the last commit matches the tag. Complete, untruncated tag trees
identify **986 changed files**; the comparison API's first 300 files are not the
complete change set. Review covers commit subjects, the complete path delta,
and the sources relevant to Mobi below, rather than claiming a line-by-line
audit of all upstream code.

Published wrapper text was downloaded and hashed, without executing it:

| Identity | SHA-256 |
| --- | --- |
| Unix wrapper | `855436c4b4222f57c561e7bfe2f7f223bd72710d0f52a101883434ecbf05b089` |
| Windows wrapper | `70cbbe654418987c58a3b7d9e39f73a394b71852cb8d61d63ce1ebf7e997db20` |
| Distribution hash declared by wrapper | `69112cebc1fdb14c92a213244182d0834896e71b3d9411b8e8c18540da2884a6` |

The distribution archive itself has not been downloaded or verified. Source
catalogs change 20 version references; 71 unique mapped component/version pairs
span the two tags. These are declarations, including tooling/test dependencies,
not measured distribution, delegated Gradle or application runtime graphs.

| Declared surface | 0.13.0 → 0.14.0 | Mobi consequence to qualify |
| --- | --- | --- |
| Kotlin / Compose defaults | 2.4.20 / 1.12.1 unchanged | Preserve Mobi's explicit Kotlin/exporter 2.5.0-RC and Metro 1.5.0; no companion upgrade |
| AGP / Android tools / compile SDK | 9.3.1 / 32.3.1 / 37 unchanged | Keep API 36 minimum/target and API 37 compilation; measure actual delegated selection |
| Gradle Tooling API | 9.5.0 → 9.8.0 | New distribution task uses `GradleVersion.current()` and Toolchain extraction cache; verify actual launcher/version |
| Bouncy Castle / Commons Compress | 1.84 → 1.86 / 1.27.1 → 1.28.0 | Potential advisory improvement, requiring artifact attribution |
| Toolchain OpenTelemetry | 1.60.1 → 1.66.0 | One queried Moderate match remains; exporter ownership is separate |

## Concrete benefits and migration cost

- [Android build inputs](https://github.com/JetBrains/kotlin-toolchain/blob/v0.14.0/sources/amper-cli/src/org/jetbrains/amper/tasks/android/AndroidBuildTask.kt)
  now include manifest/resources/JNI packaging inputs. Compiler-versioned ABI
  snapshots and dependency-resolution changes are additional correctness leads.
  Reproduce warm invalidation and dependency selection before calling them fixes
  for Mobi; no candidate build ran in this assessment.
- [Android settings](https://github.com/JetBrains/kotlin-toolchain/blob/v0.14.0/sources/frontend-api/src/org/jetbrains/amper/frontend/schema/androidSettings.kt)
  now require application ID and default namespace from it. Mobi already declares
  both as `studio.mekate.mobi`; source review predicts no app identity edit.
  APK identity and generated namespaces still need verification.
- The [test command](https://github.com/JetBrains/kotlin-toolchain/blob/v0.14.0/sources/amper-cli/src/org/jetbrains/amper/cli/commands/TestCommand.kt)
  checks discovery across the command. Its tracker counts suite/skip events as
  discovery; this is not proof that tests executed. The old JVM command already
  used JUnit's no-tests guard. Preserve actual module counts and scenario checks.
- [Gradle provisioning](https://github.com/JetBrains/kotlin-toolchain/blob/v0.14.0/sources/amper-cli/src/org/jetbrains/amper/tasks/android/InstallGradleDistributionTask.kt)
  becomes a Toolchain task. Mobi's 80-line preseed/helper pair has no active CI
  or lane caller in this source, though inventory/Renovate still read its pin.
  Removing that stale surface is independent cleanup, not qualified savings
  from adopting 0.14.0. Delegated Android bootstrap remains required.
- [Gradle deprecation reporting](https://github.com/JetBrains/kotlin-toolchain/blob/v0.14.0/sources/amper-cli/src/org/jetbrains/amper/tasks/android/gradleProgressEvent.kt)
  moves deprecations to debug logging. Less console output does not close WARN-09
  or establish remediation. Preserve raw/debug diagnostics and owner attribution.

**Review before implementation:**

1. `scripts/ios/build_swift_export.rb:65` explicitly requires task-record
   `codeVersion == '0.13.0'`. A wrapper-only update would refuse 0.14.0 records.
   Verify record shape, compiler identity and KLib inputs before updating that
   exact guard. Keep a mismatched-record negative control; do not accept arbitrary
   versions merely to make generation pass.
2. `scripts/dev/validate.rb` and the maintenance JVM resource handler only locate
   Gradle launchers/classpath ownership under `wrapper/dists`. The new Task installs
   under the Toolchain cache. Adapt owned-path discovery and shutdown first,
   preserving foreign-process, symlink, unknown-launcher and recovery refusal
   controls. Do not run the candidate under known-incomplete cleanup assumptions.

These are source-derived incompatibilities, not reproduced candidate failures.
The future real-app PR must expose their actual patch cost. Stop for design review
if qualification needs another build project, a general private-metadata adapter
or a dependency override. No such machinery is proposed or added here.

## Swift-export and UI-test dispositions

**IOS-10 remains active.** The 0.14.0 [iOS guide](https://github.com/JetBrains/kotlin-toolchain/blob/v0.14.0/docs/src/user-guide/product-types/ios-app.md)
still documents `KotlinModules` framework integration. Complete candidate paths
contain no Swift-export integration surface. The official Kotlin
[README](https://github.com/JetBrains/kotlin/blob/master/docs/swift-export/README.md)
and [standalone execution model](https://github.com/JetBrains/kotlin/blob/master/docs/swift-export/standalone_execution_model.md)
were reviewed; standalone generation remains a build-tool responsibility.
Documentation can lag, so source/API and actual delivery remain the removal
criteria. Preview iOS publishing does not establish a producer replacement.
No active interop disposition or signed-delivery hold changes.

**AND-03 remains deferred.** The candidate still runs Android host tests outside
AGP unit-test tasks. Mockable `android.jar` provisioning and variant-resolution
fixes do not demonstrate delivery of dependency resource classes. No actual
Shared Home render or resource-enabled runner was qualified; PR #99 stays draft.

## Bounded advisory observation

Fresh OSV queries cover the 71 changed source-declared pairs, with complete batch
cardinality, no pagination and all four matched records retrieved. Old declarations
match `GHSA-9pwp-9qqc-pr26` (Critical), `GHSA-qp49-qgx5-5m26` (High), and two
OpenTelemetry Moderate IDs. Queried candidate declarations match only
[`GHSA-ccrj-gw8r-854m`](https://osv.dev/vulnerability/GHSA-ccrj-gw8r-854m), on API 1.66.0.
This does not show which declared components the distribution actually delivers,
prove remediation or establish security clearance.

Mobi's separately selected Kotlin 2.5.0-RC exporter still has its own API 1.41.0
runtime owner and two open findings; see the
[existing owner assessment](2026-11-13-exporter-opentelemetry-review.md).
Updating Toolchain's launcher does not provide an exporter owner update. No risk
acceptance, forced API override or finding closure is proposed.

## Proposed qualification decision

Recommend a version-bound **experimental qualification** after review of the two
adaptations above, retaining the real `age_blocked` state. The existing runner's
`--experimental` mode supports early stable-candidate assessment; it does not
change the seven-day policy or authorize adoption. Earlier exceptions for other
versions do not cover this release. An explicit decision would cover only
Toolchain **0.14.0**, its publication timestamp and declared distribution hash.

Qualification should capture baseline/candidate module, exporter-runtime,
distribution and delegated graphs with fresh attributed advisory review; test
record rejection and owned cleanup; run Android/shared tests, both Debug builds,
the native plan, unsigned Release and cold/relocated delivery. Verify unchanged
identity, resources, service identity, one Kotlin runtime, native packages and
existing interop controls. Include a controlled manifest/resource invalidation
case. Keep Kotlin/exporter, Metro, Swift packages, platform floors and feature
behavior fixed. Signed publication, a default switch, risk acceptance and any
workaround removal require their own evidence and review.
