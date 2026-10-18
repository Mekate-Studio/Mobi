# Swift export app pilot evidence

The opt-in real-app pilot completed **29/29 implementation tasks** with bounded
local checks passing. Jorge Castro is the accountable maintainer. The local
selection is `coroutine-swift5` / `main-confined`; production selection, numeric
limit acceptance, diagnostic dispositions and dependency-risk acceptance remain
pending. See the [command guide](swift-export-app-pilot.md).

## Final qualification

| Configuration | Fresh cold original and reordered-enum phases | Guarded post-cleanup replay phases |
| --- | --- | --- |
| Native-only / main-confined | `e0bd8290c14c2d94312197d7a93b912a` passed | `640b9b3cd8d89a31f1926600daff7995` passed |
| Compose-enabled / main-confined | `493ff8f786b988d30c189ea60f65c291` passed | `936e7ca357b428cd7a937e3e9841e2c8` passed |
| Native-only / shared-operation-mutex | `8706d52118cbcc7bd741804a391b8146` passed | Not required for the selected main-confined pilot |

Each phase ran eight client/lifecycle controls and one real UI test. Cold phases
rebuilt Kotlin/export/native products from the declared source closure, built
and packaged original and relocated consumers, and tested their actual app.
Replay rebuilt Swift/app consumers from retained source/archive and warm native
products after positive origin quiescence and complete disposable-work removal.
These are distinct evidence tracks. Sealed deliveries, test result bundles,
step logs and hash-bound receipts are retained locally.

A supplemental external UI driver also exercised the real Compose refresh
button and route return without modifying the shipping app or adding app test
hooks. Its separate shipping-source equivalence record accounts for the final
repository test-only navigation fix.

## Bindings and observations

Final report: `.maintenance/swift-export-app-pilot-implementation/final-report.json`.
Compiler tuple identity: `99e0154c84e3a30547119f9b77efef277ee21526e8391dac81348dddb9ee6324`. The installed tuple uses Swift 6.4,
Xcode/SDK 27.0 and Kotlin 2.4.20; observed simulator runtime is iOS 26.5.
Swift 6 native/alias and Swift 5 support-module modes qualify this installed
compiler only, with no historical-compiler or stable-binary-ABI claim.

Each `final-*-inspection.json` records complete selected inputs. Matching
`final-*-settings.json`, `final-*-*-measurements.json`,
`final-*-settings-with-observations.json` and scoped diagnostic/disposition files
bind source, tuple, settings and raw report/log hashes. Observation records were
checked with the versioned review schema; they remain experimental.

Main confinement observed two overlapping repository operations from two owners
sharing their root's exact repository. The shared complete-operation mutex
observed one. Cancellation, manual retry, stale response/cancellation fencing,
closed admission, unknown wire tags, owner-capacity refusal before registration,
empty retired registries and background/foreground survival passed. Native and
optional shared Home verified the same Home service instance.

Five real refresh timings per client phase provide small samples, not a tail
latency guarantee. State restoration differs from actual Kotlin job completion.
Registry counts describe logical retained requests/states, not heap bytes or
energy. The noncooperative cleanup control uses a typed native test-only gate
and does not qualify a real noncooperative Kotlin repository or device behavior.

Provisional settings are four parent reservations, two native jobs per owner,
one Compose job per owner, 20 ms polling, 50 ms failure backoff and 500 ms soft
shutdown observation. These are explicit experiment inputs, not accepted bounds.

Generated import/concurrency/cast/unused-value diagnostics and UIKit deprecations
remain `review_required`. Captured lines include diagnostic source context;
fingerprint counts are not counts of independent advisories. Records include
emitter, profile, target scope, message/location, rationale, reviewer status and
requalification triggers. No compiler/native warning policy was weakened.

## Preserved baseline and failed evidence

The repaired direct baseline restored all 740 inventoried file hashes/modes into
an owned copy and passed its raw build and twelve tests. Its earlier maintenance
wrapper refusal remains separate. Final content re-verification found no drift.
Rollback archive SHA-256: `d981ae411983b98cd8b10bcc83aaee1fd1814fdd0a5a968c625fb93d8bc040b2`; manifest SHA-256: `07bf8dbaa7b5f19a3c08e5f8c6788c83653f04efed43baab86c3ab80e4e8d5b1`.
The snapshot includes approved SwiftSyntax 603.0.2 / Perception 2.0.10 repairs
and the matching project constraint; historical HEAD alone is insufficient.

Failed attempts remain failed evidence. Native-only cancellation exposed omitted
locked atomicfu runtime/interop artifacts, now included with a contract control.
Replay exposed a missing library import, now loaded and covered by unsealed
preflight refusal. A location interruption consumed a Home-tab tap; the final
test verifies selection and retries that tap once without removing assertions.
The failed replay result/attachments are retained. A synthetic ownership-control
failure passed in isolation and the full unchanged contract suite passed on
rerun; the initial failure was preserved.

## Remaining decisions

Published clean-clone, GitHub-hosted, physical-device, minimum-runtime, Android
parity, fresh advisory and signed-release gates remain independently unqualified
for this pilot. Limit/disposition/default decisions require their separate
review. The direct default, retired iOS bridge boundary, delegated Android
bootstrap and public `studio.mekate.mobi` identity are preserved. No scheduler,
archive, commit, push, signed release or production default switch was performed.
