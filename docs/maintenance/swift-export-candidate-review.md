# Swift export candidate implementation review

The optional custom producer and consumer are implemented. The approved native
macro repair updates SwiftSyntax to 603.0.2 and Perception to 2.0.10. Production
builder/defaults, Android bootstrap, CI, release and risk policies remain unchanged.
This report records local candidate evidence and requests review of unresolved
compatibility findings. It does not authorize adoption.

## Qualification boundary

The measured tuple is Kotlin 2.4.20, Kotlin Toolchain 0.13.0, JDK 26, Xcode 27.0
(27A266a), Swift 6.4 and iOS Simulator SDK 27.0. Consumers target arm64 iOS 26.
Ruby 4.0.6 and its exact `xcodeproj` 1.28.1 implementation, executable/tool bytes,
SDK settings, source inventory, compiler flags, publisher bytes and locked
native package inputs are recorded in run receipts. SDK settings binding is
not an inventory of every SDK file.

`coroutine-swift5` compiles KotlinCoroutineSupport in Swift language mode 5 and
other generated modules in mode 6. `generated-swift5` compiles every generated
module in mode 5. Aliases and the native app compile in strict Swift 6 in both
cases. A compiled Swift 5 support module consumed from Swift 6 therefore remains
an assessed possibility on this installed Swift 6.4 compiler. Historical Swift
5 compilers, stable binary distribution and library evolution are unqualified.

The fresh checkout qualification starts from the complete public baseline
`50ae26e4a40c3bc83fe10a2ad05645088330aa63` in a new local Git clone, verifies a clean
checkout, then overlays the uncommitted candidate source inventory. It does not
copy ignored assessment products or existing `.build` directories. This proves
a local clean-baseline-plus-candidate path, not published clean-clone onboarding
or a GitHub-hosted run. Each Executor phase snapshots that candidate again into
new owned source/output/cache roots. Publisher/bootstrap tools may consult host
caches; the native producer records this limitation. Post-cleanup replay uses
explicitly retained compiler-specific native objects and host macros.
The historical baseline's published equivalent is
`ca3174dec9a295e24d0c40986652dcd92c2631e8`, with an identical Git tree.

## Revised qualification after the approved macro repair

| Profile / policy | Cold source-to-app | Post-cleanup replay |
| --- | --- | --- |
| `generated-swift5` / `main-confined` | Passed, both enum variants | Passed, origin binding and original workspace removal verified |
| `coroutine-swift5` / `main-confined` | Passed, both enum variants | Passed, origin binding and original workspace removal verified |
| `generated-swift5` / `shared-operation-mutex` | Passed, both enum variants | Passed, origin binding and original workspace removal verified |
| `coroutine-swift5` / `shared-operation-mutex` | Passed, both enum variants | Passed, origin binding and original workspace removal verified |

These runs use captured source inventory
`89d39bbcdb853862014d9fa609512d41a868bbddba39fe87bd7134bac837a79e`
and native lock hash
`8f74d427f1744a1d087b60d313b5d634da4c622602427a8d6d7f903f6f35cc34`.
The first revised attempt encountered a RunStore initialization race and disk
exhaustion. Its partial evidence and inconclusive recovery results are retained.
The sequential coordinator completed all four cold cases and all four guarded
post-cleanup replays. Independent verification checked exact retained file
inventories and hashes, source bindings, fresh Kotlin/native provenance, twelve
module modes, app packaging, thirteen transport controls, twenty-two Compose
job controls, nineteen route/UI groups, three same-process lifecycle cycles,
polling observations and zero retained reservations/drains at terminal close.
Every cold run retains 6,316 files and every replay 4,669 files. All eight runs
are positively quiescent and cleaned. Retained emitter logs contain no internal
compiler error. Replay compiler work is fresh; native products/macros are
explicitly retained warm inputs.

The app's exact Perception requirement is also aligned with 2.0.10. That project
constraint and the review/ownership edits at the time were outside the export
descriptor's 125 selected inputs; comparison through the repository-owned Source
inventory verified those execution inputs against the captured matrix.
These matrix receipts describe that earlier candidate revision. The later
[app pilot](swift-export-app-pilot-evidence.md) extends the shared producer and
records its own source-bound cold and replay evidence. The complete four-case
maintained-candidate matrix has not been repeated on the final combined PR
contents; the historical receipts do not qualify changed producer inputs.
The default direct Kotlin iOS debug build and twelve PullRequest simulator tests
passed with unchanged repaired pins. Their private wrapper refusal and separate
raw-receipt verification are disclosed in the [repair assessment](swift-export-macro-repair.md).
This does not qualify minimum-runtime, hosted, device or release behavior.

## Historical qualification before the two-pin repair

| Profile / policy | Source-to-app | Post-cleanup replay |
| --- | --- | --- |
| `coroutine-swift5` / `main-confined` | Passed with expanded packaging/polling receipts | Passed; fresh Swift/app compile and runtime, retained native products |
| `generated-swift5` / `shared-operation-mutex` | Passed with expanded packaging/polling receipts | Passed; original work removed before replay |
| `coroutine-swift5` / `shared-operation-mutex` | Passed with expanded packaging/polling receipts | Passed with origin-binding guard |
| `generated-swift5` / `main-confined` | Passed with expanded packaging/polling receipts | Inconclusive: second-phase internal compiler JSON error |

The first support-only/Main attempt exposed an incorrect compiled multi-scene
flag. Its incomplete result was preserved; the candidate now authors and checks
an explicit single-scene manifest. The first all-generated/mutex attempt
encountered a Swift internal corrupted-JSON error during relocation, despite an
Xcode success marker. It was refused and retained. A fresh retry passed without
suppressing the diagnostic. The same internal diagnostic recurred in the all-generated/Main guarded
post-cleanup replay. That second incomplete attempt was also retained and
cleaned; its origin binding and first runtime phase passed. A fresh retry with unchanged inputs reproduced the failure. An isolated
source-bound comparison changed only candidate `SWIFT_ENABLE_BATCH_MODE=NO`,
using the installed Xcode specification: its normal baseline passed, but the
candidate relocated build reproduced the internal error. Batching is not an
established cause or remedy. The internal setting remains unselected; no
maintained configuration or diagnostic guard was relaxed. A later [macro termination assessment](swift-export-macro-repair.md) directly
reproduces the exact diagnostic in the old macro executables and rehearses a
released SwiftSyntax/Perception repair. The original attempts remain incomplete.

Each completed cold case exercises original and actually reordered Nearby enum
source, twelve generated modules, the joint Kotlin archive, Swift 6 aliases and
two fresh Xcode app builds. The relocated build hides the original package.
Per enum phase, the runtime requires thirteen transport controls, twenty-two
Compose job-admission controls, nineteen actual route/UI controls and three
same-process background/foreground cycles. Foundation executor/backoff controls
are separately scoped to typed stubs. These counts describe named controls,
not a diagnostic acceptance threshold.

The maintained packaging check verifies production static plist values and
build-setting expansions, explicit single-scene scope, compiled AppIcon metadata
and renditions, native privacy-bundle inventories, MapLibre assets and offline
style bytes. Its corruption controls reject changed/extra privacy resources,
changed plist/scene settings, changed MapLibre assets and symlinked resources.
Expanded app receipts require polling-resume/timing observations, cancellation
and manual-retry latency observations, and retained-count snapshots. Resumed
poll waits are not measured OS wakeups or an energy budget. Soft deadlines do
not bound backend completion, memory bytes or fairness.

The repository static quality gate and full contract gate passed locally after
adding the candidate controls. The five new suites pass twenty tests and
one hundred three assertions. Strict OpenSpec validation and whitespace checks pass.
These gates do not substitute for the full app matrix or hosted execution.

The historical cold matrix uses source snapshot
`29d04f906085070b3b6bafb4e2bb1de199b1389f11caa6807ad78adc500095ca`.
The later origin-guard replay snapshot is
`ca52150b638bbc330f9ed910952799c6fe3436588e5cd64b89a585639d1e90c9`.
Only replay metadata validation changed between these execution snapshots;
producer, module sources, native build and runtime controls are unchanged.
Review documentation and contract-gate registration have their own later edits;
these execution hashes identify captured candidates, not a published commit.

## Repository-cohort audit

`NearbyHub` resolves the Metro repository once. Its delegate, service and shared
mutex are private. Each native Nearby owner gets a facade from that same hub;
all facade refreshes call its wrapped `fetchNearbyFleetSnapshot`. Both raw facade
access and native transport are Main confined. The `main-confined` repository
wrapper asserts Main before and after suspension. The mutex policy moves each
complete operation to Default and holds one hub mutex across suspension and
delegate return. Diagnostic gates/failures run inside that same operation.

Home native/Compose peers share one exact Home service; they are not callers of
the Nearby repository. No Compose Nearby screen is introduced. These guarantees
cover the candidate's declared hub cohort. Production callers outside it need a
new cohort audit before wiring. Main confinement permits suspended operations to
overlap; it does not serialize complete operations. A noncooperative mutex holder
can delay peers. No policy is selected for production.

## Requested diagnostic dispositions

The repository-owned `quality-contracts` gate also runs the descriptor, registry,
resource-ownership and packaging controls without invoking export or simulator
builds. Workflow YAML and app builder selection are unchanged.

Every retained finding carries emitter, effective input identity, normalized
message/location and fingerprint. Review must address those specific bytes and
the profile/target; opt-ins, unchanged counts and named behavior passes cannot
close findings. The following decisions are **requested and unresolved**:

| Finding family | Requested review scope | Current disposition |
| --- | --- | --- |
| Coroutine internal inheritance | Exported support inheritance versus [Kotlin/runtime inheritance compatibility](https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines/-internal-for-inheritance-coroutines-api/) on both declared Swift modes; compiler upgrades require requalification | `review_required`; no risk acceptance |
| Kotlin/C++ casts and target features | Producer/bridge ABI, enum variant and arm64 simulator target; verify each retained emitter/location fingerprint | `review_required` |
| Generated Swift implementation-only imports, casts and unused values | Generated module/mode/compiler identity; language-mode accommodation is not a library-evolution guarantee | `review_required` |
| MapLibre/SwiftUI runtime diagnostics | Retained message/location and native dependency/app resource tuple; local UI checks cannot establish platform-wide safety | `review_required` |
| Swift internal corrupted JSON | Failed attempt remains incomplete; a passing retry does not establish cause or approve recurrence | Old macro termination incompatibility reproduced; isolated two-pin repair passed; Full repaired cold matrix and guarded replay passed; historical failures remain incomplete; dependency-risk review pending |

Compiler errors and native Swift 6 warnings fail. No scanner, warning rule or
risk policy was weakened to qualify the candidate. Fixture sources are explicit
`.kt.template`/`.swift.template` assets materialized byte-for-byte inside owned
workspaces; their compiler/runtime validation is distinct from production source
static analysis.

## Ownership, retention and external gates

The build-maintenance role owns descriptors, compiler/exporter upgrades,
diagnostic review, registry recovery and replay. The accountable person is
**Jorge Castro**, explicitly assigned during implementation review. Native architecture maintainers own app wiring and
facade/lifecycle contracts. The local registry uses generation fencing, immutable
objects, whole-build reader pins and report-first collection. Pins require owned
RunStore process groups; stale/uncertain/crashed pins and explicit evidence/run
references stay protected. A retained-run reference protects packages only when
registered; the registry does not discover arbitrary external copies. Logical
storage limits are not APFS physical quotas. Protected capacity refuses new
publication; retention expiration alone does not remove a pin.

Replay additionally binds the retained package to a passed, hash-verified check
receipt in the stated source-bound origin run. Controls refuse another package,
a changed origin receipt and an incomplete origin. This metadata safeguard was
added after historical cold-matrix capture and is included in the revised matrix.
Producer, fixture, build and runtime behavior are unchanged by the guard. Its positive path is checked against actual retained origin receipts.

Source and execution inventories, complete package manifests, native input
provenance, phase logs and retained evidence hashes remain in owned run receipts.
Cleanup removes only positively quiescent disposable resources. Retained
packages and receipt copies are separate from those resources. Readers of the
public repository can reproduce the protocol and candidate with the
[guide](swift-export-candidate.md); local ignored evidence is not a prerequisite.

| Independent gate | Current scope |
| --- | --- |
| Supported custom Toolchain export integration | Unestablished; the [upstream guide](https://kotlinlang.org/docs/native-swift-export.html) calls Swift export Alpha |
| Published clean-clone / GitHub-hosted candidate | Unqualified |
| Physical device | Unqualified |
| Minimum supported runtime | Unqualified; the measured simulator runtime is iOS 26.5 |
| Android parity | Unqualified by Swift candidate checks |
| Signed release / delivery | Unqualified; simulator ad-hoc signing is technical execution only |
| Fresh advisory review / dependency risk | Unqualified; compatibility fingerprints are not security dispositions |
| Production choices and named owner | Profile/policy/runtime choices pending; Jorge Castro is the assigned maintainer |

The [adoption plan](swift-export-adoption-plan.md) scopes later real app/CI wiring
and preserves the complete baseline commit as content rollback. No adoption,
commit, push, hosted delivery or dependency-risk acceptance follows from this
candidate report.

## Implementation completion and adoption review

All 28 implementation tasks are complete. The repaired cold matrix and guarded
post-cleanup replay pass under both language profiles and repository policies.
Jorge Castro is the accountable maintainer. The complete change is ready to
archive after review; no archive, commit or push is performed by qualification.

The original all-generated/Main replay remains inconclusive on its original
pins. Successful revised-pin runs do not rewrite it or the retained startup,
disk-exhaustion and private default-wrapper refusals. The default job pass is
supported by independently verified raw job exits, logs, unchanged native lock
and the twelve-test result bundle; its wrapper is not a passing Executor run.

The next decision is the separately scoped [adoption handoff](swift-export-adoption-plan.md):
review the profile, repository policy, facade/lifecycle contract, diagnostic
settings and each finding disposition, then qualify published clean-clone,
hosted, device, minimum-runtime, Android and signed-release paths independently.
The compiled Swift 5 language-mode support module consumed from strict Swift 6
remains a qualified possibility on the recorded installed compiler tuple.
Historical Swift 5 compilers, binary stability and library evolution remain
unqualified. Production defaults and dependency-risk acceptance are unselected.
