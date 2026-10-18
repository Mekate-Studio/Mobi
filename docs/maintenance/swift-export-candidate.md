# Optional Swift export candidate

This candidate is an isolated maintenance path over Mobi's actual shared Home,
Nearby and Compose behavior. The direct app builder remains the development
baseline. The retired iOS Gradle bridge is not a prerequisite. Kotlin Toolchain
still owns delegated Android Gradle/AGP bootstrap.

Kotlin Swift export is Alpha. The custom producer uses the standalone exporter;
it does not claim supported Gradle-free Toolchain integration. See the
[upstream guide](https://kotlinlang.org/docs/native-swift-export.html).

## Prerequisites and declared inputs

The initial diagnostic recipe targets Apple Silicon, Xcode 27.0, its iOS
Simulator 27.0 SDK, Swift 6.4, an available iOS 26 simulator runtime, JDK 26,
Ruby 4.0.6 with `xcodeproj` 1.28.1, and network access to the declared publishers.
Ruby and JDK installations are supplied locally; their executable/release
identities are recorded. The Xcode and Swift executables, SDK settings and JDK
module image are bound into execution identity. This is a measured installed
compiler tuple, not historical Swift 5 compiler or library-evolution evidence.

The [versioned descriptor](../../scripts/maintenance/swift-export-inputs.json)
declares source/module closure, generator and facade sources, Kotlin 2.4.20 and
Toolchain 0.13.0, publisher checksums, compiler flags, wire schema, SwiftPM lock,
native sources/resources and explicit diagnostic limits. Package inputs include
authored `Package.swift` and `Sources`, never an existing `.build` directory.
Missing/unknown selections, invalid closure and symlink/escaped paths refuse.

| Explicit profile | Generated language modes | Native/alias mode |
| --- | --- | --- |
| `coroutine-swift5` | KotlinCoroutineSupport=5; other generated modules=6 | 6 |
| `generated-swift5` | All generated modules=5 | 6 |

Both remain available. Each command also requires `main-confined` or
`shared-operation-mutex`. Kotlin Main confinement covers every caller/resumption
of the exact Nearby repository; it permits suspended operations to overlap.
The second option uses one cohort mutex around each complete operation on
Default. A client-local lock or Swift actor annotation cannot establish it.

## Inspect and rehearse

Provide disk headroom for both fresh phase caches and retained deliveries.
Disk exhaustion leaves qualification incomplete. Preserve partial evidence,
recover interrupted runs with `recover RUN_ID --stop --store swift-export`,
and clean only positively quiescent disposable resources. Retained deliveries
and reports are separate from disposable build caches.

Run from the repository root, using the installed Ruby executable:

```sh
ruby scripts/maintenance/swift_export.rb inspect \
  --descriptor scripts/maintenance/swift-export-inputs.json \
  --profile coroutine-swift5 --repository-policy main-confined

ruby scripts/maintenance/swift_export.rb rehearse \
  --descriptor scripts/maintenance/swift-export-inputs.json \
  --profile coroutine-swift5 --repository-policy main-confined \
  --java-home "$JAVA_HOME"
```

Repeat rehearsal for both profiles and both policies. Each owned run compares
the actual original and reordered Nearby enum source graphs. It downloads the
pinned exporter, compiles the harness/project/facades and joint archive, builds
locked native dependencies and host macros through Xcode/SwiftPM, verifies the
MapLibre publisher checksum, assembles a relocatable source/archive delivery,
and freshly compiles and runs the diagnostic Swift 6 app. It also exercises
the native executor seam and failed-driver backoff in typed Foundation stubs.

Executor/RunStore bind source, plan, execution files and output hashes. Recovery
owns process groups, tagged JVMs and nonce-named simulator resources. Historical
bridge adapters are not called. A failed baseline remains unqualified; preserve
its receipt before repair/retry. Inspect `.maintenance/runs-swift-export/` for
the run result and phase `candidate-report.json` files. Run creation does not
change app/default/release wiring or approve diagnostics.

Fresh owned roots contain no assessment binary seeds. Publisher/tool bootstrap
may consult host caches, which is disclosed in provenance. Source/archive
replay uses retained native objects/macros built for the recorded compiler;
this is explicit warm native reuse, not a SwiftPM binary-distribution promise.

## Ownership, transport and limits

The fixture has one single-scene parent lifetime, an exact shared Home service
for native and Compose peers, a declared Nearby repository cohort, a finite
parent admission pool, route owners and parent-owned drains. Teardown retires
routes; ordinary tab/background changes do not. Retirement closes business
admission while metrics/cleanup remain available. Named wire mappings have an
explicit version and reject unknown tags; native payload values are copied on
MainActor before suspension. The raw synchronous Store client requires Main;
`SafeExecutor.swift` provides explicit async hops for foreign callers.

Descriptor values are diagnostic settings, not production fallbacks. Parent
native-request/Compose-route reservations and actual per-owner Kotlin job
reservations have separate accounting. Excess work rejects before backend
registration. Cancellation restores/fences caller delivery while a drain owns
unfinished work. Only actual completion releases leases. Soft shutdown reports
`stillDraining`; cancelled acknowledgement waiters do not cancel cleanup.
Finite counts do not bound noncooperative duration, memory bytes or fairness.
Polling observations do not establish a production energy or hard-latency budget.

## Publication and collection

Registry objects are exact-inventory, hash-verified source/archive/native
closures. One local lock serializes expected-generation publication, reader
registration and collection. A reader keeps one object for its whole build;
publication of a new generation cannot change its package. ABA publication
advances generation. Missing/changed/unexpected/executable-mode or symlink
members refuse reuse. This is a cooperating local same-filesystem protocol,
not distributed writing or universal power-loss durability.

Persistent registries require explicit logical storage and minimum-age values:

```sh
ruby scripts/maintenance/swift_export.rb registry-create \
  --registry /absolute/owned/parent/registry \
  --logical-bytes 4294967296 --minimum-age-seconds 604800
ruby scripts/maintenance/swift_export.rb publish \
  --registry /absolute/owned/parent/registry \
  --delivery /absolute/retained/delivery --expected-generation 0
ruby scripts/maintenance/swift_export.rb collection-report \
  --registry /absolute/owned/parent/registry > /absolute/report.json
ruby scripts/maintenance/swift_export.rb collect \
  --registry /absolute/owned/parent/registry --report /absolute/report.json
```

The numbers illustrate the descriptor's diagnostic settings. Publication itself
does not qualify a package. Collection rechecks the exact report under lock and
refuses stale/uncertain state. Active objects, live/crashed/uncertain reader
pins, explicit holds/evidence and retained-run references stay protected.
Retention expiration does not remove pins. Reader recovery requires positive
process-group and RunStore resource quiescence. A missing/malformed run reference
refuses collection. Protected bytes exhausting the budget refuse publication;
collection is never an automatic eviction fallback. Logical payload size is
not an APFS physical-disk quota or an evidence-retention budget.

## Retain, clean and replay

Copy the complete sealed `delivery-source` outside disposable run resources
before cleanup. Verify it with `verify-delivery --delivery PATH`. Inspect recovery
and cleanup before applying cleanup:

```sh
ruby scripts/maintenance/dependencies.rb recover RUN_ID --store swift-export
ruby scripts/maintenance/dependencies.rb cleanup RUN_ID --store swift-export
ruby scripts/maintenance/dependencies.rb cleanup RUN_ID --apply --discard --store swift-export
```

Explicit discard removes disposable work after positive quiescence, while
retained evidence remains. Run evidence stays under the execution policy
(success seven days, failure fourteen days, evidence at least ninety days).

After recovery reports quiescence and original disposable resources are removed:

```sh
ruby scripts/maintenance/swift_export.rb replay \
  --descriptor scripts/maintenance/swift-export-inputs.json \
  --profile coroutine-swift5 --repository-policy main-confined \
  --java-home "$JAVA_HOME" --delivery /absolute/retained/delivery \
  --origin-run ORIGINAL_RUN_ID
```

Replay verifies cleanup, package hashes, the original compiler tuple and a
hash-bound passed origin receipt containing that exact delivery, then
recompiles generated Swift sources/aliases and freshly builds/links/runs the app
in new owned workspaces. Original producer paths cannot satisfy this gate.

## Review and later adoption

See the [implementation review](swift-export-candidate-review.md) for measured
scope, preserved failures and requested diagnostic dispositions.

Generated and runtime diagnostics carry emitter/input/message/location
fingerprints, not a count allowlist. Compiler errors and native Swift 6 warnings
fail. Coroutine inheritance remains an unresolved compatibility gate; opt-ins
do not establish safety. Cast/target diagnostics, generated Swift warnings and
MapLibre/SwiftUI runtime findings require tuple-specific dispositions. Unknown
findings keep the assessment `review_required` even when named behavior checks
pass.

The build-maintenance role owns descriptors, exporter/compiler upgrades,
diagnostic dispositions, registry recovery and replay evidence. Native
architecture maintainers own facade/lifecycle semantics and app wiring. The
accountable maintainer is **Jorge Castro**. The opt-in real-app pilot is described in [its command guide](swift-export-app-pilot.md). No production profile,
repository policy, numeric setting or risk disposition is selected here.

A [separate adoption patch](swift-export-adoption-plan.md) must name that owner and approved settings, cite the
exact source/tool/delivery identities from fresh receipts, and scope real app/CI
wiring. Its content rollback must include the repaired direct content snapshot documented in the pilot guide, including the approved SwiftSyntax and Perception pins and matching project constraint. Historical revision `50ae26e4a40c3bc83fe10a2ad05645088330aa63` alone does not reproduce that repaired baseline. Hosted,
physical-device, minimum-runtime, Android parity, release/signing and fresh
advisory gates are independent. Local simulator success grants no credentialed
delivery, dependency-risk or default-switch permission.

Protocol controls:

```sh
ruby scripts/maintenance/test_swift_export.rb
ruby scripts/maintenance/test_swift_export_registry.rb
ruby scripts/maintenance/test_swift_export_resources.rb
ruby scripts/maintenance/test_swift_export_packaging.rb
ruby scripts/maintenance/test_swift_export_origin.rb
```

The registry suite uses owned processes, killed writers/readers and synthetic
packages to test storage safety. It is not native app qualification.
