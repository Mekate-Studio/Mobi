# Provisional app composition and build review

Date: 2026-10-15. Status: `review_required`; candidate implementation is
authorized for evaluation, with final acceptance pending. The agreed review path
is integrated Home code, then Nearby and Shared UI, followed by source-bound
qualification and explicit adoption. See the
[decision review](../../openspec/changes/production-swift-export-integration/decision-review.md).

## Actual code to review

The first feature implementation lives in [ios-app/interop](../../ios-app/interop/README.md).
The Home reducer, view, presentation and client form a closed native feature
module. It uses the real Metro composition and typed Kotlin request owner;
the default app membership is unchanged. The supporting completion registry and
independent drainer are visible source, rather than a hidden transport framework.

The [source-bound Home receipt](evidence/2026-10-15-swift-export-home-slice.json)
records **24 passing runtime checks** and 68 command outcomes. The TCA reducer
was exercised through loading, domain failure/retry, stale response fencing,
early/active cancellation, owner-independent noncooperative cleanup, visible
capacity denial/retry, retirement and a distinct native boundary failure. The
native module and shell compile with strict Swift 6 warnings as errors; raw
generated imports and private composition access fail compilation.

The installed executable hash matched the produced app. The owned simulator ran
iOS 27 and was deleted after the checks. Its
[Home screenshot](evidence/2026-10-15-home-slice/home-screen.png) shows the actual
SwiftUI Home view hosted by the new route. The
[assessment harness](evidence/2026-10-15-home-slice/HomeSliceAssessment.swift.txt)
and [Kotlin cohort fixture](evidence/2026-10-15-home-slice/CohortScenario.kt.txt)
are retained run inputs, not claims that candidate CI or production test
membership is already wired. The production entry point and regression gate
remain task 4.4 work.

The first actual TCA compile exposed an overly broad implementation-only import:
TCA macros, observation storage and protocol conformances need a normal native
dependency. The candidate keeps that native dependency visible and confines only
generated Kotlin imports. The active `CheckImplementationOnly` recipe remains
enabled. A shell has native dependency search paths but no raw Kotlin paths or
module maps. This distinction must be retained by the production builder.

## D3 caller inventory and proposed composition

| Entry | Service/repository path | Required ownership/policy behavior |
| --- | --- | --- |
| Native Home | TCA client → typed Home request owner → `AppComposition.homeService` → graph counter repository | Synchronous Main entry, Kotlin execution, native result copy and independent cancellation drain |
| Shared UI Home | `HomeRouteOwner` → the same `AppComposition.homeService` → graph counter repository | Compose Main scope and route reservations; exact service identity still needs integrated qualification |
| Native Nearby owners | `AppComposition.nearbyHub.makeFacade()` → hub service → one wrapped graph fleet repository | Every owner uses the same wrapper/policy, including suspension and resumption |
| Existing DI helper APIs | `SharedDependencies.createDefault*` or graph's direct Nearby service | Must remain unavailable to the candidate shell; a second graph or direct repository service bypasses candidate ownership |
| Android native/Shared UI | `AppShell` creates one shared graph and its Android graph | Separate app/runtime; preserve existing behavior and obtain actual Android parity evidence |

The repository calls themselves live in `HomeFeatureService.refresh` and
`NearbyVehicleMapFeatureService.refreshSnapshot`. `FakeCounterRepository` delays
before consulting failure policy and computing a result; it has no per-instance
mutable request counter. `SimulatedNearbyFleetRepository` delays before reading
and incrementing its snapshot index, with no suspension inside that final
read/update/result section. These observations motivate testing Main confinement
before imposing whole-operation serialization; they do not establish every
possible future repository's requirements.

The DI graph also exposes a Nearby feature service directly over its repository,
while the hub constructs a guarded service over that same repository. The
candidate must not let a shell choose between these entry points. Its composition
is private, and the shell's compiler recipe must refuse raw module imports.
Kotlin/Compose callers must be audited separately; Swift import closure cannot
prove their policy participation.

The comparison fixture constructs the actual `AppComposition` through Metro,
checks native Home's exact service identity and rejection of a foreign graph,
then overlaps requests from two Nearby facades over the real simulated repository.
It compares Main confinement and the existing whole-operation mutex policy.
This native cohort exercise is not the integrated Shared UI identity/overlap gate.

Observed maximum active repository calls were **two for Main confinement** and
**one for whole-operation locking**. Both produced distinct sequences 1 and 2,
preserved request times and returned to zero active calls. Both policies accepted
the composition's Home service and rejected a foreign graph's service. This
supports continuing with Main confinement provisionally for this repository;
it does not select a production policy or qualify Compose participation.

## D4 macro and compiler controls

The inherited Xcode macro-skip preference need not be changed globally. Xcode's
installed `xcodebuild(1)` manual documents `-userdefault=value`; the tested
invocation uses `-IDESkipMacroFingerprintValidation=NO`. An owned build first
refused the four unapproved package macros, then compiled the locked native
dependencies after exact package-revision approvals were installed in the owned
home. Checkout revisions and the MapLibre publisher checksum were verified.

The first control attempt reached the expected Xcode refusal but its diagnostic
parser used the wrong text encoding. It remains an incomplete attempt. A fresh
native directory reran the refusal and approved build with UTF-8 parsing. No
global preference was changed, no macro-skip argument was passed, and the negative
control is required evidence for the explicit invocation recipe.

This establishes the bounded candidate approach. The existing direct rollback
command still needs this invocation recipe integrated and its complete build/test
rerun; the earlier rollback receipt remains incomplete. Likewise the repo-owned
production command, exact consumer membership, cold/replay and hosted app evidence
remain pending. Reusing warm Core/Home/Nearby model Klibs for iteration does not
qualify a cold app build.

The active hidden-layout control compiled without `CheckImplementationOnly`
and failed with it. The same generated coroutine support also failed an explicit
Swift 6 comparison on its Sendable/inheritance requirements, while the selected
Swift 5 support / Swift 6 remaining-module recipe built. No fallback was selected
automatically. This is an additional compiler-coupling cost for D4 review, not
resolution or acceptance of the generated bridge findings.

Upgrade/recovery procedure: change tools/exporter/dependencies only through a
separate assessed tuple; regenerate all modules and the joint native archive,
rerun the positive/negative import and macro controls, rebuild native products,
then repeat the actual app controls and affected cold/replay/hosted gates. Do not
reuse a module image or receipt from another tuple. Keep the direct content
checkpoint and macro repairs until recovery has been rerun on the final source.

## Remaining review

Final D1/D2/D3/D4 dispositions remain pending. Continue with the meaningful Home
slice and its real feature/lifecycle controls, then Nearby and Shared UI from one
delivery. Preserve fresh diagnostic/advisory attribution, realistic state-change
patches, explicit experimental settings and the recovery path. Prepare the draft
PR after exact staged gates for the intended scope; missing qualification must
stay visible while code review proceeds.
