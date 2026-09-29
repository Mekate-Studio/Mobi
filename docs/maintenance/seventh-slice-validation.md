# Seventh slice validation

Status: locally validated and ready for review; not committed or adopted. This slice adds manual compatibility assessment and rehearsal through the existing public workflow. Production dependency pins, bridge default, app/test targets, release paths and schedules remain unchanged.

The [public receipt](evidence/2026-09-29-slice-7.json) retains seven run identities, outcomes, source/runner/plan hashes, capability cells, command-log hashes, native test names and recovery/cleanup results. The [command guide](compatibility-runner.md) explains how to reproduce the profiles. Slice 6 is already integrated as `ff7146e9cad15a26ae3824a2eca192f0ec6b3684`; [all seven hosted jobs passed](evidence/2026-09-28-slice-6-integration.json).

## Compared tuples

| Profile | iOS Kotlin/Native compiler | Metro | SKIE | Bridge Compose declaration |
| --- | --- | --- | --- | --- |
| Retained bridge baseline | 2.3.20 | 1.1.1 | 0.10.12 | 1.9.0 |
| Retained bridge candidate | 2.4.10 | 1.4.4 | 0.10.14 | 1.9.0 |
| Direct facade candidate | Toolchain 0.12.2 path (2.4.10) | 1.1.1 | Absent | Bridge absent; Toolchain owns Compose |

All runs use Toolchain 0.12.2 in the workspace. The direct experiment retains the production Metro tuple. Its result cannot be combined with the bridge upgrade to claim an untested direct Metro 1.4.4 combination. Sources were reviewed on September 27–28; nomination reads that dated snapshot, not a live search for the newest releases.

## Verified facts

### Native capability results

The native comparisons ran on Apple Silicon macOS with Xcode 27 and owned iOS 27.0 simulators, using the `PullRequest` test plan. They do not add iOS 26 runtime evidence. Macro trust validation is explicitly skipped by the existing native rehearsal policy; package macros still compile and execute during builds. The receipt records these settings.

| Evidence track | Baseline | Candidate | Meaning |
| --- | --- | --- | --- |
| Bridge KLIB compile + framework link | Passed | Passed | Actual simulator framework linking, beyond the old compile-only task. |
| Bridge full mobile | All four jobs passed; 12 native Swift cases | All four jobs passed; 12 native Swift cases | The nominated bridge tuple passes the bounded local comparison. |
| Direct typed facade full mobile | All four jobs passed; 12 native Swift cases | All four jobs passed; 12 native Swift cases, bridge absent | Toolchain 0.12.2 can build and test these current native consumers with the recorded facade experiment. |
| Direct SKIE | Source review | Missing prerequisite | No reviewed supported standalone configuration/Swift-processing integration. |
| Direct Swift export | Source review | Missing prerequisite | The reviewed Gradle examples do not establish standalone Toolchain emission/embedding. |

The full bridge run took 764.540 seconds for its baseline and 877.422 seconds for its candidate. The final direct comparison took 729.054 seconds for its baseline and 619.834 seconds for its candidate. These are local observations, not performance benchmarks.

The final direct candidate uses a typed Kotlin visitor and Swift projections in a disposable copy. It preserves the existing Home and Nearby native test sources, app/test target identities, scheme and test plans. Both exported Kotlin enums have explicit Swift aliases preserving consumer spelling. The build copy has no `gradle-bridge/` or stale products; it reaches `shared-di` through the Toolchain module graph and uses the documented Xcode integration phase. It does not add SKIE or adopt Swift export. Expected authored inputs are checked before and after commands, and IDE build skipping is disabled.

Direct compiler/link work is exercised through the iOS jobs. The separate `native_library_compile` and `framework_link` cells remain `not_attempted` for that candidate: the report does not relabel integrated app evidence as separately executed narrow commands. The retained bridge's DI result refers to the Toolchain graph; its own flattened source sets compile DI independently.

### Failures retained and investigated

| Run | Recorded result | Diagnosis / response |
| --- | --- | --- |
| `3aeaac29bca2b088802d3f423817236f` | Narrow bridge comparison passed | Separate KLIB compile and actual framework link passed for both tuples. |
| `d240e0dcd2dc98e9b14192ae5f6f77c5` | Inconclusive infrastructure failure | Receipt generation read the Unicode wrapper as US-ASCII under the executor C locale. Explicit UTF-8 decoding and a byte-exact locale regression fixed this. No native commands had run. |
| `19ff3b41d177e3dc52d20049285286af` | Full bridge comparison passed | Both tuples passed Android/shared tests, Android debug build, 12 native Swift cases and iOS debug build, as well as compile/link. |
| `db17288a1311ad8e899405ffb1bf727d` | Direct candidate incompatible after passing baseline | Swift compilation exposed an Objective-C visitor selector collision and enum constant spelling differences. A unique `onSnapshotLoaded` method and explicit Rider enum aliases corrected the experiment. |
| `312afa8bd2cd84d70d6ce009ea1ea799` | Direct candidate incompatible after passing baseline | App compilation passed; the unchanged native test target exposed the remaining map-failure enum alias. Both map-failure aliases were added. |
| `e362b0ccd1b1c10b76b2c3d4f260638d` | Refused during baseline | The native resource guard could not prove ownership of a live PID found through the private Gradle registry. No direct candidate ran. Recovery confirmed quiescence. The offending identity was not retained, so the precise cause remains unconfirmed; future refusals now retain that private diagnostic and still send no signal to unproven processes. |
| `db2a171343360da0c10f92a29a8505bb` | Full direct comparison passed | Fresh baseline-first comparison with the final facade and ownership diagnostic. |

The two Swift compile failures describe the bounded experiment patches, not a general Toolchain incompatibility. Their original receipts remain failures; later success does not rewrite them. Before the last full run, the complete facade also passed `swiftc -typecheck` against the real direct framework header for `arm64-apple-ios26.0-simulator`; that narrower receipt alone was insufficient for native acceptance.

Contract testing also exposed a common process-shutdown race: an earlier nonempty process snapshot could be followed by an already-exited supervisor. The fix accepts only a confirmed empty group and never sends KILL after losing leader ownership. A deterministic regression and 100 real TERM interruption checks passed. This is separate from the Gradle ownership refusal above.

### Validation and cleanup

- All 164 contracts passed: 35 quality, 27 validation, 23 inventory, 28 executor, 22 Kotlin, 13 support-policy and 16 compatibility contracts. The Kotlin suite includes the retained ownership-refusal diagnostic and verifies the unrelated process remains alive.
- All five pinned static analyzers passed. Strict OpenSpec validation passed all 12 current items. Diff whitespace checks passed.
- All seven runs have verified reports, quiescent recovery and completed owned-workspace cleanup. Step evidence and logs remain retained; failed runs were not rewritten or resumed as successes.
- The reporter verifies the result/journal/check/evidence/log digest chain. Missing phase evidence, omitted hashes, altered referenced files, missing required cells or absent direct isolation proof cannot produce a passing report. Technical results retain `adoption_authorized: false` and retirement `defer`.

Earlier native runs retain their original code/source bindings. In particular, the passing bridge comparison predates the final receipt-reader and shutdown refinements; the final direct comparison uses the final runner, facade and ownership diagnostic. Documentation and this public receipt are written after native execution releases its source binding. The normal staged integration gate and hosted CI for slice 7 have not run; slice 6's hosted pass is not attributed to these uncommitted changes.

## Untested assumptions and limits

Passing simulator jobs do not establish physical-device execution, release archives, signing/export packaging, cold hosted direct builds, incremental direct builds or rollback behavior. The rehearsal uses fresh owned homes/caches and source copies on an already prepared host; it does not prove clean-clone onboarding on a new machine.

Compose UIKit code compiles through the app/framework path, but reducer tests do not exercise interactive rendering or resource behavior. DI reachability and successful compiler/plugin consumers do not replace a dedicated negative factory-generation fixture. Cancellation/lifecycle behavior, generic export, complete Kotlin/Compose release-interval review, advisory review and complete bridge target dependency graphs remain unproven.

The facade demonstrates a possible architecture, with extra maintained interop surface. Any adoption needs architecture review, including ADRs 0003 and 0006, plus the missing capability evidence. No observed pass authorizes bridge retirement or changes the user's dependency adoption policy.

## Blockers and next work

Direct SKIE lacks a reviewed supported standalone Toolchain configuration/Swift processing pipeline. The reviewed Alpha Swift export documentation still demonstrates Gradle integration and does not establish standalone Toolchain emission/embedding. These are source-bound prerequisite gaps, not reproduced compiler failures.

The historical execution store's host-ownership mismatch remains protected; this work only recovers the newly owned slice 7 stores. The single Gradle ownership refusal has a retained outcome and successful recovery, but its root cause remains unconfirmed. No ownership rule was relaxed to get a passing build.

Slice 7 can be reviewed as a manual evaluator while adoption and retirement remain separate future decisions. Slice 8 can consolidate the existing compatibility caller around this evidence without adding a schedule. Before a bridge upgrade is proposed for adoption, complete its release-interval, dependency-graph and advisory review; before a direct-default proposal, close the additional native/package/clean-clone/rollback gates.
