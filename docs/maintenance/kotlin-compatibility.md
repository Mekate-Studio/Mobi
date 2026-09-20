# Kotlin Toolchain compatibility and iOS bridge retirement

Audit date: 2026-09-19. Decision: **assess a coordinated upgrade; defer bridge
retirement**. No candidate dependency set has been built or adopted. Kotlin
Toolchain means the CLI/workspace behind `./kotlin`, not Gradle's JVM toolchain.

## Version and ownership matrix

`C` means checked configuration; `U` means upstream source/documentation;
`P` means locally executed and passed; `H` means historical repository claim
without a fresh receipt; `?` means unproven. None of the native matrix below
has new local or CI proof from this audit. The audit's `P` results cover only
static quality and executor/classifier behavior.

| Component | Current Toolchain / Android path | Current iOS bridge | Candidate assessment and ownership |
| --- | --- | --- | --- |
| CLI distribution | C: 0.11.1; SHA-256 `0ded2a434f6bf193b24e2a6d56c3ba443f4232721155a65aaa8372789412112f` | Not the bridge compiler selector | Assess 0.12.2 after its age threshold; independent wrapper/distribution identity |
| Kotlin compiler | U: 0.11.1 defaults to 2.3.21; not runtime-resolved here | C: 2.3.20 | U: 0.12.2 defaults to 2.4.10; record effective override, compiler artifact hash and Native compiler identity for each lane |
| Kotlin/Native | Supplied/resolved by Toolchain configuration; actual distribution unmeasured | KGP 2.3.20 selects compiler by default | Verify actual Native version/ABI and SDK against downloaded artifacts; a Maven language/API target is insufficient |
| Compose | U: 0.11.1 default 1.10.3; `$compose` aliases and `compose: enabled` | C: 1.9.0; Compose compiler plugin uses Kotlin catalog version | U: 0.12.2 default 1.11.1; assess alignment with bridge separately, including UIKit factory/resources |
| Metro | C: runtime/compiler 1.1.1 across module YAML | C: runtime/Gradle plugin 1.1.1 | Assess 1.2.1 as narrow ceiling probe and 1.4.3 as age-eligible later candidate; keep runtime/compiler/Gradle plugin aligned; 1.4.4 age-blocked |
| Coroutines | C: core/test 1.11.0 | C: core/test 1.11.0 | Hold unless a coupled change is justified; prove current suspend/cancellation behavior |
| SKIE | No configured direct integration | C: 0.10.12; sealed interop; coroutine and Flow interop disabled | U: 0.10.13 adds Kotlin 2.4.0, 0.10.14 adds 2.4.10; new support is a Track 1 lead |
| Java | U: Toolchain default 21; repo helpers prefer 21, CI declares 17 | Xcode bridge phase explicitly finds JDK 21 | U: 0.12.2 default 25; distinguish launcher, compile JDK, Gradle JVM and CI installation |
| AGP / delegated Gradle | U: Toolchain 0.11.1 source catalog AGP 8.10.1; repository fallback Gradle 9.6.1 | C: wrapper Gradle 9.6.1; iOS only | U: 0.12.2 source catalog AGP 9.3.1; extract generated Android versions in a probe, do not infer from bridge wrapper |
| Android SDK | C: min 23, compile/target 36 | Not owned by bridge | Candidate defaults include min 24/compile 37/build tools 37; determine effect of Mobi's explicit overrides and delegated AGP requirements |
| Xcode / Swift / iOS | Host Xcode 27.0/Swift 6.4; language config 6.0, formatting version file 6.3 | Same app/project and native packages | Pin supported CI image/Xcode observations; SPM manifest specifies iOS 16; verify effective deployment settings per target/configuration |
| SPM / release tooling | C: 15 SPM pins, Ruby 4.0.6/Bundler 4.0.8/Fastlane 2.238.0 | Xcode owns packages and app/tests; Fastlane owns archive/export | Hold initially; preserve macros, package locks, framework/resource embedding and signing boundary |

Default versions above are from versioned upstream files, not Mobi's actual
resolved command output: [0.11.1 defaults](https://github.com/JetBrains/kotlin-toolchain/blob/v0.11.1/sources/frontend-api/src/org/jetbrains/amper/frontend/schema/DefaultVersions.kt),
[0.12.2 defaults](https://github.com/JetBrains/kotlin-toolchain/blob/v0.12.2/sources/frontend-api/src/org/jetbrains/amper/frontend/schema/DefaultVersions.kt),
[0.11.1 catalog](https://github.com/JetBrains/kotlin-toolchain/blob/v0.11.1/libs.versions.toml)
and [0.12.2 catalog](https://github.com/JetBrains/kotlin-toolchain/blob/v0.12.2/libs.versions.toml).
The bootstrap wrapper in an upstream source tag may itself point to an older
bootstrap/dev distribution. Do not copy that file and assume it is the released
consumer wrapper. Obtain the exact release wrapper/checksum through the
documented distribution/update mechanism in an isolated candidate, and verify
its declared version before executing it.

Independently declared pins include the CLI distribution, bridge catalog,
Maven runtime/plugin coordinates, Swift packages, Ruby and analyzer tools.
Built-in Kotlin/Compose/JDK values start from the selected Toolchain release;
any supported project override must be validated against that release's schema
and recorded as effective configuration. AGP and delegated build machinery
come from the Toolchain implementation/generated build and cannot be assumed
independently replaceable through the bridge catalog. The Native artifact must
be resolved and inspected, not inferred solely from a language-version flag.

## Upstream changes that alter the previous explanation

Primary sources were retrieved on 2026-09-19. Mutable documentation describes
capabilities at retrieval time; exact-version release notes/source take
precedence when choosing a candidate. The
[evidence record](evidence/2026-09-19.json) includes hashes for inspected raw
Toolchain sources and publication timestamps from public release APIs.

| Previous observation or assumption | Revalidated evidence | Consequence |
| --- | --- | --- |
| SKIE blocks all Kotlin 2.4 upgrades | [0.10.13](https://skie.touchlab.co/changelog/0.10.13) supports 2.4.0; [0.10.14](https://skie.touchlab.co/changelog/0.10.14) supports 2.4.10 | The explanation is stale for newer SKIE. Keep existing ceilings until an exact paired rehearsal passes; replace the blanket ceiling rationale in an authorized upgrade. |
| Swift export lacks documented sealed mapping | [Swift export](https://kotlinlang.org/docs/native-swift-export.html) now documents sealed enums and `.sealedType()`; it remains Alpha, with generic erasure and Gradle Xcode examples | Renew a bounded interop investigation. This is neither stable API parity nor standalone Toolchain integration evidence. |
| A checked-in test target necessarily prevents direct integration | [0.11.1 target selection](https://github.com/JetBrains/kotlin-toolchain/blob/v0.11.1/sources/amper-cli/src/org/jetbrains/amper/tasks/ios/ManageXCodeProjectTask.kt#L110) and [0.12.2 selection](https://github.com/JetBrains/kotlin-toolchain/blob/v0.12.2/sources/amper-cli/src/org/jetbrains/amper/tasks/ios/ManageXCodeProjectTask.kt#L134) filter for an integration-marked target | Exactly one marked target is required; this does not establish a prohibition on a separate unit-test target. Preserve both targets and test the real project. |
| Any single app-target project is enough | [Current iOS guidance](https://kotlin-toolchain.org/latest/user-guide/product-types/ios-app/) also requires a managed phase and wrapper settings; 0.12.x manages a required scheme | Audit the marker, phase rewriting and scheme behavior. Mobi's custom phase contains neither known marker. CLI-managed and raw-Xcode entry paths may behave differently. |
| Metro runtime language target proves Native compatibility | [1.2.0 notes](https://github.com/ZacSweers/metro/releases/tag/1.2.0) distinguish build compiler 2.4.0 from runtime target 2.3.0; [compatibility guidance](https://zacsweers.github.io/metro/latest/compatibility/) distinguishes plugin compatibility | The existing Native ABI concern is not disproved by language/API target declarations. Inspect KLIB metadata and compile actual factories for both stacks. |
| Latest stable release is automatically eligible | [Toolchain 0.12.2](https://github.com/JetBrains/kotlin-toolchain/releases/tag/v0.12.2) was published Sep 15 and repairs an overwritten 0.12.1 distribution | Enforce age and artifact identity independently; never substitute the bad artifact or edit checksums merely to bypass a mismatch. |

A documentation phrase such as “direct Xcode integration” may still mean
`gradlew`. Here **direct Toolchain** means the standalone workspace path with
the hand-maintained `gradle-bridge/` unavailable. Toolchain may still delegate
Android work to Gradle; “no Gradle anywhere” would be a separate requirement.

### Concrete source-level gaps in Mobi

- [ios-app/module.yaml](../../ios-app/module.yaml) reaches Home, Nearby Map and
  shared UI, but none reaches `shared-di`. [AppServices.swift](../../ios-app/src/AppServices.swift)
  uses `SharedDependencies` from that module. The bridge explicitly includes
  it. This is a verified graph mismatch and a likely direct-path factory gap,
  not a reproduced compiler diagnostic.
- [project.pbxproj](../../ios-app/module.xcodeproj/project.pbxproj) has `app`
  and `appTests`, a builder switch, custom embed logic and an IDE skip variable.
  Its custom phase lacks the old/new Toolchain integration markers. Upstream
  project management can rewrite marked phases. A candidate must record the
  Xcode diff and retain a real rollback; do not insert a marker in the main
  checkout merely to see what happens.
  The [0.12.2 scheme convention](https://github.com/JetBrains/kotlin-toolchain/blob/v0.12.2/sources/amper-cli/src/org/jetbrains/amper/tasks/ios/IosConventions.kt)
  is `app`, matching Mobi's checked-in scheme name. Name agreement is verified;
  preservation of its test plans and behavior still needs execution.
- [HomeCounterLoadable.swift](../../ios-app/src/Features/Home/HomeCounterLoadable.swift)
  and [NearbyVehicleMapFeature+State.swift](../../ios-app/src/Features/NearbyVehicleMap/NearbyVehicleMapFeature+State.swift)
  call `onEnum(of:)`; the Nearby tests do too. The direct manifest configures no
  SKIE replacement. Native tests constructing Kotlin values must remain intact.
- The concrete states are feature-local sealed types, not a generic
  `Loadable<T>` (ADR 0006). Probe actual retained/nullable values, collections,
  typed reasons and Kotlin wrappers. Add a small generic export fixture if
  evaluating erasure; do not claim a generic production state requirement.
- Shared suspend services rethrow cancellation; Swift clients currently catch
  errors and return fallback state. The Nearby view has a cancellable refresh
  loop. End-to-end Swift-task-to-Kotlin cancellation and retention are not
  established by current reducer tests. Characterize the existing behavior
  before promising equivalence or silently “fixing” it during an upgrade.
- The actual UIKit entry is
  [SharedHomeViewControllerFactory.kt](../../shared-ui-home/src@ios/SharedHomeViewControllerFactory.kt).
  Older references to `ios-app/src/ViewController.kt` are stale. Current CI
  build scripts pass runner-native `ARCHS`, despite older architecture prose
  warning against forced architecture settings. Test current commands.

## Track 1: upgrade while preserving the bridge

Keep the current builder and release defaults. First reproduce the baseline
with its two compiler/Compose stacks; do not call an upstream source default
runtime proof. Then test exact, bounded sets in separate copies:

1. Narrow ceiling check: bridge Kotlin 2.4.0 + Metro 1.2.1 + SKIE 0.10.14,
   matching the existing probe's intended question, but with structured result
   semantics. A framework compile is just the first check.
2. Toolchain priority candidate: 0.12.2, with effective Kotlin 2.4.10 and
   Compose 1.11.1 verified after resolution; assess bridge Kotlin 2.4.10,
   SKIE 0.10.14 and a reviewed Metro version on both paths. Metro 1.4.3 is an
   age-eligible candidate to assess, not an approved version set. Treat a bridge
   Compose change from 1.9.0 as an explicit coupled change, with its own notes.
3. Read the full intervening release/migration interval before a candidate can
   become `ready_for_review`. This audit reviewed Toolchain 0.12.0–0.12.2
   highlights and selected Metro compatibility changes, not every behavioral
   change from Metro 1.1.1 through 1.4.3 or every Compose release.

Source-bound risk map for the first Toolchain candidate:

| Upstream change | Concrete Mobi exposure | Required check |
| --- | --- | --- |
| [0.12.0 changes](https://github.com/JetBrains/kotlin-toolchain/releases/tag/v0.12.0): Kotlin/Compose/JDK defaults, Android defaults, removed CLI options | All module YAML, `$compose` aliases, compiler plugin coordinates, scripts invoking `./kotlin`, Android min/compile SDK | Resolve effective settings; diff transitive graph; Android/shared tests and both native builds; search actual CLI usage across full interval |
| Same release: `ios/app` drops iosX64, scheme enforcement, archive-placement fix | Shared KMP libraries and bridge declare iosX64; app scheme is `app`; custom framework embedding | Distinguish library support from app target support; preserve required architectures or explicitly defer candidate; inspect generated project and archive contents |
| [0.12.1](https://github.com/JetBrains/kotlin-toolchain/releases/tag/v0.12.1) resolution fixes; 0.12.2 distribution repair | Cold bootstrap, checksums, error classification | Verify exact archive digest, no cached fallback; network/bootstrap failures cannot be labeled compiler incompatibility |
| Metro provider/codegen changes in [1.2.0](https://github.com/ZacSweers/metro/releases/tag/1.2.0) and [1.2.1](https://github.com/ZacSweers/metro/releases/tag/1.2.1) | `@Provides`, `@DependencyGraph.Factory`, `createGraphFactory` in shared DI and Android graph | Real factory construction, missing-binding negative fixture, common/native tests; do not enable newer IR-only flags indiscriminately |

Confirmed upstream changes are separate from plausible Mobi breakage. No
candidate failure or candidate success has been observed here.

### Release-age decisions as of this audit

| Release | Publication UTC | Proposed policy outcome |
| --- | --- | --- |
| Toolchain 0.12.0 | 2026-08-25 00:01:47 | Age eligible, but later fixes matter; assess as comparison only |
| Toolchain 0.12.1 | 2026-09-08 22:43:14 | Age eligible but artifact incident blocks selection |
| Toolchain 0.12.2 | 2026-09-15 13:41:20 | Normal adoption age-blocked until Sep 22 13:41:20 UTC; explicit experimental rehearsal may run earlier |
| SKIE 0.10.14 | 2026-07-27 15:09:23 | Age eligible; compatibility still needs Mobi proof |
| Metro 1.4.3 | 2026-09-08 04:27:30 | Age eligible; full interval review/rehearsal outstanding |
| Metro 1.4.4 | 2026-09-16 21:45:45 | Age-blocked until Sep 23 21:45:45 UTC |

Dates come from the public [Toolchain](https://api.github.com/repos/JetBrains/kotlin-toolchain/releases?per_page=10),
[SKIE](https://api.github.com/repos/touchlab/SKIE/releases?per_page=10) and
[Metro](https://api.github.com/repos/ZacSweers/metro/releases?per_page=10) APIs.
These bounded release queries are not a complete ecosystem discovery run.

## Track 2: capability parity matrix

The candidate-direct column is a proposed 0.12.2 experiment with one of the
interop options below, not a stack known to build. Each future cell must link
a receipt containing source/candidate identity, environment, check ID and logs.
Upstream support alone is `U`; local proof is `P`; clean CI proof must be marked
separately as `CI`. Missing required cells block retirement.

| Required behavior / evidence to retain | Current bridge | Current direct 0.11.1 | Candidate direct 0.12.2 |
| --- | --- | --- | --- |
| Checked-in `app` + `appTests`, `app` scheme, both test plans survive | C/H: project and jobs exist | C: selectable; marker/phase behavior ? | U: project management changed; target preservation and scheme diff ? |
| Actual SPM products/macros resolve and compile from pinned lock | C/H: Xcode local package, macros flags | ?: same Xcode dependency graph must work | ?: package, macro host architecture, linking must pass |
| Sealed Home/Nearby state, typed failures, retained payloads, nullability | C: `onEnum`; H: native behavior | Gap: SKIE path absent | U: Swift export sealed mapping; actual adapter/API parity ? |
| Generic values relevant to export; Swift construction used by tests | C: concrete typed state; generic production state not adopted | ? | ?: small generic erasure fixture plus real wrappers; no invented production requirement |
| Suspend, failure mapping, cancellation and view lifecycle | C: normal suspend bridge; SKIE coroutine/Flow disabled; cross-language cancellation ? | ? | ?: characterize and compare; unused SKIE Flow is not a requirement |
| Metro factories and all applicable compiler plugins | C: bridge source sets include DI; H: compilation | Gap: DI not reachable from app manifest | U: generic compiler plugin configuration exists; real Native factory generation ? |
| Optional Compose UIKit screen/resources still work | C: shared UI included | C: reachable shared UI; build ? | ?: compiler/runtime, resources, controller embedding |
| Simulator debug build and full native tests | C/H: repo jobs and two test plans | ?: no fresh receipt | ?: local + cold supported CI; preserve test counts/targets |
| iosArm64 device and declared simulator architectures | C: three bridge targets; current audit untested | C: library platform declarations | ?: app iosX64 change explicitly assessed; no silent architecture deletion |
| Release configuration, archive app placement/resources/deployment settings | H: bridge guide reports archive; fresh packaging ? | ? | U: archive fix announced; actual archive inspection ? |
| Signed archive/export appropriate for distributable claim | H only; no credentials used here | ? | ?: separate authorized protected release evidence; simulator success insufficient |
| Cold-cache clean clone and incremental rebuild on macOS/CI | H: documented quickstart | ? | ?: independent caches, no preexisting frameworks, repeated native tests |
| Android/shared regression and stable repo-owned job contract | C: jobs present; no fresh native run | ? | ?: common compiler/plugin changes validated on Android too |
| Bridge physically unavailable; no stale Gradle framework or IDE skip | Not applicable to retained-bridge baseline | ? | ?: delete/relocate only in owned isolated copy; disable IDE skip, inspect process/build provenance and product hashes |
| Authorized switch, rollback and subsequent clean CI | Not requested | Not requested | Deferred until every required cell is proven and the retirement change is approved |

## Three interop options to investigate

| Option | Evidence available | Bounded experiment and decision condition |
| --- | --- | --- |
| Supported Toolchain integration for required SKIE behavior | Toolchain documents [third-party compiler plugins](https://kotlin-toolchain.org/latest/user-guide/advanced/kotlin-compiler-plugins/); [SKIE installation](https://skie.touchlab.co/intro) is Gradle-oriented | Identify supported compiler hooks, Swift generation and framework postprocessing. Attaching a Maven plugin coordinate alone is insufficient. Defer if only unsupported private build internals can supply the pipeline. |
| Swift export | Alpha documentation now includes sealed mapping, async calls and remaining limitations | First prove standalone Toolchain emission/embedding, then adapt actual Home/Nearby native adapters in a throwaway patch. Run native consumer tests including value/error/cancellation semantics. A Gradle export sample proves only compiler capability. |
| Small deliberate interop facade | Existing `SharedDependencies` and native clients are appropriate narrow seams | Prototype typed factories and explicit state projections if needed; retain sealed domain truth and native tests. Review API shape/exhaustiveness and avoid string tags, loose nullable bags or platform frameworks entering shared feature code. Needs ADR review before adoption. |

If none passes the matrix, record `defer` with the next failing capability and
minimal reproducer. Do not expand the bridge or weaken the domain to manufacture
a passing result.

## Repeatable assessment and watch design

Use one assessment engine for manual runs and the existing
[Dependency Compatibility workflow](../../.github/workflows/dependency-compatibility.yml).
Do not create another schedule. After implementation authorization, retain that
workflow as a thin caller of isolated probes; preserve any current protections.

Discovery compares exact upstream versions, artifact identities, relevant
release-note/source changes and changed blocker references. Assessment selects
bounded sets for Track 1 or Track 2. Every run first checks host prerequisites
and the unchanged baseline. Framework compile, app compile, native tests and
archive inspection are separate check IDs. A compile failure with a passing
baseline and dependency-attributable diagnostic may be `incompatible`;
network, permissions, bootstrap, resource exhaustion, timeout and baseline
failure are `incomplete` or `inconclusive` with reasons.

Store matrix deltas keyed by source hash, toolchain/platform tuple and check ID.
Notify only on actionable capability improvements, regressions or changed
blockers. Unchanged known incompatibility is quiet but remains non-passing
evidence. Technical success produces `checks_passed`, never an instruction to
remove ceilings or bridge code. A scheduled client cannot adopt, commit, change
defaults, publish or upload a release. No watch is created by this audit.

The retirement review requires all applicable rows, real native tests and
clean-clone CI on the direct path, release evidence appropriate to the claimed
packaging, a bridge-unavailable run, reviewed interop changes, and an authorized
default switch. During transition preserve the builder switch and known bridge
pins. The rollback is to restore the last proven bridge configuration and
revalidate its jobs; after physical removal restore those files from the
reviewed prior revision. Do not reuse the old migration guide's suggestion to
delete the bridge as a general rollback recipe.
