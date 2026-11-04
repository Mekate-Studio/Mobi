# IOS-08 strict Swift 6 recheck — 2026-11-04

**Disposition: retained.** The actual generated support sources still fail
Swift 6 compilation. Keep the explicit coroutine-support Swift 5 exception;
removal is not qualified. This review changes no producer, app API, dependency,
generated source or compiler setting.

## Executed tuple

| Input | Selected value |
| --- | --- |
| Mobi base | `dc23db0a26f38da78d1fc85f38567fe6c7f41733` |
| Kotlin Toolchain | `0.13.0` |
| Kotlin/Native and standalone exporter | `2.4.20`, matching versions |
| Application kotlinx.coroutines | `1.11.0` |
| Exporter-only IntelliJ coroutines runtime, IOS-10 | `1.8.0-intellij-13` |
| Xcode | `27.1` (`27A9275`) |
| Apple Swift | `6.4`, `swiftlang-6.4.0.34.1` |
| SDK / compilation target | iPhoneSimulator `27.1` / `arm64-apple-ios26.0-simulator` |
| Configuration | Debug, the actual eight-module app/test export graph |

The producer compiled the real shared KLib inputs and generated their bridges.
No sample application or copied substitute API was used. Both producer runs used
the same installed JDK 25 and existing Toolchain caches; cold provisioning was
not assessed.

## Compilation results

Run from the repository root with the selected JDK in `JAVA_HOME`:

```sh
ruby scripts/ios/build_swift_export.rb --strict-support
ruby scripts/ios/build_swift_export.rb
```

| Check | Result |
| --- | --- |
| Full producer, `--strict-support` | Exit 1 in `KotlinRuntimeSupport`: `KotlinError.wrapped` stores non-Sendable `KotlinBase`; the import diagnostic refuses the warnings-as-errors build. It stops before coroutine-support compilation. |
| Unchanged producer recipe | Exit 0: one Kotlin archive and all eight Swift modules built. Existing warnings remain; this is a compilation control, not full app/runtime qualification. |
| Isolated runtime support, Swift 6 with warnings-as-errors | Exit 1, reproducing the same sendability/import diagnostics. |
| Isolated coroutine support, Swift 6 with warnings-as-errors | Exit 1: the unused `error` binding in the cancellation catch is rejected before later ownership diagnostics. |
| Coroutine support, Swift 6 without warnings-as-errors, diagnostic control only | Exit 1 with five ownership errors: the mutex's `inout sending` value, sending the continuation result, and closures passed to cancellation handlers and `Task`. |

The isolated trials replayed the corresponding `swift-KotlinRuntimeSupport` and
`swift-KotlinCoroutineSupport` arguments from
`build/swift-export/Debug-iphonesimulator/commands.json` after the unchanged build.
They set `-swift-version 6`, added `-warnings-as-errors`, and redirected
`-emit-module-path`, `-o` and `-module-cache-path` to private temporary output.
They retained `-emit-module -emit-library -static -parse-as-library`, the actual
generated source, bridge headers, package name, SDK, target and import checking.
The coroutine trial imports the unchanged runtime-support module from the
baseline Package. Omitting warnings-as-errors only exposes later diagnostics;
it is not an accepted replacement recipe. No source was patched or suppression
added, and no baseline artifact was overwritten by the isolated trials.

Generated Swift source SHA-256:

| Module | Digest |
| --- | --- |
| `KotlinRuntimeSupport` | `3cf1d7fb7b1177a62400397dc94f8207ada3b26a955c09594def8ab8ee620560` |
| `KotlinCoroutineSupport` | `883cec935c34af1380ca1e59a5e78af498349cb152c79aeb6878216fc097dc04` |

No native tests, app link/launch, Release/device build or signed-delivery claim
follows from these compilation checks. A complete strict graph was unavailable,
so removing the exception and qualifying its runtime behavior was not attempted.

## Upstream review

Reviewed all six [implementation documents at Kotlin
`77d8d7a1a193`](https://github.com/JetBrains/kotlin/tree/77d8d7a1a193e011140ec00e92328aec93ab2dd7/docs/swift-export)
and at the selected [2.4.20 release,
`890ac1d94fdb`](https://github.com/JetBrains/kotlin/tree/890ac1d94fdb80eb85f0eeb5be5e4352df987b2f/docs/swift-export).
Each document has identical content at those two revisions:

| Document | Git blob SHA |
| --- | --- |
| `README.md` | `fd64dd62fd08dcef0e907c0dd64f163199a0f6af` |
| `architecture.md` | `10ca74580f22569ec064d26b88d4166a891c419d` |
| `compiler-bridges.md` | `d21eec159d3d58d17e3a69e279a08c07e8468fb3` |
| `language-mapping.md` | `549910c2e1dc5943ee641a5fd92645dbb365aae5` |
| `standalone_execution_model.md` | `5da148d43394e2ae3a72fb52a514bcbb43a1303b` |
| `testing-usr-stability.md` | `c3936ef79a46ffcaa9623a95209196fe9d04debe` |

The README still warns about unstable standalone APIs and documentation lag.
The language-mapping document still excludes suspend functions, while the
[published guide](https://kotlinlang.org/docs/native-swift-export.html) documents
async/Flow support. This preserves the source-freshness gap recorded on
2026-10-18; neither document establishes strict Swift 6 support. The retrieved
guide HTML has SHA-256
`70ba12efe269546ef4df2068f5bc027b4d38a71d05deeb20c9eb1a61c6958996`.

The [official sample at
`654a686070c0`](https://github.com/Kotlin/swift-export-sample/tree/654a686070c07e293679f1c24136be73562df7a1)
now selects Kotlin **2.5.0-Beta2**, versus 2.4.10 in the previous review, and keeps
coroutines 1.11.0. Reviewed its README, version catalog, shared build file,
`CoroutinesView.swift` and CI workflow. Its build adopts the new `export.swift`
DSL and Swift-package integration. Its consumer distinguishes cancellation for
loads/countdown, but still has silent Flow catches. Its CI builds Apple tests
and runs separate Swift-package tests. No sample build was executed here; those
Gradle integrations do not qualify Mobi's Toolchain producer or strict support.
The sample's Beta notice applies to its 2.5.0 track; Mobi remains on 2.4.20.

### Specific removal issue

[KT-90266](https://youtrack.jetbrains.com/issue/KT-90266), “Swift Export: make the
generated Swift sources compile in the Swift 6 language mode,” was **In Progress**
on this review, last updated `2026-10-15T13:31:25Z`, with no planned or available
version recorded. Its description covers the same coroutine ownership error
families and `KotlinError` sendability warning. This is a verified diagnostic
match, not evidence that a fixed release exists. It also records upstream's
temporary Swift 5 package-language pin. Related
[KT-90263](https://youtrack.jetbrains.com/issue/KT-90263) concerns the manifest
tools version; that change alone does not resolve language-mode errors.

The issue pages required JavaScript, so their public issue API supplied the
descriptions and status/version fields. Rechecked
[KT-64572](https://youtrack.jetbrains.com/issue/KT-64572),
[KT-80305](https://youtrack.jetbrains.com/issue/KT-80305),
[KT-80970](https://youtrack.jetbrains.com/issue/KT-80970) and
[KT-80971](https://youtrack.jetbrains.com/issue/KT-80971): all are Fixed, with
availability respectively in 2.2.20-Beta2, 2.4.0-Beta2 and 2.3.20-Beta1 for the
last two. Those milestones do not close KT-90266. No upstream issue was published.

## Recheck and removal

On Kotlin/exporter, coroutines, Swift or Xcode updates, review KT-90266 and its
actual available version, then rerun the existing support probes and full
`--strict-support` producer. A sample update or Fixed issue alone is insufficient.
Require full generated-code compilation with warnings-as-errors, without patches,
suppression or fallback. Then remove only the coroutine Swift 5 selection in the
actual producer and run the existing native Home/Nearby success, typed-failure,
cancellation/retry, late-result and one-runtime checks plus normal iOS test/build
gates. Record the new tuple and outcome beside that removal diff.

IOS-02 remains separate: stricter generated support alone does not qualify
Mobi's preconcurrency service captures or Nearby's unchecked state crossing.
The sample's new integration is a future IOS-10 review input, not an adopted
Toolchain path. Neither workaround is retired by this review.
