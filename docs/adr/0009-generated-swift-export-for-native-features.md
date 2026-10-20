# ADR 0009: Generated Swift export for native features

Status: Proposed for review with the actual app integration.

## Decision

Native Home and Nearby consume Kotlin 2.4.20 Swift export together. Kotlin
Toolchain 0.13.0 compiles and resolves the KLib graph. Xcode's existing app and
test targets call `scripts/ios/build_swift_export.rb` to generate Swift APIs,
compile the Kotlin bridges into one static archive and compile the Swift modules.
Native Swift packages and application identity stay under the existing Xcode project.

Shared Kotlin retains the state algebra, repositories, refresh and failure policy.
Home still returns its native counter value from the client. Nearby still retains
its original shared state. Both now switch on compiler-generated `sealedType()`
cases, without handwritten visitors or default branches. This replaces ADR 0008's
visitor mechanism; it does not add request registries or change feature behavior.

`shared-ios-app` exposes composition factories and a typed UIKit entry point.
AppServices passes the same Home service to its native client and Shared UI.
Compose implementation dependencies are linked into the same Kotlin archive, not
exported as a second public feature API or loaded as a second Kotlin runtime.

## Costs and review decisions

- **IOS-10:** the standalone exporter API and the Toolchain task-record reader
  are custom build integration. A normal JVM tool module owns exporter dependencies;
  its explicit IntelliJ coroutines runtime prevents analysis-worker exceptions.
  Delete replaced machinery when supported Toolchain integration passes the same
  app, cold-build and delivery checks. Keep delegated Android bootstrap.
- **IOS-07/08:** generated implementation-only imports need the compiler's
  `CheckImplementationOnly` check, and generated coroutine support uses Swift 5.
  The app uses Swift 6. `--strict-support` makes strict generated-support compilation
  an explicit update check; it never selects a fallback automatically.
- **IOS-02:** existing preconcurrency service imports and Nearby's unchecked raw
  state sendability remain. Generated Swift service classes expose non-Sendable
  capture warnings. This PR does not qualify compiler-checked service ownership.
  Replacing those boundaries needs its own measured isolation change; no new actor
  assertions, unsafe service conformances or cancellation relays are introduced.
- **IOS-14:** live-client repositories move from Swift stubs to Kotlin test sources.
  The selected reverse async bridge wraps Swift errors as `SwiftException`, losing
  the typed Kotlin repository exception needed by the existing characterization.
  Production error interpretation is unchanged. Remove this restriction when a
  native stub round-trip preserves the tested failure and cancellation meanings.
- **IOS-15:** test-only state constructors compensate for internal generated
  nested case aliases. Remove those factories when ordinary nested constructors
  compile publicly. Do not patch generated code or depend on mangled class names.

Debug delivery includes the Kotlin test-support KLib in the same archive; the
hosted test bundle links only its Swift test-support module. Release excludes the
fixture KLib and module. Test scheduling remains governed by IOS-13.

## Rejected mixed delivery

The selected compiler/runtime controls did not qualify generated Home alongside
unchanged Objective-C Nearby in one framework. A common exported prefix appeared
to work for separate calls with runtime assertions disabled, but combined imports
conflicted over KotlinBase definitions. Enabling runtime assertions aborted the
generated call with `Must be used in Swift Export only`. This bounded macOS
control is not an iOS app qualification. It rules out adopting that workaround;
the actual app instead migrates both API boundaries with Swift export enabled.

An additional `--runtime-assertions` app probe aborts in Compose accessibility
initialization when Kotlin calls `class_addProtocol`. The maintained build keeps
the [baseline runtime-assertion setting](https://github.com/JetBrains/kotlin/blob/v2.4.20/kotlin-native/backend.native/compiler/ir/backend.native/src/org/jetbrains/kotlin/backend/konan/NativeSecondStageCompilationConfig.kt#L135). This diagnostic mode is an explicit
recheck on Kotlin/Compose updates; compilation or a normal launch does not prove
that the fully asserted Compose graph works.

## Source and update review

Review the [published guide](https://kotlinlang.org/docs/native-swift-export.html),
[selected release implementation docs](https://github.com/JetBrains/kotlin/tree/v2.4.20/docs/swift-export)
and [current implementation docs](https://github.com/JetBrains/kotlin/tree/master/docs/swift-export).
The guide describes sealed cases and async export; the implementation mapping
notes lag some of those features. Actual selected-compiler builds settle the
app's contract. Also inspect the [official sample](https://github.com/Kotlin/swift-export-sample)
and use [KT-64572](https://youtrack.jetbrains.com/issue/KT-64572) as an issue-discovery
entry point, not evidence that a particular Mobi limitation is fixed.

The workaround registry identifies update triggers and removal checks. A release
lead requests review; it does not authorize removal or declare these probes passed.
