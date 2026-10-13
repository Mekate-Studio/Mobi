# Native Home/Nearby Swift export qualification

Review scope selected on 2026-10-13: qualify native Home and Nearby first.
This begins the next qualification stage; it does not select a production
language profile, repository policy, runtime budget or diagnostic disposition.
The main app retains its direct integration and existing Shared UI flow.

## Selected experiment

The experiment uses `coroutine-swift5`, `main-confined` and `--compose disabled`.
These preserve the previously measured native configuration while testing a new
source provenance boundary. Swift 5 is confined to coroutine support; other
generated modules, aliases and the native app use Swift 6.

The published source is PR [#37](https://github.com/Mekate-Studio/Mobi/pull/37),
commit `5d1eb007023b8cff51c46e5bbf116dc90b190087`. It is published on the PR branch
and has not been merged to `main`. A fresh SSH clone of that branch contains
796 tracked files and no working-tree changes. No ignored local build products
or assessment deliveries were copied into it.

The selected native source identity is
`574afcd0a0267309d1dac0f82ad64df59e852c30239ec10dbfc1b9f7fb6ca3ef`;
compiler tuple identity is
`99e0154c84e3a30547119f9b77efef277ee21526e8391dac81348dddb9ee6324`.
Both match the earlier native qualification. The installed tuple remains
Swift 6.4, Xcode/SDK 27.0, Kotlin 2.4.20 and JDK 26.

Settings remain explicit experiment inputs: four parent reservations, two native
jobs per owner, one inactive Compose job limit, 20 ms polling and 50 ms failure
backoff. The embedded 500 ms shutdown observation setting is currently unused
by shipping code. Shutdown controls exercise explicit 0 and 5 second deadlines;
they do not qualify a 500 ms app budget.

## Qualification record

| Evidence track | Status |
| --- | --- |
| Earlier native working-tree cold and guarded replay | Passed; see the [pilot evidence](swift-export-app-pilot-evidence.md) |
| Published PR commit, fresh clone and matching native input inventory | Verified |
| Fresh-clone native cold original/reordered app phases | Passed; run `c8af5ccc8f3c492a566db30f5dd3b477`, 9 tests per phase, zero failures/skips on iOS Simulator 26.5 |
| Fresh-clone post-cleanup guarded replay | Passed; run `7049ce54df450950561b1d77a16358f4`, 9 tests per consumer phase, zero failures/skips on iOS Simulator 26.5 |
| Normal hosted Android/iOS tests, debug builds, quality and aggregate PR gate | Passed on the same commit; [run 38289075242](https://github.com/Mekate-Studio/Mobi/actions/runs/38289075242) |
| Dedicated Swift-export pilot on hosted runners | Pending; normal hosted jobs use the direct default |
| Physical device and minimum runtime | Pending; the existing pilot recipe targets the arm64 simulator |
| Fresh authenticated advisories and risk dispositions | Pending |
| Signed release and production default | Separate qualification and review |

The fresh-clone command uses the [existing pilot guide](swift-export-app-pilot.md)
with `--action test --profile coroutine-swift5 --repository-policy main-confined
--compose disabled`, a settings record created from that clone's inspection and
`--experimental`. Each cold phase rebuilds Kotlin/export/native products, builds
original and relocated consumers, and runs the real client and UI tests.

Guarded replay must use a retained, hash-verified delivery from the passed new
origin. Recovery must prove quiescence and remove the disposable origin work
before replay. Replay rebuilds Swift/app consumers with retained Kotlin/native
products; it does not repeat cold native production. The selected replay input
is the retained original-enum delivery. Its two consumer phases do not regenerate
the reordered Kotlin archive.

Both cold phases and both replay consumer phases passed eight client/lifecycle
controls and one real UI test each. Xcode's result summaries report nine passes,
zero failures and zero skips per phase. All 796 published file hashes and modes
were unchanged after execution, and the original clone remained clean. Both
runs proved resource quiescence and removed their disposable work. Complete
deliveries, raw test results, emitter logs and hash-bound receipts were retained
before cleanup. The resulting verdict is `checks_passed_review_required`.

Local provenance, settings, logs and retained receipts are stored under ignored
`.maintenance/native-home-nearby-qualification-20261013/`. Tool/bootstrap and
publisher operations may use host caches. This is a fresh published-source
checkout on the installed host, not a hermetic or hosted-runner qualification.
The final local report is `final-report.json` in that store; the published source
manifest, inspection, explicit settings, phase summaries, recovery and cleanup
receipts are kept alongside it.

The next missing execution boundary is the dedicated native-only pilot on a
hosted runner. Its repo-owned setup must declare compatible Xcode/SDK, Ruby and
JDK inputs, derive experimental settings from the runner's own inspection, and
retain failure evidence as well as successful cold/replay receipts. Ordinary
direct-app hosted checks do not exercise this exporter or its alternate app.

The opt-in `Native Swift-export qualification` workflow checks out the PR head
when the `swift-export-native` label is present. Its repo-owned entry is
`./scripts/ci/run_job.sh ios-swift-export-native-qualification`, under locked
Bundler dependencies with `MOBI_SWIFT_EXPORT_RUBY` set to Ruby 4.0.6 and
`JAVA_HOME` set to JDK 26. Selected Xcode must satisfy the existing
Swift 6.4/Xcode 27.0/Simulator SDK 27.0 contract. No native build caches are
restored by this lane.

The pilot lane uses the `xcode-27` public-preview image. GitHub's
[runner announcement](https://github.com/actions/runner-images/issues/14404)
documents that separate image and its iOS Simulator 27 runtime; `macos-26`
carries the Xcode 26 line. The hosted experiment explicitly selects simulator
major 27, bound into delivery inputs and guarded replay. It fails preflight if
that runtime is absent. Local pilot commands default to major 26; an explicit
`--simulator-major 27` selects the hosted experiment's runtime contract. This
provides additional-runtime evidence and does not qualify the deployment floor
or change the main app's runtime/default paths. Image-preview limitations remain
part of the review record.

The command writes `.maintenance/native-hosted-qualification/report.json`,
both cold deliveries, four available test bundles and summaries, and bounded
run journals/results/step diagnostics. The workflow retains that directory
for 90 days even on failure, as a mode-preserving `evidence.tar.gz` plus the
readable report. Extract the archive before verifying delivery receipts.
An incompatible host, incomplete tests or cleanup
refusal cannot produce a passed report. Failed disposable work is retained on
the runner, and the report discloses that it is excluded from the artifact.
Changed helper inputs require fresh receipts; the local receipts above qualify
the earlier commit only. Hosted status remains pending until the actual report
and test/cleanup evidence have been inspected.

The first executed hosted attempt at `d3e8ebf`,
[run 38421602488](https://github.com/Mekate-Studio/Mobi/actions/runs/38421602488),
passed Apple/JDK/runtime preflight and Kotlin production/export. Locked native
package checkout verification and the independently downloaded MapLibre
checksum also passed. Xcode then refused four macro targets at its enablement
gate, before native compilation; no app tests, reordered phase or replay ran.
The outcome is incomplete/inconclusive, with positive failure recovery and
disposable work retained on the runner. Its source-bound archive is retained
as failure evidence, not a qualified delivery.

The producer now creates approvals only for ComposableArchitectureMacros,
CasePathsMacros, DependenciesMacrosPlugin and PerceptionMacros at their exact
locked and verified checkout revisions. Those records live in the disposable
phase home; `CFFIXED_USER_HOME` keeps Foundation/Xcode home lookup there. A
read-only Foundation probe verifies that home and refuses an inherited
`IDESkipMacroFingerprintValidation` bypass. It does not use `-skipMacroValidation`, alter
developer preferences, suppress warnings or accept dependency risk. Missing,
duplicate or changed locks and escaping approval paths refuse before approval.
The actual approval records and their hash are retained in step diagnostics.
Historical local runs do not establish this new macro-enablement control;
fresh hosted execution must validate the changed helper inputs.

The macro-fix attempt at `49ee375`,
[run 38427585849](https://github.com/Mekate-Studio/Mobi/actions/runs/38427585849),
verified both phases' locked macro approvals with the skip preference false.
Both native production and consumer builds passed. The original phase passed
all 9 tests on iPhone 18 Pro / iOS Simulator 27.0; its complete 354-member
delivery and immutable receipts were retained and independently verified.
The reordered phase passed all 8 client tests, then its composite UI scenario
crossed Xcode's one-minute execution allowance. Its assertions completed at
about 70 seconds, but XCTest restarted the runner and the 1,300-second outer
phase check eventually timed out. The result is inconclusive, not compatible;
replay did not run. Failure recovery reached quiescence; work remained on the
runner and the incomplete result bundle is retained.

The UI scenario now explicitly requests a 180-second **harness** ceiling.
Its existing individual assertion waits sum to 90 seconds before XCUI launch,
idle and background overhead. Client tests retain the 30-second default, and
all functional assertion waits, phase/outer deadlines and experimental app
settings stay unchanged. This is not an approved app-latency threshold.
Partial-bundle summary failures are now phase retention findings; they preserve
earlier passed evidence and the original execution reason. These changed
inputs require another complete cold/replay hosted run.

## Boundaries for later app integration

Native adapters synchronously start and poll Kotlin jobs on Main, copy checked
wire values into Swift values, and await only native polling/cancellation seams.
They do not currently call the generated Swift async/error bridge. The
non-Sendable wrapped Kotlin error and generated coroutine API inheritance
findings still need their own dispositions; this narrower call path does not
establish safety for broader bridge use.

Main confinement allows suspended repository operations to overlap. The current
simulated repository updates its snapshot index without suspension after its
delay. New background callers, repositories or graph access require another
[caller/cohort audit](swift-export-pilot-cohort.md).

Before a later default change, preserve the main app's Shared UI flow with the
same Home service and a single Kotlin delivery, or obtain a separate decision
to change that flow. Native-first qualification does not authorize silently
removing Shared UI or mixing independent Kotlin deliveries.
