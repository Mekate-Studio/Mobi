# Swift export ownership comparison

Date: 2026-10-15. D2 status: **`review_required`**. Accountable maintainer:
Jorge Castro. This is an isolated design assessment; shipping membership,
defaults and dependency-risk dispositions are unchanged.

The candidate passed **32 runtime checks** across real Home and Nearby Kotlin
services in an owned simulator harness. Both polling and completion notification
preserved cancellation fencing and independent cleanup. The proposed D2 choice
is **payload-free completion notification, synchronous Main-confined result
copying, and a closed native Swift module**. This is now concrete enough to
review alongside [D1's state-evolution patches](swift-export-state-boundary-review.md).
It does not yet qualify the actual app or Shared UI.

## What feature authors would maintain

Kotlin remains authoritative for feature state and transitions. The proposed
facades return the generated Home/Nearby state types, replacing the pilot's
handwritten numeric feature tags and nullable payload tables. A generated enum
describes request lifecycle; it does not duplicate feature variants.

Only the boundary module imports the generated modules. Its Main-confined code
reads completed state synchronously and copies primitives into native presentation
values before returning through an async API. Home copies into its existing
presentation type, as in D1. The Nearby prototype copies a fleet snapshot into
an assessment presentation type; production must integrate the existing Nearby
presentation and helpers without adding a second transport registry.

Ordinary feature edits still require explicit native presentation meaning. They
should not require an additional visitor, numeric tag or decoder entry. Listener
registration and draining are generic request infrastructure, independent of
the number of feature variants. Their maintenance cost still needs acceptance.

## Observation and ownership

The Kotlin facade registers `Job.invokeOnCompletion` and returns a disposable
subscription token. The Swift callback carries no Kotlin state, error or wrapper:
it only signals and finishes a buffered `AsyncStream<Void>`. Swift resumes on
Main, checks cancellation, reads the typed result and copies it synchronously.
Completion before registration is supported by immediate invocation and buffering.

The callback assumes no executor. It must remain nonthrowing, thread-safe and
fast; cancellation of a subscription is not a promise that an already executing
callback has stopped. Capturing only the continuation and a synchronized test
counter makes that race harmless here. These requirements follow the
[coroutines completion-handler contract](https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines/-job/invoke-on-completion.html).

When a caller cancels, it fences delivery and transfers the request, facade and
admission reservation to independently owned cleanup. Cleanup retains no route
client. It releases capacity only after actual backend completion and request
removal. A cancelled shutdown waiter or elapsed soft deadline does not cancel
cleanup. Retirement closes admission and fences late work; Nearby retirement
also clears its owned state handles.

The assessment compares the same lifecycle controls with polling and completion.
For one Home request held behind a controlled approximately 60 ms repository gate:

| Mode | Client result reads | Request-observation timer waits | Completion signals |
| --- | ---: | ---: | ---: |
| Polling | 12 | 11 | 0 |
| Completion | 1 | 0 | 1 |

These are fixture counters, not all bridge calls, CPU, energy, latency budgets
or memory-byte measurements. Shutdown observation still uses the repository's
wait loop. The 5 ms polling interval, capacity of one, listener limit of two and
fixture deadlines are experimental controls, not proposed production settings.

## Compiler and runtime evidence

The emitted native module and separate clients compile under Swift 6 strict
concurrency with warnings as errors. Client compilation has only the native
module search path, with no generated module paths or bridge module maps.
The host links private generated libraries through linker search paths. Controls
show that native Home and Nearby async clients compile, a copied Nearby value
can cross a detached task, raw imports fail with `no such module`, a public
Kotlin type leak fails, and the facade is absent from the client module interface.
This is compiler enforcement in the prototype, beyond a source import scan.

The 32 runtime cases comprise 11 Home and five Nearby cases per observation mode:

- Home: typed success and domain failure; completion before subscription;
  cancellation before admission; owner-independent cancellation drain; capacity
  retained while work is live; cancelled observation waiter; noncooperative late
  completion rejected and released; retirement; the repository shutdown
  coordinator's soft deadline and cancelled acknowledgement waiter.
- Nearby: typed fleet and domain failure; negative time refused before backend
  admission; owner-independent noncooperative cleanup; retirement clearing handles.

The coordinator uses the existing admission, polling, drain and settings sources;
its only assessment adaptation replaces its concrete drainer type with a native
metrics protocol. Backend fixtures are deterministic gates around the real
feature services, not production repositories. The runtime driver checks the
exact case set and raw result, then terminates and deletes only its owned
simulator; deletion was verified.

## Concrete review material and binding

The [structured evidence](evidence/2026-10-15-swift-export-ownership-review.json)
records all 36 successful or expected-refusal command outcomes and log hashes,
32 runtime case names, source/tool bindings, artifact hashes and remaining gates.
The source checkpoint contains 824 files at HEAD
`1a8197051117004ec9247b309e61179a8b612422` plus the existing uncommitted review
documents. All 460 existing non-documentation inputs were verified unchanged
against that checkpoint after the experiment.

Review the actual assessment bytes:

- [Home facade patch](evidence/2026-10-15-ownership/home-typed-completion.patch)
  and [Nearby facade patch](evidence/2026-10-15-ownership/nearby-typed-completion.patch).
- [Compiled native boundary and lifecycle cases](evidence/2026-10-15-ownership/NativeOwnership.swift.txt),
  [Home fixture](evidence/2026-10-15-ownership/Scenario.kt.txt),
  [Nearby fixture](evidence/2026-10-15-ownership/NearbyScenario.kt.txt), and
  [shutdown adaptation](evidence/2026-10-15-ownership/shutdown-drain-reader.patch).
- [Macro-free scene host](evidence/2026-10-15-ownership/App.swift.txt),
  [Home consumer](evidence/2026-10-15-ownership/ClosedClient.swift.txt),
  [Nearby consumer](evidence/2026-10-15-ownership/closed-nearby-async-client.swift.txt),
  [raw-import refusal](evidence/2026-10-15-ownership/RawBypass.swift.txt),
  [private-facade refusal](evidence/2026-10-15-ownership/private-facade-access-refused.swift.txt),
  and [public-type-leak refusal](evidence/2026-10-15-ownership/LeakedBoundary.swift.txt).
- [Recorded command recipe](evidence/2026-10-15-ownership/command-recipe.json),
  with explicit path placeholders and setup dependencies. This is a warm
  assessment recipe, not a new production command or clean-clone onboarding path.

The local tuple is Swift 6.4 / Xcode 27.0 / SDK 27.0 / JDK 26, Kotlin 2.4.20,
coroutines 1.11.0, Metro 1.4.5 and atomicfu 0.32.1. It reuses hash-verified D1
Core/Home/Nearby Klibs after checking their current sources. The typed facades,
generated modules, joint native archive and native boundary were rebuilt.
`KotlinCoroutineSupport` uses Swift 5; other generated modules and native clients
use Swift 6 with the active `CheckImplementationOnly` recipe. Deployment target
is simulator iOS 26; execution used iOS 27. This is not cold, relocated-replay,
minimum-runtime, physical-device or hosted evidence. Installed app bytes were
not independently hashed; the produced app and retrieved runtime JSON were hashed.

Retained failed attempts include a test fixture's `release` selector colliding
with NSObject, an unsupported simulator type, and a legacy host refused because
SDK 27 requires a scene lifecycle. They produced no passing runtime evidence.
The corrected scene host was rebuilt and rerun. Additional control-driver syntax
and diagnostic expectations were corrected before their results were accepted.
Raw inputs, drivers, logs, failures and binaries remain under ignored
`.maintenance/production-d2-20261015T120617Z/`.

## Critical costs and the next decision

1. **A separate Swift module becomes part of the build contract.** Its production
   target membership, native type visibility, implementation-only imports and
   restricted consumer search paths need deterministic gates. Putting raw paths
   back on the app target would invalidate the closure evidence. Feature code
   must not acquire a second representation solely to cross this module.
2. **The project owns listener lifetime and cleanup.** Registration, cancellation,
   disposal, immediate completion and parent-owned draining need shared code and
   regression controls. The prototype's fatal assertions, test-only factories,
   fixed location and internal boundary error are not a finished public app API.
   Production needs explicit native admission/boundary failure handling.
3. **The broader generated bridge remains a separate finding.** Generated coroutine
   inheritance and `KotlinError` Sendable diagnostics were not repaired or silenced.
   The closed client does not prove whole-binary unreachability. Upstream bridge
   repair and diagnostic disposition remain D4/D5 responsibilities.

The recommendation for review is D1 generated typed state plus D2 completion
notification and a closed native presentation boundary. Polling remains the
comparison baseline; a repaired upstream async bridge has not been qualified by
this experiment. Deferral remains valid if the additional module/lifetime cost
is unacceptable. No maintainer selection has been recorded.

Review-cadence update, 2026-10-15: the maintainer authorized provisional integrated
implementation so these costs can be judged through actual app code. The
[Home slice and composition review](swift-export-composition-review.md) follows
that direction. Record final acceptance or rejection in the
[decision review](../../openspec/changes/production-swift-export-integration/decision-review.md)
before production/default adoption; candidate wiring may proceed for evaluation.
D3 must assess actual Native/Shared UI composition and repository overlap; D4
must make the compiler and membership recipe reproducible in production. Delivery
skew, malformed payloads, actual app/TCA flows, Android, platform evidence and D6
measurements remain pending. October 13 advisory data must be refreshed for D5.

The direct rollback build/test remains held: Foundation still reports macro
validation skipped in the owned home. This harness has no package macros and
does not change that preference or clear that hold. Nothing was staged, committed,
pushed or switched to production by this assessment; PR #37 remains the unmerged
pilot reference.
