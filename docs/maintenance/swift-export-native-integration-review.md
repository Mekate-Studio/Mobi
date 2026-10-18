# Provisional native Home and Nearby integration

Date: 2026-10-15. Status: `review_required`. The maintainer selected Native
Home/Nearby as the first qualification scope; Shared UI follows separately and
remains required before final adoption. The default app still uses its existing
membership. The [draft candidate PR](https://github.com/Mekate-Studio/Mobi/pull/38)
is the place to assess this implementation before accepting D1–D6.

## Code to review

[NearbyStateCopy.swift](../../ios-app/interop/nearby/NearbyStateCopy.swift) switches
exhaustively over compiler-generated location, snapshot, overlay and reason cases.
It constructs the actual map scene, messages and overlays directly. The pilot's
numeric tags, nullable wire payload combinations and parallel native transport
variants are absent from this candidate. Kotlin retains ownership of refresh,
freshness and location transitions. Domain failures receive specific native retry
messages; admission and boundary failures have separate reducer fields and keep
the previous map visible.

[NearbyRequestOwner.kt](../../shared-ios-export/src/NearbyRequestOwner.kt) retains
the original typed Kotlin state behind per-owner handles. Its request completion
uses the same [registry](../../shared-ios-export/src/RequestCompletion.kt) as Home.
[NativeNearbyAccess.swift](../../ios-app/interop/nearby/NativeNearbyAccess.swift)
validates owner identity and liveness before each synchronous call. It releases
replaced or unclaimed handles and transfers cancelled work to the existing
independent drainer; capacity is released after actual completion.

[NativeAppServices.swift](../../ios-app/interop/NativeAppServices.swift) replaces
the Home-only factory name. Both native routes share its private, real Metro
composition, parent admission pool and cleanup supervisor. Nearby uses the exact
hub's policy-wrapped service. The generated service accessor is available only
on the private side of the closed native module; the shell cannot import it or
choose the DI graph's unguarded service. Kotlin/Compose callers still require
separate policy audit and qualification.

## Maintenance choices still under review

- **Module placement:** both actual TCA reducers and views are provisionally in
  `MobiNativeFeatures`. Compare a smaller adapter-only module exposing native
  presentation values before accepting the final arrangement. Native TCA
  dependencies remain normal imports for macros/conformances; generated Kotlin
  imports remain implementation-only.
- **State ownership:** Nearby needs original Kotlin states for subsequent
  transitions. Opaque handles, pending-result adoption/discard and release-on-
  replacement are additional machinery beyond Home's scalar input. Review
  whether this cost is acceptable, including the stale/cancelled response paths.
- **Route lifetime:** the shell retains native routes and explicitly retires
  them when their navigation owner ends. Tab/background changes preserve them.
  Independent drain tasks retain unfinished work without retaining the route.
- **Failure presentation:** shared domain failures now have specific native
  messages; boundary/admission failures preserve the last map and allow retry.
  Internal cleanup assertions remain invariants, not malformed-input recovery.
- **Build ownership:** the local assessment uses the earlier verified locked
  native products and warm model Klibs. Promoting its recipe into the existing
  repo-owned producer/gate is still required. The retained assessment inputs
  are evidence, not candidate regression membership in CI.

## Evidence and limits

The [combined source-bound receipt](evidence/2026-10-15-swift-export-native-slice.json)
records the exact candidate source hashes, compiler recipes, installed app hash,
raw runtime case set and owned simulator cleanup: **42 checks passed**, binding
32 candidate source files and verifying 258 reused native product hashes. The real Home checks are
retained alongside Nearby map/reducer controls. Import controls continue to
refuse raw Kotlin imports and private composition access. The hidden-layout
control passes without the checker and fails with it; the fully strict Swift 6
coroutine-support alternative still refuses compilation.

Nearby controls cover typed location/fleet presentation, all blocked-location
reasons, temporary loss with retained map, domain failure/retry, freshness,
foreign/released handles, single adoption and unclaimed disposal, stale reducer
responses, invalid native input, noncooperative drains after route retirement,
shared Home/Nearby capacity, and a separately injected visible boundary failure.
Invalid native coordinates/time and an injected client error do not qualify
malformed Kotlin payloads, generated-output skew or immutable delivery checks.

The assessment-owned tab app also exercises the actual composition's Home
service and Nearby repository with a simulated rider coordinate. The default
Home repository deliberately fails 35% of requests; the composition control
accepts its expected success or repository-domain-failure result and records the
observed value. Controlled fixtures separately assert deterministic success,
failure and retry. The first composition attempt incorrectly required random
success; it is retained as incomplete rather than counted as a passing run. Simulator-only
location permission is pregranted; this does not qualify the permission prompt
interaction, real-device accuracy behavior or actual deployment-floor runtime.
The screenshot shows the native map and rider/vehicle markers. Basemap tile
completion is not asserted; the captured background is plain. External tile/
network availability and offline behavior remain unqualified.

Shared UI same-service/one-delivery qualification, complete cohort controls,
production cold/reordered/relocated replay and hosted candidate execution,
selected dependency/advisory refresh, generated bridge findings, settings and
resource measurements, rollback build/tests, Android parity, device and runtime
floor evidence remain open. The prior Home commit's ordinary hosted CI passed;
its skipped pilot workflow does not qualify this changed candidate. Final design
acceptance, dependency-risk disposition, default switching and merge remain
separate decisions in the [production change](../../openspec/changes/production-swift-export-integration/tasks.md).
