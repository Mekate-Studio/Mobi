# IOS-14 Home repository recheck — 2026-11-06

Base: `f979f50990a3251dd0429e847d58a3419aa8a23d`, the merged Beta2 update.
Its source tree matches `8e003a43a5505daca3d1a9830f8f8617a865bf36`, qualified
by [CI #579](https://github.com/Mekate-Studio/Mobi/actions/runs/42197342446).
The selected tuple remains Toolchain 0.13.0, Kotlin/exporter 2.5.0-Beta2,
Metro 1.5.0 and coroutines 1.11.0; local Xcode is 27.1 / Swift 6.4.

## Actual maintained-code change

Home's existing tests now construct a Swift `KotlinBase, CounterRepository`
double with an immutable `Result<Int32, any Error>`. Success returns 21; an
ordinary Swift error exercises Kotlin's `Unexpected` policy. This is normal
test support, not a new application client, state flag or error adapter.

The failure matrix checks the real Kotlin service's typed state first, then the
real native client. A thrown service error cannot silently pass by being mapped
by the client's generic fallback. Both zero and retained counter values remain
covered. Shared UI composition still uses the injected Home service. Existing
Swift Task cancellation, Kotlin-origin cancellation/retry and uncaught Kotlin
error tests remain.

Delete `successfulHomeService`, `unexpectedFailureHomeService` and the nullable
`homeService(failure:)` branch factory from the Kotlin fixture. Keep the direct
typed repository-unavailable fixture. The fixture file and its native-runner
registration remain because Kotlin-origin controls and Nearby still use them.

The two test files add 40 lines and remove 24 before documentation/registry
changes. The extra Swift double and direct-service assertions are visible test
cost; this is a partial workaround simplification, not a total line-count reduction.
Application source and shared error policy are unchanged.

## Typed-error boundary and deferred decision

The current producer exports `MobiCore` privately/transitively. Its generated
API exposes `CounterRepository`, but not `CounterRepositoryException`.
Compiling a normal Swift construction/throw of that exception against the actual
baseline modules exits 1 with `cannot find 'CounterRepositoryException' in scope`.

A one-line test typealias to that existing exception makes it reachable, but the
actual exporter then produces nine modules, adding `KotlinStdlib`. The producer's
unchanged module-graph guard refuses that candidate before native packaging.
The alias is removed. The observed cost is a ninth Swift binding module; the
expanded graph's runtime packaging and behavior have not been qualified.

Keep the typed Kotlin fixture until a dedicated export-surface change proves its
replacement worthwhile. Recheck on Kotlin/Toolchain/Swift updates under IOS-14;
do not bypass the graph guard or introduce another exception factory to declare
the workaround removed. Normal delivery remains eight Debug Swift modules and
one Kotlin archive. Release continues to exclude test support.

## Source review and qualification

- The official [Swift repository implementation sample](https://github.com/Kotlin/swift-export-sample/blob/654a686070c07e293679f1c24136be73562df7a1/spm-consumer/Tests/SwiftExportTests/SwiftImplementationTests.swift)
  uses direct `KotlinBase` inheritance and an async interface implementation.
  Its current file has the same blob, `cc8ef493b021576d0fc5adad9ebec9e7c88f7ddb`.
  No extra Kotlin base class is needed for this app's measured case.
- The [official guide](https://kotlinlang.org/docs/native-swift-export.html)
  documents async/reverse import, but its inheritance example uses a Kotlin
  superclass. Implementation mapping docs still omit async and restrict class
  mappings. Current implementation README, mapping and execution documents have
  blobs `fd64dd62fd08dcef0e907c0dd64f163199a0f6af`,
  `549910c2e1dc5943ee641a5fd92645dbb365aae5` and
  `5da148d43394e2ae3a72fb52a514bcbb43a1303b`. Those documentation gaps do not
  replace actual module and runtime checks.
- The real iOS suite passed with the Swift doubles before the unused Kotlin
  helpers were deleted. It qualified success, direct-service/client failure
  meaning, previous values, composition, cancellation/retry and existing native
  lifecycle checks. The normal export checks confirmed eight Debug modules,
  one runtime and complete/omitted-case switch contracts.

Final source-bound local and hosted results after helper deletion are recorded
in the implementation PR. No 2.4.20 runtime comparison was run for these Swift
double outcomes, so this record does not claim Beta2 introduced the capability.
The typed exception's full reverse identity remains unqualified in the retained
graph. Warning cleanup, Nearby fixture removal, strict support, device behavior
and signed delivery remain separate.
