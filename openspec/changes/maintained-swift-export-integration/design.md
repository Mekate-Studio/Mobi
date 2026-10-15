## Context

See [the proposal](proposal.md) for motivation. Mobi's current direct framework/projection path remains the development baseline. Shared Kotlin owns business state; native TCA/SwiftUI own presentation; optional Compose uses the exact Home service supplied by the native composition root.

The measured custom producer emitted twelve generated modules, bridge/runtime interfaces and one joint Kotlin archive. Both named profiles passed on the installed Swift 6.4 compiler using Swift language modes 5 and 6. A complete generated-source/native delivery passed local writer interruption, generation fencing and post-cleanup consumer replay. These observations establish a candidate on a measured tuple; they do not establish supported Toolchain integration, SwiftPM binary distribution, historical Swift 5 compiler compatibility or a maintained clean-clone path.

The [official Swift export guide](https://kotlinlang.org/docs/native-swift-export.html) still calls the feature Alpha and documents a Gradle Xcode task. The proposed custom generator therefore owns compatibility with its declared exporter/runtime tuple. Kotlin's documented Default dispatcher for exported async calls does not establish repository confinement from Swift actor annotations.

## Goals / Non-Goals

**Goals:** Provide a small optional, reviewable producer/consumer contract that can be rebuilt from public source, carries its full input identity, preserves native ownership and makes failures and unresolved review gates visible.

**Non-Goals:** Selecting a production Swift profile, repository policy or numeric runtime limits; changing default app/build/release paths; reintroducing the retired iOS Gradle bridge; making power-loss, general reclamation or binary-distribution promises. The candidate compares policies and reports evidence without performing adoption.

## Decisions

### 1. Implement an opt-in maintenance adapter before app integration

The proposed entry point is `scripts/maintenance/swift_export.rb`, with library logic under `scripts/maintenance/lib/swift_export/` and public-source fixtures under `scripts/maintenance/fixtures/swift-export/`. These are proposed paths. Reuse the existing Executor/RunStore/Recovery ownership and source binding; keep CI calls thin. Candidate invocations require a descriptor and a profile explicitly. Inspection and rehearsal commands cannot alter the app builder or production source.

A standalone public guide will describe required Apple Silicon/Xcode/SDK/runtime, Ruby/JDK and declared compiler inputs. It will give reproducible owned-workspace commands and distinguish installation/provisioning from warm reuse. Assessment-specific absolute paths or prepared ignored products are not prerequisites. Existing historical bridge-only experiment adapters must not be reused without accounting for their bridge preconditions.

Alternative: fold the generator into the normal Xcode phase immediately. Rejected for the candidate because errors would affect the current development baseline before compatibility and lifecycle contracts are qualified.

### 2. Carry both Swift language profiles explicitly

| Profile | Generated module language modes | Aliases/native consumer |
| --- | --- | --- |
| `coroutine-swift5` | KotlinCoroutineSupport=5; every other generated module=6 | 6 with strict native warnings |
| `generated-swift5` | Every generated module=5 | 6 with strict native warnings |

The recommended first integration candidate is `coroutine-swift5`, because it limits the language-mode accommodation to the observed support boundary while retaining Swift 6 checking elsewhere. This is a review recommendation, not a selected default. `generated-swift5` stays fully supported by the candidate matrix. Neither profile repairs Kotlin coroutine inheritance or grants historical compiler/library-evolution compatibility. A change to compiler/module/target inputs invalidates the prior tuple's qualification.

Alternative: use all generated modules in Swift 6. The measured support isolation failure prevents advertising that configuration as passing; retain its failure as a compatibility finding.

### 3. Keep complete input identity and native package ownership

A versioned descriptor binds source content and module dependency/visibility closure, facade/wire schemas, generator/harness code, exporter and publisher bytes, Kotlin/native runtime and compiler plugins, JDK/compiler identity, target/minimum/CPU/features, SDK/Xcode, Swift module modes and command flags. Bind native source selection, resolved SwiftPM revisions, publisher binary checksums, host macro identity, plist/icons/resources and reviewed diagnostic fingerprints as consumer inputs. Content identity is separate from local paths; changing content at the same path must invalidate reuse. No secret values enter identities or receipts.

Kotlin generation owns Kotlin/export products. Xcode/SwiftPM continue to own native dependency resolution, macro builds and publisher binaries. The candidate assembler joins those declared cohorts into one complete delivery, preserving their provenance separately. Initial maintained qualification builds from source/locked publisher inputs rather than seeding from assessment products. Warm native product reuse is allowed only when explicitly reported and hash-verified.

Deliveries contain generated Swift sources, Kotlin/bridge/runtime interfaces, the joint archive, Swift 6 alias sources, module/profile/target metadata and the native consumer closure needed for the declared replay. Modulemaps/invocations are relocatable. Compiled Swift modules built during consumption are tied to that compiler and are not advertised as a distributable binary interface.

Alternative: publish whatever generated directory currently exists and infer dependencies from imports. Rejected because missing/stale members and undeclared archive/profile changes could produce a mixed delivery.

### 4. One local writer, generation fencing and pinned readers

Use a local same-filesystem registry with immutable content-identified objects, unselected staging directories and one monotonically increasing active generation. A cooperating writer holds the registry lock, verifies its expected generation, validates the exact complete inventory and atomically replaces one pointer. Missing, malformed, corrupt or unknown inputs refuse before publishing. Interrupted staging/object installation retains the previous complete delivery; interrupted commit exposes a complete object. Returning to identical bytes still advances generation, preventing stale ABA publication.

A reader acquires the same registry lock while resolving the pointer and registering a resource-owned pin, then releases the lock and uses that object for its entire build. The writer can progress while an old reader is building. A later cache hit verifies all members before use. Corruption refuses consumption and is reported; reconstruction never silently legitimizes altered bytes. No symlink escape is permitted in payloads or state.

Alternative: a mutable shared output directory or multiple independent module pointers. Rejected because consumers could observe partial graph changes. Distributed/network filesystem writers and universal power-failure durability are outside this contract.

### 5. Conservative, explicit collection and maintenance responsibility

Jorge Castro is the accountable human maintainer, explicitly assigned during implementation review. The proposed build-maintenance role owns exporter/compiler upgrades, diagnostic dispositions, input descriptors, replay evidence, writer recovery and reader-aware collection. Native architecture maintainers own facade/lifecycle semantics and app wiring; Xcode owns native dependency production.

Collection is manual and starts with a report. Under the registry lock it excludes the active object, every positively owned reader pin, uncertain reader/writer ownership, held evidence and objects needed by retained run references. Run expiration alone never authorizes deleting a live/uncertain pin. Recovery must prove the owning process/resource is quiescent before removing a crashed reader's pin. A configured age/storage policy applies only to otherwise eligible objects. If the storage budget cannot be met without protected deletion, new publication refuses with a capacity report. Persistent evidence retention follows the existing execution policy; cache object retention is a separate declared setting. Reuse existing ownership verification rather than inventing time-only liveness.

This proposal tightens the rehearsal's retain-all diagnostic policy; a collector/pin race is not yet measured. Collection must be rehearsed with readers/writers before adoption.

Alternative: automatic time-based eviction or unlimited production retain-all. Rejected because time does not prove a reader dead, and indefinite growth has no operational bound.

### 6. Preserve ownership, repository policies and transport invariants

An explicit app/session composition root owns the Home service used by native and Compose peers, the exact Nearby repository cohort, admission pool and drain supervisors. Route owners/Stores have route lifetime. Route teardown retires only its requests and transfers unfinished work to the parent supervisor. Tab changes and ordinary backgrounding are not retirement. Closed roots never reopen; a new parent lifetime gets fresh owners and capacity. The initial candidate declares single-scene scope; multi-scene ownership requires independent qualification.

Both repository policies remain runnable: Kotlin Main confinement for every caller/resumption, or one shared mutex around the complete operation on Default for every caller of the exact repository. Main confinement is the proposed first review candidate for the current simple reference repository. Suspensions can overlap; it is not operation serialization. The mutex option stays available when serialization is the chosen contract; slow/noncooperative holders can block peers. A per-client mutex or Swift actor annotation does not cover bypass callers. Audit all native/Compose/Kotlin entry points before choosing either policy.

Closed facade admission rejects all new business operations after retirement; cleanup and metrics remain usable. Named versioned wire tags replace ordinal dependence, reject unknown schema/tags and validate payloads. Native values cross the actor boundary after synchronous copying; generated wrappers do not survive a suspension. Foreign-executor calls must be prevented by the declared client API or have an explicitly tested safe path. The existing synchronous Store assumption alone is bounded evidence.

Cancellation separately restores matching native UI, fences obsolete delivery and transfers an unfinished request/resource lease to an app/session supervisor. Actual Kotlin completion permits exactly-once consume/forget and lease release. Copy failure after consumption releases the resulting capability without inventing an outstanding request. Cancellation, timeout and ARC observations never substitute for backend completion.

### 7. Make capacity, shutdown and UX configuration reviewable

| Setting/contract | Proposed requirement | Current numeric status |
| --- | --- | --- |
| Native request + Compose route reservations | Explicit finite parent limit; reserve before construction/begin; rejected admission performs no business work | Three is a diagnostic setting only |
| Kotlin work launched within a Compose owner | Separate explicit per-owner job admission; reserve atomically before registration/launch; release after actual completion | One is a proposed comparison candidate, unmeasured as an enforced Kotlin limit |
| Shutdown observation | Close admission and retire roots immediately; configured soft observation deadline returns `drained` or `stillDraining`; cancelled waiters do not cancel cleanup | Diagnostic deadlines do not select production values |
| Polling/backoff | Explicit scheduler/interval/backoff and budget observations; cancellation-safe drain polling without a cancelled-sleep spin | Two milliseconds is a diagnostic setting; production energy/latency budget unselected |
| Busy/closed presentation | Busy allows manual retry; no queued/automatic retry; duplicate/obsolete controls cannot create extra owners; closed disables new work | Bounded diagnostic UX pass; product policy unselected |

Route reservations must continue to be reported as coarse route capacity. A general Kotlin concurrency bound cannot be claimed until each relevant launch path has independently enforced admission. Rehearse Compose per-job capacity separately rather than relabeling the passing route tests. A cancelled or noncooperative job retains its resource accounting until actual completion, even after a shutdown observation timeout. Unbounded completion time remains possible; finite admission limits retained counts, not duration, memory bytes or fairness.

The candidate requires explicit diagnostic settings and records them. Production integration refuses until reviewed settings are present; it supplies no implicit production fallback values.

### 8. Diagnostics are compatibility contracts

Compiler errors fail. Native Swift 6 consumer warnings fail. Generated Kotlin/C++/Swift findings carry producer/target identity and location/message fingerprints; new or changed findings require review. Runtime findings have a separate ledger. Warning counts are observations, not an allowlist or an absence-of-risk claim.

Generated coroutine inheritance is an adoption-blocking unresolved compatibility finding until a stable pairing is demonstrated or a specifically scoped risk disposition is approved. The [coroutines annotation](https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines/-internal-for-inheritance-coroutines-api/) identifies inheritance as unsafe; an opt-in alone is not a compatibility fix. Cast/ignored target-feature findings and MapLibre inset/unbalanced SwiftUI appearance diagnostics also need explicit dispositions. Keep uncertainty visible; prohibit blanket warning/Sendable/isolation suppressions.

Alternative: pass whenever total warning count matches the prior build. Rejected because different emitter contracts or new warnings can have the same count.

## Risks / Trade-offs

- Custom exporter coupling → pin complete bytes/options, declare an accountable maintainer and requalify each relevant tuple change; preserve the existing direct path as content rollback.
- Reader/collector races → lock pin creation/collection consistently, refuse uncertain ownership and add held-reader, killed-reader and concurrent-writer controls.
- Noncooperative work retains drains indefinitely → finite explicit admission, honest `stillDraining` and separate latency/energy/retention review; never free active handles to satisfy a deadline.
- Route capacity is weaker than job admission → distinct metrics, specifications and controls for Kotlin launches.
- Warm dependencies conceal reproducibility gaps → require a maintained source-to-app clean-checkout qualification, disclose host-cache reads, then replay after owned workspace cleanup.
- Compiler/runtime/platform success is bounded → retain hosted, device, minimum-runtime, Android, release/signing and fresh advisory gates independently.

## Migration Plan

First implement the optional producer, immutable delivery validator, pin/collection protocol and isolated fixture matrix. Compare both Swift profiles and repository policies, including actual app behavior, retirement/wire/cancellation counterexamples and corruption/crash/collection controls. Build the maintained candidate from public source and declared inputs, then clean/replay it with the original work unavailable. Publish a review report distinguishing measured checks from external gates.

A later adoption patch requires named maintenance ownership, reviewed profile/repository/transport/runtime limits and diagnostic dispositions. It scopes actual app/CI wiring, records the exact source/tool tuple and preserves the complete prior content revision for rollback. It cannot infer approval for credentials, release delivery or dependency/security risk from a green candidate build. The current direct builder and delegated Android bootstrap remain the baseline during candidate work.


## Targeted assessment follow-up

Three additional prototype contracts now have bounded evidence: ownership-verified reader pins and report-first collection/storage refusal; per-owner job admission through the actual Compose Home owner's common launch path; and unchanged native-client executor assertions plus an async MainActor seam and cleanup-driver-error backoff in Foundation fixtures. Both Swift language profiles remain available. Diagnostic job limits one and two remain unselected for production. Controlled explicit references, logical storage, stubbed executor access and diagnostic Compose commands limit the respective observations.

The assessment returns to an integration decision now. The candidate scope is an optional single-scene Apple Silicon source-package route over the existing shared architecture. Maintained producer/reader collection integration and clean-checkout qualification remain implementation work. At proposal creation all 28 implementation tasks were pending; prototype passes did not complete them. Current implementation progress is recorded in tasks.md and the public candidate review. Named ownership, coroutine/diagnostic compatibility, language/repository choices and production budgets require review. Hosted/device/minimum-runtime/Android/advisory/release qualifications stay separate. Production adoption is deferred.
