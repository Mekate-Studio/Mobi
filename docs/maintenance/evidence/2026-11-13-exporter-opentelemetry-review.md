# Exporter OpenTelemetry assessment — 2026-11-13

**Disposition: findings remain open; await a qualified owner release.** The
selected Kotlin 2.5.0-RC exporter still declares OpenTelemetry API 1.41.0. Kotlin
has an upstream update to 1.67.0 on `master`, but the published RC does not deliver
it. The Toolchain launcher independently delivers 1.60.1. This assessment changes
documentation and update-review checks only. It introduces no dependency
override, launcher flag, generated-source patch or new test/build machinery.

Base: `28d5fb1dc615905b4174cc6ffa1bf4056ebf9d36`, merged PR #104. The selected
compiler/exporter/Native tuple, application behavior and tests remain unchanged.
This is exposure triage and an owner-update plan, not remediation, risk acceptance
or repository-wide security clearance.

## Finding and owner boundaries

| Delivered surface | Evidence | Disposition |
| --- | --- | --- |
| Standalone exporter JVM dependency | `swift-export-embeddable:2.5.0-RC` POM declares `opentelemetry-api:1.41.0` at runtime; its API POM brings context 1.41.0 | Both named Moderate findings remain matched |
| Kotlin compiler embedded subset | The actual compiler JAR contains relocated `org.jetbrains.kotlin.io.opentelemetry` classes; neither affected parser class is present in the scanned compiler or exporter JAR | Distinct bytes/class namespace; an external API pin alone does not update this subset |
| Toolchain 0.13.0 launcher | Actual class origins and the versioned catalog select unshaded API 1.60.1; its trace-context parser loads during the iOS build | Both IDs also match this separately owned version; not part of the exporter module's public Maven graph |

The [tracestate advisory](https://github.com/open-telemetry/opentelemetry-java/security/advisories/GHSA-ccrj-gw8r-854m)
describes excessive CPU use when crafted headers reach
`W3CTraceContextPropagator.extract()`; its fixed API version is **1.67.0**.
The [baggage advisory](https://github.com/open-telemetry/opentelemetry-java/security/advisories/GHSA-rcgg-9c38-7xpx)
describes excessive allocation/CPU during oversized baggage extraction; its fixed
version is **1.62.0**. Both vendor and captured reviewed records classify these
findings as Moderate. Header extraction is the affected operation; dependency
presence, statistics reporting and class loading are different observations.

Fresh exact queries for API **1.41.0**, **1.60.1** and **1.67.0** return the same
two IDs for each old version and no match for the fixed reference. All three
results and both full finding records are HTTP 200 with complete cardinality and
no pagination. The 1.67.0 query is reference evidence, not a selected candidate or
a claim that all of its transitives are clear.

## Actual graph, bytes and execution

Fresh public settings/dependencies cover nine modules and 104 roots, with the
same complete parsed graph as the #104 qualification and 359 named Maven queries.
OpenTelemetry 1.41.0 occurs in **`swift-export` JVM main/test runtime roots**;
neither compile root contains it. This corrects the earlier RC assessment's
compile-root attribution. Only the three named versions above were freshly
queried in this slice; this is not another full 359-query advisory scan.

The selected exporter/compiler JARs match the inspected Maven artifacts. Their
published SHA-1 checksums were verified and their SHA-256 identities retained;
these artifacts do not publish SHA-256 sidecars. The API/context 1.41.0 JARs and
the actual Toolchain API 1.60.1 JAR match published SHA-256 checksums. Checksum
agreement establishes these artifact identities, not publisher authentication.

The external API 1.41.0 JAR contains both affected parser classes. Neither is
present in the inspected exporter/compiler JAR, including the compiler's relocated
namespace. Disassembly of the exporter provider confirms calls into that
relocated namespace. This does not inventory every shaded/native/tool artifact.

The unchanged `./scripts/ci/run_job.sh ios-test` passed **79 test functions**, no
failures/skips, under installed JDK 25 and Xcode 27.2. Existing compile-contract
checks passed six complete switches and rejected six omission controls; the app
report still identifies one Kotlin runtime image. Existing strict-support and
coroutine-inheritance blockers remain recorded by that checker.

For this run only, `JAVA_TOOL_OPTIONS` carried JDK class-loading diagnostics to
separate external log files. The actual exporter `MainKt` process loaded five
relocated tracing classes from the inspected Kotlin compiler JAR. It did not
load either affected parser or the unshaded API 1.41.0 classes. A separate
positive control explicitly loaded both parser classes from that actual API JAR
and recorded both origins. It invoked no header extraction or allocation attack.
No diagnostic option or helper is added to Mobi's maintained launch path.

This is evidence for this generation path, not universal unreachability. Source
review of the selected [Analysis API statistics contract](https://github.com/JetBrains/kotlin/blob/4eeec3a1fba47a3fbd807dcb0f482535fa8503ce/analysis/analysis-api-platform-interface/src/org/jetbrains/kotlin/analysis/api/platform/statistics/KaStatisticsService.kt)
also says Standalone does not collect statistics by default. Mobi's entry point
configures local KLib translation and registers no telemetry provider or header
extractor. Absence in one trace does not waive the matched vulnerable dependency.

The launcher trace separately loads `W3CTraceContextPropagator` from API 1.60.1.
Toolchain's versioned [telemetry setup](https://github.com/JetBrains/kotlin-toolchain/blob/v0.13.0/sources/amper-telemetry/src/org/jetbrains/amper/telemetry/TelemetrySetup.kt)
configures that propagator; [child-process telemetry](https://github.com/JetBrains/kotlin-toolchain/blob/v0.13.0/sources/amper-telemetry/src/org/jetbrains/amper/telemetry/ChildProcessTelemetry.kt)
extracts a serialized parent context from `AMPER_OTEL_PARENT_CONTEXT`. This is a
separate build-environment input boundary. Class loading does not prove the
vulnerable parsing operation executed, and no crafted-context test was run.
The reviewed setup does not configure the baggage propagator; that is not a
whole-distribution unreachability finding.

## Owner update and review decision

Kotlin [PR #9547](https://github.com/JetBrains/kotlin/pull/9547), merged November 6
as `41b42792aa1eeac687a69fe34189a7b964d45016`, updates the API from 1.62.0 to
1.67.0, its context/common verification metadata and the expected exporter POM.
It references **KT-91289**. The YouTrack page could not be retrieved in this
review; its status/fix-version fields are not independently verified. The merged
PR and artifact contents establish the narrower facts above.

The published 2.5.0-RC tag is `4eeec3a1fba47a3fbd807dcb0f482535fa8503ce`; its
catalog and actual POM still select 1.41.0. Publication after the master fix does
not imply inclusion. The current release lists, including prereleases, provide
no newer published Kotlin/Toolchain candidate for this review. Toolchain's
current `main` catalog has API 1.66.0, which is still below the tracestate fix;
it is also not the selected release.

Prefer the owner-delivered update when a release actually contains it. A forced
unshaded API upgrade would add compatibility/retirement obligations, would not
replace the compiler's relocated bytes, and would not update Toolchain's separate
launcher. No override or exclusion is qualified or proposed here. Both findings
stay visible. This decision does not renew or rebind historical tooling risk
acceptances, change severity/age policy or close broader coverage gaps.

The [manual update-review checks](../dependency-review-playbook.md#exporter-opentelemetry-owner-review)
now name both owners, actual runtime artifacts, the upstream fix and the required
future qualification. IOS-10 remains active for custom producer integration.
The selected and current official Swift-export architecture/execution-model docs
were reviewed and are byte-identical. The [published Swift-export guide](https://kotlinlang.org/docs/native-swift-export.html)
was also reviewed; its integration example uses Gradle. No new supported
Toolchain integration is established by this security update.

## Validation limits and recovery

The [compact receipt](2026-11-13-exporter-opentelemetry-review.json) retains graph,
source, advisory, artifact and trace identities. Download/bootstrap caches were
privately seeded; app outputs were built in this isolated checkout. The trace
adds diagnostic overhead, so timing/performance comparisons are not claimed.
There is no candidate dependency change and therefore no paired remediation
result. Normal final-source checks and hosted results are recorded in the PR.

Coverage excludes a complete compiler/Native/Gradle/shaded inventory, hostile
environment injection, arbitrary plugin/SDK configuration, APK/IPA absence proof,
device acceptance and signed delivery. Temporary diagnostics and the positive
control remain outside the repository. Recovery reverts this documentation
slice; no application, dependency, delivery or policy setting changes.
