# Provisional native integration

This directory contains the first Home slice of the proposed Swift-export
integration. It is application feature code for review, with no separate app
entry point. The default Xcode/Toolchain app membership still uses `src/`.
Final design acceptance and default adoption remain pending.

The candidate build compiles `home/` into `MobiNativeHome`. Its normal native
dependency is `MobiIOSDependencies` (TCA, Dependencies and MapLibre). Generated
Kotlin modules are implementation-only imports on the private side of the
module. A shell receives `NativeHomeServices` and `NativeHomeRoute`, constructs
the route's controller and retires the route when that navigation owner ends.
Tab changes or backgrounding do not by themselves end ownership.

## Read these files first

- [HomeCounterLoadable.swift](home/HomeCounterLoadable.swift): the existing native
  presentation model now copies generated Kotlin state directly. This is where
  a new shared state acquires its native presentation meaning.
- [NativeHomeAccess.swift](home/NativeHomeAccess.swift): completion observation,
  synchronous Main-confined copying and cancellation transfer. No feature tag
  decoder or additional native transport enum sits between it and presentation.
- [RequestCompletion.swift](home/RequestCompletion.swift): generic notification
  and independent draining; this is supporting code the project must maintain.
- [HomeFeature.swift](home/HomeFeature.swift): actual TCA loading, response,
  cancellation, retry and retirement handling. Boundary/admission failures have
  their own presentation fields; Kotlin domain failures remain domain state.
- [NativeHomeServices.swift](home/NativeHomeServices.swift): the provisional
  composition root uses the actual Metro-backed Kotlin composition. Factory and
  route APIs expose native types; Kotlin services do not escape to the shell.

The Kotlin side is [HomeRequestOwner](../../shared-ios-export/src/HomeRequestOwner.kt)
and its [completion registry](../../shared-ios-export/src/HomeRequestCompletion.kt).
Neither changes shared business transitions or the authoritative state algebra.

## Review points

The native TCA dependency is deliberately a normal import. TCA macros and
conformances cannot all be implementation-only under the active checker. The
consumer therefore needs native dependency products, while raw Kotlin module
paths and bridge module maps remain private. Importing a generated module from
the shell must continue to fail. That is the supported closure claim, not
whole-binary unreachability or a repair of the generated coroutine/error findings.

During review, compare an actual added state/payload across Kotlin and this
presentation, and inspect the omission failure. Then inspect how much generic
listener, admission and cleanup machinery remains. Code passing runtime tests
does not decide whether those costs are acceptable.

These Home files temporarily coexist with the direct and pilot implementations
while the candidate is evaluated. They are intended to replace those paths in
the single adopted app, not establish a permanently maintained second app. Nearby,
Shared UI, complete composition identity, production build orchestration and
final consolidation remain work in the
[production change](../../openspec/changes/production-swift-export-integration/tasks.md).
