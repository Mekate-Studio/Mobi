# IOS-10 exporter runtime recheck — 2026-11-06

Base: `45a5cea5325bd486ad6866b632cf50485ec46d30`, merged PR #83.
Selected tuple: Toolchain 0.13.0, Kotlin/exporter/Native 2.5.0-Beta2,
Metro 1.5.0 and mobile coroutines 1.11.0. Local Xcode is 27.1 / Swift 6.4;
the producer's JVM runs on JDK 25.0.4.1+1.

## Removed mechanism

Remove the exporter tool's explicit
`com.intellij.platform:kotlinx-coroutines-core-jvm:1.8.0-intellij-13`
runtime-only dependency and its IntelliJ Maven repository from
`tools/swift-export/module.yaml`. Do not add a replacement override. The selected
compiler's published metadata already supplies standard
`org.jetbrains.kotlinx:kotlinx-coroutines-core-jvm:1.8.0` at runtime.
That build-tool dependency is separate from the app's mobile coroutines 1.11.0.

This is a partial IOS-10 retirement. The standalone exporter, bridge compiler,
module ordering, task-record integration and Xcode preflight remain. No app
source, generated source, export graph, compiler version or CI invocation changes.
Local validation also needs the small environment-propagation correction below.

## Actual producer comparison

Run `ruby scripts/ios/build_swift_export.rb` in an isolated worktree, first on
the base declarations, then after removing only the extra runtime/repository.
Use the same resolved app KLibs, Native distribution, target and configuration:
`iosSimulatorArm64`, Debug. Preserve generation logs and source hashes before
the candidate run overwrites the output directory.

- The baseline producer passes with one Kotlin archive and eight Swift modules.
- The candidate's Toolchain resolution record contains 17 runtime JARs, including
  the compiler's standard coroutines runtime and excluding the IntelliJ variant.
  Its repository inputs are Maven Central's configured mirror and Google Maven.
- Generation completes without `Exception in thread`, `NoClassDefFoundError` or
  `ClassNotFoundException`. The existing launcher still refuses these failures,
  including when the JVM exits zero.
- All eight generated module records, dependencies and Swift/Kotlin/C-header
  content hashes match the baseline exactly. The canonical, sorted-key JSON
  manifest of those records and content hashes has SHA-256
  `e601c545c113301f36cce0183f083749d9cd1da664876ecdb8d940528d51ca62`.
- The producer reuses the unchanged, verified native archive, SHA-256
  `2ac796de174c6c4792f23cacc2ddd4400217b02f632f62d2076d0e823edf5807`,
  then successfully compiles all Swift modules. This is binding/packaging
  equivalence, not yet an app runtime result.
- A second candidate run also passes after moving this worktree's cached IntelliJ
  runtime out of its toolchain cache. Bindings remain identical and the artifact
  is not redownloaded. Final app and hosted results are recorded in the
  implementation PR.

The existing inventory contract continues to cover `runtime-only` YAML syntax
using a small declaration fixture, independently of current app dependencies.
The actual-tool inventory assertion now checks the exporter coordinate that
remains. No new production code or dependency is added to retire this override.

## Local validation prerequisite

A cold local gate encountered Maven Central HTTP 429 for Robolectric's
`nativeruntime-dist-compat:1.0.18`; the configured public mirror served it with
HTTP 200. The source-copy gate was dropping the caller's supported
`KOTLIN_DEFAULT_MAVEN_CENTRAL_URL` setting. Add that setting to its existing
host-tool allowlist. The existing child-environment contract fails before the
fix and passes after it, while retaining its credential/version exclusion checks.
Unset behavior, selected jobs, source guards and dependency versions stay unchanged.

Toolchain 0.13.0's [configuration source](https://github.com/JetBrains/kotlin-toolchain/blob/v0.13.0/sources/libraries/maven-central-configuration/src/org/jetbrains/amper/mavencentral/mavenUtil.kt),
blob `e5ef018fc0366b139788f60b7325916bc3b3a7e4`, confirms the setting. This is
local build configuration propagation, separate from the retired IOS-10 runtime.

## Hosted timer fixture correction — IOS-13

[CI #589](https://github.com/Mekate-Studio/Mobi/actions/runs/42286184688) builds
the app successfully but times out the existing timer-cadence test at its
one-minute limit; the other 169 test runs pass. Local executions pass in 2.538
and 3.329 seconds. That timer fixture does not call the shared services. The
timeout alone does not identify which await stalled or establish an exporter
regression; qualify the scheduling correction against the actual suite.

The pinned [TestClock implementation](https://github.com/pointfreeco/swift-clocks/blob/cc46202b53476d64e824e0b6612da09d84ffde8e/Sources/Clocks/TestClock.swift)
advances time using background-task yields. Keep the existing clock and route
its advances through Point-Free's existing
[`withMainSerialExecutor` API](https://github.com/pointfreeco/swift-concurrency-extras/blob/5a3825302b1a0d744183200915a47b508c828e6f/Sources/ConcurrencyExtras/MainSerialExecutor.swift).
The parent suite is already serialized under IOS-13. The library scope restores
the prior setting on return, but uses a process-wide runtime hook; this is a
visible test-library constraint, not compiler-checked isolation. Requalify and
remove the clock scope when supported per-test scheduling makes it redundant.
Keep all five timer scenarios, assertions and their original one-minute limits.
No scheduler-count override, retry policy, new dependency or app change is added.
Final local and hosted qualification of this correction is recorded in the PR.

## Sources and update observability

The [official implementation README at Beta2](https://github.com/JetBrains/kotlin/blob/v2.5.0-Beta2/docs/swift-export/README.md)
and current default branch have the same blob,
`fd64dd62fd08dcef0e907c0dd64f163199a0f6af`. They describe standalone artifacts
but do not qualify Mobi's runtime dependency override. The measured result above
is specific to this selected graph, not proof of a new Beta2 capability or an
identified upstream fix.

Published POM evidence, retrieved 2026-11-06:

| Artifact | SHA-256 | Relevant declaration |
| --- | --- | --- |
| [swift-export-embeddable](https://repo.maven.apache.org/maven2/org/jetbrains/kotlin/swift-export-embeddable/2.5.0-Beta2/swift-export-embeddable-2.5.0-Beta2.pom) | `b7a44d76185f2bb0ad12bc4585ecc484227dc287d317e988d3fc99d78bf35961` | Matching embeddable compiler at runtime |
| [kotlin-compiler-embeddable](https://repo.maven.apache.org/maven2/org/jetbrains/kotlin/kotlin-compiler-embeddable/2.5.0-Beta2/kotlin-compiler-embeddable-2.5.0-Beta2.pom) | `6435e4c20a663dd4a2817e2a8f7f9773f334114c7de09ecf569d00336541a128` | Standard coroutines 1.8.0 at runtime |

IOS-10 remains visible to the existing Kotlin/Toolchain/Swift/Xcode update watch.
On relevant updates, require clean actual generation, review the resolved graph,
and run app checks before changing delivery. A new runtime requirement needs an
explicit review; there is no automatic override fallback. Supported Toolchain
integration is still needed to retire the remaining producer. Strict support,
typed-error fixture exports, warning cleanup and signed delivery remain separate.
