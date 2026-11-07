# Generated coroutine inheritance: WARN-05 / IOS-17

Status: **retained upstream constraint**, reviewed 2026-11-07. No supported
removal is verified for Kotlin 2.5.0-Beta2 / coroutines 1.11.0. The warning remains
open; this change adds observability, not an inheritance opt-in or source patch.
IOS-08's Swift 6 sendability constraint is separate.

## Official source review

- The [published Swift-export guide](https://kotlinlang.org/docs/native-swift-export.html)
  documents Alpha async/Flow support. The [implementation README](https://github.com/JetBrains/kotlin/blob/v2.5.0-Beta2/docs/swift-export/README.md)
  warns that implementation documentation can lag and standalone APIs are unstable.
  Neither establishes a supported Job inheritance contract.
- The [selected coroutine template](https://github.com/JetBrains/kotlin/blob/v2.5.0-Beta2/native/swift/swift-export-standalone/resources/swift/KotlinCoroutineSupport.kt)
  emits `class SwiftJob private constructor() : Job by Job()`. Its blob is
  `56040403dd61d590c37b9f288f348f216bd09680`, identical to `master` when inspected.
  Its `InternalCoroutinesApi` opt-in differs from `InternalForInheritanceCoroutinesApi`.
- Coroutines 1.11.0's [Job interface](https://github.com/Kotlin/kotlinx.coroutines/blob/1.11.0/kotlinx-coroutines-core/common/src/Job.kt)
  requires the inheritance marker. The [marker documentation](https://github.com/Kotlin/kotlinx.coroutines/blob/1.11.0/kotlinx-coroutines-core/common/src/Annotations.kt)
  says inheritance is unsafe/unsupported and the warning will become an error.
  A compiler opt-in would acknowledge that contract, not repair it.
- The [official Beta2 Gradle integration](https://github.com/JetBrains/kotlin/blob/v2.5.0-Beta2/libraries/tools/kotlin-gradle-plugin/src/common/kotlin/org/jetbrains/kotlin/gradle/plugin/mpp/apple/swiftexport/SwiftExport.kt)
  adds the same three Native compiler opt-ins as Mobi: `ExperimentalNativeApi`,
  `ExperimentalForeignApi` and `InternalForKotlinNative`. Current master retains
  those opt-ins. This comparison is limited to opt-ins, not all compiler options.
- The [official sample](https://github.com/Kotlin/swift-export-sample) selects
  Beta2 / coroutines 1.11.0 with no inheritance opt-in. Reviewed catalog/build blobs:
  `baf955e28026fbc1fe89a5fffff6127fcf172b53` /
  `ea6d7726ecd456aa6494107ca49e5c9ea731add8`.

No exact upstream issue/fix was verified. [KT-64572](https://youtrack.jetbrains.com/issue/KT-64572)
and [KT-80305](https://youtrack.jetbrains.com/issue/KT-80305) remain navigation
leads, not evidence that this inheritance contract is resolved. Any proposed
upstream report needs review before publication.

## Actual delivery check and review cost

The normal `ruby scripts/ios/check_swift_export.rb` check now reads the generated
`KotlinCoroutineSupport.kt`, `native.log` and `native-cache.json` from the actual
producer output. Missing inputs fail rather than becoming a warning-free result.
The Native receipt preserves the compiler argv even when the producer reuses its
verified archive. No second app, transport, runtime or compilation is introduced.

`build/logs/swift-export-checks/report.json` contains `coroutine_inheritance`:
source SHA-256, Job delegation, marker presence, exact diagnostic count, compiler
opt-ins and diagnostic-control flags. The matching normalized diagnostics are
saved as `coroutine-inheritance.log` in the existing uploaded artifact directory.
The registry connects IOS-17 to Kotlin/coroutines/Toolchain release reviews;
the release watch does not run the check itself.

A real Debug simulator producer run on the unchanged base emitted **one**
inheritance warning at `KotlinCoroutineSupport.kt:32:40`. Generated source SHA-256:
`98643dd11d89a5cf97dc8925c79b5ebd41abfe644ca18e9bb53262ebc97b515e`.
No inheritance compiler opt-in or diagnostic-control flag was present.

If the diagnostic disappears, the report explicitly requests review. A changed
message, source annotation, compiler opt-in or suppression could explain absence.
Inspect the selected upstream source and coroutines contract before claiming a
supported fix. Then regenerate and qualify real Home/Nearby success, uncaught
errors, cancellation recovery, late completion and lifetime tests with one Kotlin
runtime on local and hosted compiler tuples. Other WARN-05 diagnostics stay open.
