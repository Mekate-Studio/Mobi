# Swift export state-boundary comparison

Date: 2026-10-14. Status: isolated compiler assessment passed; D1 remains
review-required. Accountable maintainer: Jorge Castro.

**Proposed D1 direction:** consume compiler-generated `.sealedType()` state and
copy into native presentation synchronously on Main. The Home comparison also
copies directly into the existing native presentation type, removing the need
for a second handwritten Swift transport enum. Do not promote the pilot's manual
numeric tags/decoders or introduce a new schema generator for this path.

This is concrete evidence for a design review, not a production selection or an
integrated app qualification. The [decision queue](../../openspec/changes/production-swift-export-integration/decision-review.md)
retains separate async/lifetime, concurrency, build, risk and settings decisions.
The [machine-readable packet](evidence/2026-10-14-swift-export-state-boundary-review.json)
binds the inputs, compiler controls, log hashes and review patches.

## What was compiled

The checkpoint captures 816 tracked/nonignored working files and their full
modes at HEAD `1a8197051117004ec9247b309e61179a8b612422`, including dirty proposal
and review files. Restoring the complete content and modes into an owned copy
passed. Source identity is
`838582c15ecb31d1ee0bdaf9d422922be0547159a8d6ef0d89b2c847e898d170`.
The repaired native package lock and matching project constraint are included.

The local Apple/JDK tuple is
`a44ec744bb9333e3ec14ea5786aa9ce3e0db45a13246e74b61588070803ac97d`:
Swift 6.4, Xcode 27.0, simulator SDK 27.0 and JDK 26. It differs in bound bytes
from the hosted pilot tuple. Cached inputs were cloned into owned directories;
this was a warm compiler assessment, not cold qualification.

Actual current shared Core, Home and Nearby sources were compiled afresh into
Klibs using Kotlin 2.4.20 and the locked Metro/compiler inputs. The exporter
harness was rebuilt from the repository template with checksum-verified exporter
JARs. Each evolution rebuilt the affected Kotlin module and regenerated six
Swift modules. Coroutine support used Swift 5 mode; the other modules and native
consumers used Swift 6. Generated import checks were enabled; native consumers
used strict concurrency and warnings-as-errors.

The selected external Klib inputs include coroutines **1.11.0**, Metro 1.4.5 and
atomicfu 0.32.1. This is the descriptor-bound compiler comparison, not a new
attribution of the complete production dependency graph. Generated coroutine
inheritance and KotlinError diagnostics remain separate unresolved findings.

The generated code contains typed sealed enums for the real state families,
matching the [documented sealed-type mapping](https://kotlinlang.org/docs/native-swift-export.html#sealed-classes-and-interfaces).
The evidence here comes from Mobi compilation and controls, rather than treating
that documentation as proof of the custom integration.

## Evolution and omission controls

| Exercise | Observed result |
| --- | --- |
| Baseline Home/Nearby native copying | All state families compiled; fleet sequence, rider coordinates, vehicle identities/coordinates and load time copied into native Sendable values |
| Add Home `RefreshQueued` | The existing shared Kotlin `when` and unchanged Swift sealed-state switch failed until explicitly handled |
| Add Nearby `AwaitingPermission` | The real service's shared Kotlin `when` and unchanged Swift switch failed until explicitly handled |
| Rename Home's loaded payload `value` to `count` | The stale Swift read failed; using the regenerated property compiled. The diagnostic exposed the inherited NSObject `value` accessor as an incompatible function type, rather than a missing-member error |
| Rename Nearby `Unavailable` to `Offline` | The stale Swift case failed; using the generated case name compiled |
| Reorder Nearby enum and sealed declarations | The same native consumer compiled without edits; application code used named cases |
| Omit an existing Swift case | Compilation failed with an exhaustive-switch error |
| Store a Kotlin state wrapper in a Sendable struct | Swift 6 rejected the non-Sendable property |
| Existing Shared UI against changed Home | Missing new-case presentation and stale payload access failed; explicit source updates compiled |
| Android-authored Nearby presentation against changed state | Missing/renamed case handling failed; explicit source updates compiled |
| Existing visitor dispatch against new cases | Its Kotlin exhaustive dispatch failed for Home and Nearby; the direct workaround still needs its own additional adapter work |
| Existing native Home presentation | Its second-stage switch caught the new native value; direct generated-state copying into the presentation type also caught missing cases and payload changes |

There are 37 named compiler controls across the state and consumer assessments,
including positive baselines and expected failures. These are not app-runtime
tests. The Android-authored presentation file was compiled as pure common Kotlin
on the Native target; this does **not** qualify Android SDK/build/runtime parity.
Shared UI controls compiled its actual Compose source, not a running Compose app.

The hypothetical new cases exist only in owned assessment sources. Positive
native value controls retain distinct cases; the native Home presentation control
explicitly renders queued work with its existing loading presentation. That is a
compiler fixture choice, not approved shipping UX or a business-state change.

## Concrete maintenance cost

Start with the [Home typed-presentation patch](evidence/2026-10-14-state-boundary/home-typed-presentation.patch).
It replaces the presentation's consumption of the intermediate native transport
enum with an exhaustive generated-state switch and primitive/native copies. It
adds no visitor protocol, callback adapter, numeric registry or schema generator.
It is a review-only patch over the pilot source, not a complete app integration;
facade results, call sites, API membership and lifecycle still need D2 work.

The evolution patches expose the required edits:

- [Added Home case](evidence/2026-10-14-state-boundary/home-added-case.patch): shared state/helper, actual Shared UI presentation and native Home presentation handling.
- [Renamed Home payload](evidence/2026-10-14-state-boundary/home-renamed-payload.patch): shared model/helper, service construction, Shared UI field access and one native copy read.
- [Added Nearby case](evidence/2026-10-14-state-boundary/nearby-added-case.patch): shared state/service handling, Android presentation and the typed native-copy prototype.
- [Renamed Nearby case](evidence/2026-10-14-state-boundary/nearby-renamed-case.patch): shared state/service references, Android presentation and a native named-case switch.
- [Reordered Nearby declarations](evidence/2026-10-14-state-boundary/nearby-reordered.patch): Kotlin declaration order changes; the native consumer needs no edit in this compiler control.

Native presentation still requires handwritten meaning: what to show for a new
state and which values to retain. The compiler forces explicit case handling; it
cannot judge correct UX or insist that a newly added optional field be displayed.
This proposal reduces transport coordination, not all cross-platform feature
work. Folding value copying into presentation avoids the extra mirror enum for
Home; equivalent Nearby integration is still to be assessed in the actual app.

Generated enum bridges still contain ordinal conversion internally. The app
does not maintain its own ordinal mapping. Swift modules and native bridges must
come from the same verified delivery; successful named-case typechecking does
not establish runtime reorder behavior, stable ABI or version-skew safety.

## Holds and next check

The rollback build/test preflight remains incomplete: Foundation reported
`IDESkipMacroFingerprintValidation=true` even with the owned home and a private
plist requesting false. A process-argument probe read false, but Xcode rejected
that preference option. Those attempts are retained; no global preference was
changed, and no rollback app build/test success is claimed.

The subsequent [D2 comparison](swift-export-ownership-review.md) demonstrates a
closed native module, synchronous typed result copying and 32 macro-free
Home/Nearby simulator cases across polling and completion notification. It
covers domain failure, cancellation and noncooperative cleanup in that prototype;
actual app/Shared UI wiring, production membership and resource measurements
remain pending. Generated broader suspend/Flow/error APIs remain held.

Stale delivery/mismatch and malformed-input controls, full app linking/runtime,
production Shared UI, actual Android qualification, minimum-runtime/device work,
dependency/risk/diagnostic decisions, measured settings and fresh hosted evidence
remain separate gates. The current [risk review](swift-export-production-risk-review.md)
is not an accepted exception for the changed production graph.

Earlier assessment setup errors included missing common-source flags, an output
directory, diagnostic spelling/accessor expectations and an overly broad service
patch anchor. Corrected controls were rechecked; retained command outcomes were
reused only after matching arguments, outcomes and log hashes. They are not cold
replays. Raw sources, outputs, drivers, patches and logs remain in ignored
`.maintenance/production-state-boundary-20261014T144747Z/`.
