# Pre-commit quality and dependency audit

Inspected 2026-09-19 at `7810841cf58196b4564ce78ce30d6ebb1f0db2f4`, tree
`fab34d36a0d01777120ef01d52119ba2447d122f`. The initial checkout was clean.
This is source inspection plus the explicitly listed probes, not a fresh
certification of Android, iOS, release delivery or every dependency.

## Decision and scope

Improve the existing entry points before introducing more tools. The highest
value first slice is an exact-content pre-commit guard and complete file/module
coverage. Next pin the analyzers and inventory, then build isolated Toolchain
rehearsals. Keep `studio.mekate.mobi`, native shells, typed shared state,
Metro factories, optional shared Compose UI, native tests and release packaging.

Inputs reviewed: [AGENTS.md](../../AGENTS.md), [README](../../README.md),
[platform direction](../reference/platform-direction.md),
[mobile architecture](../reference/mobile-architecture.md),
[feature blueprint](../reference/how-to-add-a-feature.md),
[CI architecture](../reference/architecture.md),
[CI validation](../reference/ci-validation.md),
[bridge migration](../reference/ios-gradle-bridge.md), all six accepted ADRs,
the existing OpenSpec capabilities and mobile CI change, and
[contribution guidance](../../CONTRIBUTING.md). External planning input was
treated as hypotheses to verify, not as authority to execute migrations.

## Verified local results

Commands ran in disposable local clones, with existing installed tools; no
dependencies were installed or updated. An instrumented repeat measured each
analyzer through a transparent timing wrapper. These single warm-host samples
are not cold-machine or CI percentiles.

| Probe | Result | Limit of the evidence |
| --- | --- | --- |
| `./scripts/ci/run_job.sh quality-check` | Exit 0, 7.05 s | Existing static scope only; 22 Swift files, zero SwiftLint findings |
| `./scripts/ci/test_classify_changes.sh` | Exit 0, 0.78 s | Existing fixtures pass, including unknown-path full validation; not exhaustive |
| Existing compatibility script with a disposable `gradlew` stub returning 1 | Script exits 0; catalog restored | Demonstrates handled failure becomes shell success; no Kotlin compiled |
| Same stub returning 0, alert off/on | Script exits 0 / 2; catalog restored | Demonstrates notification encoded as failure; not compatibility evidence |
| Classifier with `android-app/module.yaml` | Android tests/build only | Earlier platform case shadows generic manifest full-validation case |
| Classifier with `ios-app/module.yaml` | iOS tests/build only | Same mismatch against documented conservative dependency policy |

Host observations: macOS 26.6.2 arm64, Xcode 27.0 (27A266a), Swift 6.4;
Python 3.9.6 executes. The earlier reported Apple license error did not recur.
Swift version inspection emitted sandbox cache/file-event warnings. Version
commands do not establish simulator availability, package resolution or native
build readiness. The login shell selects Java 26.0.1 and system Ruby 2.6.10;
the quality job selected an installed JDK 21.0.11. Tool selection must be recorded
after repository environment preparation, not inferred from the login shell.

No full mobile build/test, signed archive, vulnerability audit, local Renovate
lookup, Toolchain bootstrap, candidate build or hosted CI run was performed.
Public upstream requests initially hit sandbox DNS restrictions; permitted
read-only retrieval succeeded. This is not a dependency incompatibility.

## Existing quality coverage

All analyzer versions below are **observed installed versions**, not repository
pins or proposed adoption choices. The hook, `just check`, and CI converge on
the same lint script, but tool installation/runtime selection can differ.

| Command/tool | Version; warm sample | Covered inputs and rule profile | Type analysis, omissions and proposed action |
| --- | --- | --- | --- |
| `ktlint`, via [lint.sh](../../scripts/dev/lint.sh) | 1.8.0; 1.35 s | 36 tracked `.kt` and 3 `.kts`; [EditorConfig](../../.editorconfig) | Formatting, not semantic checks. Untracked source excluded. Function naming disabled globally. **Improve** discovery and pinning; review naming exceptions narrowly. |
| `detekt --build-upon-default-config --config detekt.yml --input …` | 1.23.8; 1.42 s | Fixed 13-directory candidate list; existing Kotlin source/test roots; [detekt.yml](../../detekt.yml) | No `--classpath`/`--jvm-target`; no claim of type-aware rules. New modules/source sets and Gradle scripts outside list omitted. Missing roots silently skipped. **Improve** graph-derived inputs; evaluate typed mode separately. |
| `swiftformat --cache ignore --lint …` | 0.62.1; 0.09 s | `ios-app/src`, `ios-app/tests`; [.swiftformat](../../.swiftformat) | Excludes the two Swift files under `ios-app/Dependencies`. Formatter reads [.swift-version](../../.swift-version) = 6.3; config also says 6.0. Xcode project uses Swift 6.0 language mode. **Improve** coverage and explain the effective language policy. |
| `swiftlint lint --strict --no-cache` | 0.65.0; 0.26 s | Same 22 files; [.swiftlint.yml](../../.swiftlint.yml); assets/project excluded | No compile-context/analyzer invocation. Line length, trailing commas/whitespace delegated to formatter. **Keep/improve**; compiler concurrency diagnostics remain separate. |
| `shellcheck --external-sources --source-path=SCRIPTDIR` | 0.11.0; 1.55 s | `find scripts -name '*.sh'`; 42 tracked scripts today | Includes newly created scripts under that root, also potentially ignored generated scripts. Omits `.githooks/pre-commit`, extensionless shell and embedded Xcode scripts. **Improve** repo-owned shell inventory; keep vendored wrappers explicitly separate. |
| [.githooks/pre-commit](../../.githooks/pre-commit) | Bash; runtime above | `core.hooksPath=.githooks` is active locally; calls lint directly | No tests, index/worktree equality, input hashes or post-run drift check. Hook can be bypassed. **Improve**; CI remains defense in depth. |
| [check.sh](../../scripts/dev/check.sh), [run_job.sh](../../scripts/ci/run_job.sh) `quality-check` | Bash | `check.sh` delegates only to lint | No integration selection or evidence receipt. **Keep entry points**, add explicit static/pre-commit contracts in stages. |
| [install_quality_tools.sh](../../scripts/ci/install_quality_tools.sh) | Homebrew, unpinned | Installs missing commands on macOS and prints versions | Existing wrong versions accepted; brew formula changes affect new hosts. **Improve** separate checksum/version-aware bootstrap; never install in a hook. |
| [format.sh](../../scripts/dev/format.sh), `just format` | Same PATH tools | Explicit Kotlin/Swift autofix | Same file omissions as lint. **Keep** manual autofix; never run it implicitly during commit. |

Detekt currently disables all comment rules, `InvalidPackageDeclaration`,
`MagicNumber` and `MaxLineLength`; parameter thresholds are 8. These are policy
choices, not proof of false positives. Preserve the working baseline initially,
then justify exclusions with examples. Do not create blanket baselines to make
new versions pass. Require each suppression to identify rule, exact scope,
reason, owner and review date.

### Additional checks ranked by incremental value

| Check | Decision and purpose | Limits and cost before adoption |
| --- | --- | --- |
| Source/module inventory and content guard | **Add first**; close silent omissions and partial-staging mismatch | Small local Git/filesystem cost; test filenames, deletions, symlinks, ignored output and concurrent edits |
| Analyzer version/checksum verification | **Add next** around existing five tools | Installation outside gate; choose exact versions from paired baselines, not this machine's PATH |
| Secret detection | **Add** pinned [Gitleaks CLI](https://github.com/gitleaks/gitleaks), redacted output over candidate content; intentional-history scan as separate task | Pattern coverage is incomplete; reviewed narrow allowlists, synthetic secret regression, no Go compiler required if verified binary is available |
| GitHub Actions validation | **Add** pinned [actionlint](https://github.com/rhysd/actionlint) alongside ShellCheck | Validate expressions and job structure; runner availability and third-party action behavior still need CI; measure cost |
| Vulnerability auditing | **Improve** from optional to declared required coverage | A recursive [OSV scan](https://google.github.io/osv-scanner/supported-languages-and-lockfiles/) does not automatically understand Toolchain YAML or every SPM package. Inventory-supported package identities first; unknown ecosystems/data unavailable mean incomplete, not clean |
| Compiler diagnostics | **Keep/improve** through actual Android/shared and Xcode tests | Record language/compiler/plugin versions; introduce selected warnings-as-errors for owned code only after baseline; third-party warnings are evidence, not blindly elevated |
| Android Lint | **Assess**, focused Android resources/manifest/API checks | No invocation found in repository jobs. Inspect Toolchain-generated Android tasks before proposing a supported entry point. Do not grow the iOS bridge into Android analysis |
| Swift concurrency and diagnostics | **Assess** using Xcode compilation, native tests and explicit modes | Audit `@preconcurrency` and `@unchecked Sendable` in clients; SwiftLint cannot prove safety. Add lifecycle/cancellation probes before changing interop |
| Architecture constraints | **Add** declared module/dependency-edge validation first; **assess** symbol-level rules | Apply ADR 0001 directions to manifests plus resolved graphs; inject forbidden edges. Text import search alone cannot prove type/API boundaries, aliases or generated code |
| Public API/ABI checks | **Assess**, start with reviewed Kotlin/Swift export diffs and native consumer tests | No established validator found. Toolchain's plugin examples are leads, not installed KMP ABI checks. Define supported targets before snapshotting an API baseline |
| Extra broad scanners and Dialyzer | **Defer** pending measured coverage | Avoid duplicate mandatory gates and new language prerequisites without evidence |

### Type-aware detekt feasibility

[Detekt 1.23.8 documentation](https://detekt.dev/docs/1.23.8/gettingstarted/type-resolution/)
requires CLI compilation classpath and JVM target. Its documentation now also
describes KMP metadata tasks, so a blanket statement that detekt can never
analyze common/native code is unjustified. Those Gradle task descriptions do
not establish equivalent coverage in this Toolchain workspace.
Its [compatibility table](https://detekt.dev/docs/1.23.8/introduction/compatibility/)
lists Kotlin 2.0.21 for 1.23.8; compatibility with Mobi's newer effective
compiler inputs needs its own probe.

The [Toolchain task API](https://kotlin-toolchain.org/latest/user-guide/plugins/topics/tasks/)
exposes source, classpath and compilation artifacts, while warning that most
consumption APIs are JVM-only and multiplatform source discovery remains
limited. This is a promising way to avoid a permanent analysis dependency on
the iOS bridge. First test an isolated JVM/Android compilation slice with real
AAR expansion, Android boot classpath, Metro output, test dependencies and
friend paths. Prove a deliberately type-dependent violation fails, then passes
after repair. Missing symbols or generated classes make analysis incomplete.
There is no proven recipe here for all Native/common source sets; retain
syntax analysis and actual platform compilation until equivalent coverage is
demonstrated. Do not silently report skipped typed rules as executed.

## Dependency discovery inventory

| Surface | Observed state | Coverage gap/action |
| --- | --- | --- |
| [kotlin](../../kotlin) | Toolchain 0.11.1; distribution SHA-256 pinned | No explicit wrapper/checksum custom manager. Add primary distribution inventory; distinguish CLI from compiler and Native artifacts |
| [project.yaml](../../project.yaml), module files | Seven modules; Metro compiler/runtime 1.1.1, coroutines 1.11.0; built-in Compose aliases | Regex managers see Maven dependency/compiler-plugin coordinates, not the full effective graph, built-in catalogs or transitive resolution |
| [bridge catalog](../../gradle/libs.versions.toml) | Kotlin 2.3.20, Compose 1.9.0, Metro 1.1.1, coroutines 1.11.0, SKIE 0.10.12 | Native Gradle manager useful; exact coupled diff and artifact graph still required |
| [bridge wrapper](../../gradle-bridge/gradle/wrapper/gradle-wrapper.properties) | Gradle 9.6.1; no distribution SHA-256 property | Native wrapper extraction must be verified; checksum enforcement is a separate proposed control |
| [Android bootstrap](../../scripts/ci/lib/android_generated_gradle.sh) | Repository fallback Gradle 9.6.1; custom Renovate manager exists | Fallback is not necessarily the effective generated distribution; capture actual delegated AGP/Gradle per Toolchain release |
| [Swift package](../../ios-app/Dependencies/Package.swift) / [lock](../../ios-app/module.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved) | TCA 1.25.4, Dependencies 1.12.0, MapLibre 6.27.0; 15 resolved pins | Native SPM manager declared by standard manifest; record full revision/version diff, macros and binary checksums; do not assume vulnerability matching |
| [.ruby-version](../../.ruby-version), [Gemfile.lock](../../Gemfile.lock) | Ruby 4.0.6, Bundler 4.0.8, Fastlane 2.238.0 | Native managers provide a start; effective interpreter and full gem resolution must match; system Ruby differs |
| [.github/workflows](../../.github/workflows) | macOS-26, Ubuntu labels; action tags including checkout v7, cache v6, Java v5, Ruby v1 | Discover runner-image changes and action immutable SHAs separately from major tags; hosted integration state not inspected |
| [Dockerfile](../../Dockerfile) | Android build image: `eclipse-temurin:25`, SDK 36/build tools 36.0.0, fixed Android command-line-tools URL; unpinned apt packages/Bundler install | Native Docker manager may see base tag, not every downloaded tool. No digest pin, image build or OS scan proven; image is unrelated to dormant Phoenix |
| Analyzer/bootstrap commands | PATH or Homebrew | No version manifest; Renovate itself and analyzer releases not comprehensively inventoried |

[dependency_updates.sh](../../scripts/dev/dependency_updates.sh) uses an override,
PATH Renovate or unpinned `npx --yes renovate`; no Renovate or OSV executable was
found on the audit shell PATH. Node 26.5.1 is present. OSV absence/skip currently
permits success. This audit did not invoke the download fallback.

[renovate.json](../../renovate.json) has useful native managers, three custom
regex managers, Metro/coroutines grouping, Kotlin `<2.4.0` and Metro `<1.2.0`
ceilings, Monday schedule and dashboard approval for majors. No explicit
seven-day minimum age or complete advisory-freshness policy is present.
It configures hosted-style behavior; installation of the hosted app was not
verified. Preserve it during planning. Future local mode should use a pinned
overlay with branch/PR writes impossible, while exposing ceiling-blocked
candidates in a separate report. [Renovate local mode](https://docs.renovatebot.com/modules/platform/local/)
is experimental lookup/extract, not a rehearsal or a full before/after engine.

Two additional mutation paths need consolidation:
[update_kotlin_toolchain_dependencies.rb](../../scripts/maintenance/update_kotlin_toolchain_dependencies.rb)
actually updates only `activity-compose` in place, without age or evidence
checks; [update_bundler_lockfile.rb](../../scripts/maintenance/update_bundler_lockfile.rb)
changes local Bundler settings and updates Fastlane. Keep them out of ordinary
discovery; migrate them behind isolated rehearsal or explicitly documented
manual usage in a later authorized implementation.

## CI and pre-commit parity gaps

The CI classifier/test/build split is valuable and should be preserved. The
two app manifest exceptions measured above must be fixed before claiming that
all dependency/build changes receive full validation. New test-bearing modules
must also be discovered instead of relying only on Fastlane's current list of
five host-test modules.

`android-test` currently calls [Android preparation](../../scripts/ci/lib/android.sh),
which invokes [apply_android_version.sh](../../scripts/ci/apply_android_version.sh)
and writes tracked `android-app/module.yaml`. Therefore simply adding that job
to a checkout-based commit hook would violate an exact-content contract.
The future pre-commit test mode must preserve reviewed metadata, validate in
an isolated snapshot, and reject unexplained tracked mutations. Build identity
generation belongs outside those inputs or must be an explicit recorded
transformation, not a hidden exception to the guard.

The quality job does not run tests. Both Xcode test plans currently select
`appTests`, with no wider device/UI matrix yet. An iOS test job builds its host;
avoid an equivalent extra standalone build for behavior-only changes.

## Verified facts, assumptions and blockers

**Verified:** current static gate passes on this host; omissions and unsafe
probe result semantics exist; manifests, tool versions and source-level iOS
gaps are enumerated above and in the [compatibility matrix](kotlin-compatibility.md).

**Untested assumptions:** complete analyzer pin portability; a supported typed
detekt adapter; effective resolved/transitive Toolchain graph; simulator and
archive readiness; successful coupled upgrades; direct iOS parity; complete
advisory coverage; hosted app/ruleset state. Existing documentation's historical
build claims are not current execution receipts.

**Blockers to claiming readiness:** no exact candidate artifact/checksum set or
resolved diff; no paired baseline/candidate native runs; no bridge-absent direct
test; no current clean-clone CI or release evidence; direct `shared-di` and
build-phase integration need investigation. Toolchain 0.12.2 and Metro 1.4.4
are age-blocked on this audit date. These block adoption/retirement conclusions,
not completion of the audit. No unresolved license prerequisite was established.
