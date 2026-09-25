# iOS Xcode 27 compatibility investigation

Status: reviewed dependency update adopted locally; the full staged gate
passed on 2026-09-23. Integrated at `2a2577d` on 2026-09-25, with every existing
hosted check passing in [run 36127364544](https://github.com/Mekate-Studio/Mobi/actions/runs/36127364544). Investigation baseline: `10319cd`, with the uncommitted
slice 3 job implementation. The 2026-09-22 rehearsal evidence remains historical;
the three reviewed dependency files now match its passing candidate exactly.

## Diagnosis

The local failures are compatibility gaps in the locked Swift dependencies under
Xcode 27.0 (27A266a), Swift 6.4. The same base commit passed hosted iOS validation
using Xcode 26.6 (17F113). This explains why hosted success did not establish
local Xcode 27 compatibility.

1. Sharing 2.8.0 fails linking initialization expressions for the private
   `Shared.__generation` and `SharedReader.__generation` state. The original
   snapshot and a clean archive of the base commit reproduced it. Upstream
   [report 239](https://github.com/pointfreeco/swift-sharing/pull/239) matches the
   exact Xcode build and symbols; its author closed the proposed workaround
   after confirming the released fix in
   [2.8.1](https://github.com/pointfreeco/swift-sharing/releases/tag/2.8.1).
   [Patch 216](https://github.com/pointfreeco/swift-sharing/pull/216) excludes
   unavailable initializers under Swift 6.4 and adjusts generic signatures.
2. Rehearsing Sharing 2.8.1 alone links Sharing successfully, then exposes TCA
   1.25.4's actor-isolated key-path compilation error in
   `NavigationStack+Observation.swift`. Upstream
   [patch 3931](https://github.com/pointfreeco/swift-composable-architecture/pull/3931)
   adds the missing main-actor annotation and ships in
   [TCA 1.26.0](https://github.com/pointfreeco/swift-composable-architecture/releases/tag/1.26.0).
3. Together those versions compile the app and test targets, but the test host
   crashes before test execution. The crash stack enters IssueReporting 1.9.0's
   `_currentTest()`, `Test.id` and `TypeInfo` copy through the Dependencies cache
   during `AppServices.makeHomeStore()`. It ends in `swift_retain` with
   `EXC_BAD_ACCESS`/`SIGBUS`. Upstream
   [patch 186](https://github.com/pointfreeco/swift-issue-reporting/pull/186)
   updates the reflected Swift Testing type layout for Swift 6.4 and ships in
   [IssueReporting 1.10.0](https://github.com/pointfreeco/swift-issue-reporting/releases/tag/1.10.0).
   The later simulator diagnostic timeout is a consequence of the failed test
   launch; it does not identify the original cause.

These observations identify a coupled Swift compatibility update. These
failures do not demonstrate a Kotlin Toolchain or Gradle bridge defect. No
application code, native target, Swift sealed-state adapter, compiler plugin,
optimization setting or release default was changed to bypass these failures.

## Reviewed update

The [reviewed patch](rehearsals/ios-xcode27-compatibility.patch) changes three files:
the TCA exact declaration in the local Swift package and Xcode project, plus the
resolved lockfile. It updates these three components together:

| Component | Before adoption | Adopted | Immutable adopted commit |
| --- | --- | --- | --- |
| Composable Architecture | 1.25.4 | 1.26.0 | `e2fa1df6cd9eec6fa6314aa20513e47da576f24e` |
| Sharing | 2.8.0 | 2.8.1 | `c525e53936c878c102421eee241d82711eb38104` |
| IssueReporting (`xctest-dynamic-overlay`) | 1.9.0 | 1.10.0 | `cb281f343fd953280336dcbd3822cdf47c182f5b` |

All other 12 resolved packages remain fixed. The candidate was resolved in an
owned copy using `xcodebuild -resolvePackageDependencies` with
`-onlyUsePackageVersionsFromResolvedFile`, followed by a complete pin comparison.
The resolver preserved the candidate lockfile bytes.

All three releases were published on 2026-06-09, exceeding the seven-day observation
period. The full Sharing interval contains four commits across 25 files: compiler
compatibility changes, upcoming-language-feature/import declarations, and removal
of its production CombineSchedulers use. The latter also changes an internal
file-storage SPI that Mobi does not call. TCA's full interval includes 1.25.5 and
contains 13 commits across 157 files, including formatting/documentation, broader
SwiftSyntax compatibility, enum reducer fixes, additional scope overloads and
the Xcode compatibility fix. The existing Mobi SwiftSyntax pin stays 601.0.1.
This is a reviewed compatibility candidate, not a recommendation to take all
current upstream releases.
IssueReporting's six-commit, 14-file interval also modernizes concurrency and
imports, removes the internal PackageSupport module and adjusts asynchronous
helper signatures. Mobi does not call its `unimplemented` or
`withExpectedIssue` helpers directly. The original package identity/URL stays
unchanged; the 2.x package rename and major migration are outside this candidate.
Later releases have additional fixes, including Sharing's file-storage scheduling
fix and TCA's notification-name cleanup. Those are not included in this bounded
rehearsal; a general refresh still needs the complete inventory/review workflow.

Public repository advisory endpoints returned zero records for all three packages
on the inspection date. That is a limited provider observation, not a complete
direct/transitive vulnerability audit or a claim that no vulnerabilities exist.

## Probe integrity

The first attempted candidate was incorrectly prepared by replacing the first
matching version string, which belonged to Navigation rather than Sharing.
Xcode then re-resolved the graph and reported duplicate IssueReporting targets.
That attempt is rejected as a preparation error, not dependency compatibility
evidence. Subsequent candidates select packages by identity and assert the exact
changed set before running. The preparation error never affected Mobi's working files.

The valid Sharing-only rehearsal used fresh derived data. Its 15-entry lockfile
remained unchanged throughout the job. The combined candidates reuse downloaded
packages within the owned copy and run the existing `ios-test` job with the
Gradle bridge and `PullRequest` plan. Before/after manifests bind all copied
inputs, including scripts, app/test sources, compiler settings and dependency
files. Raw logs contain host paths and simulator identifiers and stay local;
the public evidence records sanitized outcomes and hashes.

The interrupted two-component attempt did not retain its outer executor's
completion receipt. Its final Xcode result bundle and app crash report establish
failure: zero tests passed, with one synthetic test-host failure. A recovery
check confirmed the recorded source manifest remained unchanged. This is
recovered failure evidence, not a completed executor success or timeout test.

## Verified candidate results

Both runs used Xcode 27.0 (27A266a), Swift 6.4 and the existing iPhone Air
simulator on iOS 27.0 (24A434), with the same three-component candidate.

| Probe | Result | Native tests | Job duration |
| --- | --- | --- | --- |
| Existing owned derived data, rebuilt changed dependencies | Passed | 12 passed, 0 failed, 0 skipped | 85.768 seconds |
| Fresh owned derived data and Swift package checkouts | Passed | 12 passed, 0 failed, 0 skipped | 131.893 seconds |

Xcode built the retained `app` and `appTests` targets and ran the `PullRequest`
plan's Home and Nearby Vehicle Map tests, including shared-state adaptation and
location/error behavior. The existing Gradle bridge job succeeded. Both runs
retained all 15 expected package pins and passed the before/after copied-source
and executable-mode checks. Only the three candidate files differ from the
original source snapshot. At rehearsal time, Mobi's working dependency files
still matched the base; the reviewed candidate was applied on 2026-09-23.

The second run removed the entire owned Xcode derived-data directory, including
Swift package checkouts and compiled Swift products. It retained Kotlin/Gradle
outputs and could use host package caches, so it is not fully cold clean-clone
evidence. These are direct native-job rehearsals through the slice 3 executor,
not a complete staged pre-commit hook run. No tests were disabled, no simulator
runtime was changed, and the test plan was not narrowed.

Existing non-blocking warnings remain: the test target has an absent
`AmperFrameworks` search path, Gradle reports deprecations affecting a future
Gradle 10 upgrade, and Xcode skips AppIntents metadata extraction for products
without that dependency. These warnings did not cause the diagnosed failures.

The [sanitized evidence](evidence/2026-09-22-ios-xcode27.json) records the full
candidate manifest (with personal Xcode metadata paths omitted), exact pins,
test identities, source/patch/log hashes and primary upstream records. It is
rehearsal evidence, not an adoption receipt.

After the final source-integrity check, the owned source/build/cache copy and
all three Xcode result bundles were removed. No matching owned build process
or booted simulator remained at inspection. Raw logs, crash/summary hashes and
local evidence JSON remain in temporary storage; public documents contain no
host paths or simulator identifiers. Host-managed Kotlin/Native and package
caches were not removed. Xcode managed its own test clone of the selected
existing simulator; the repository job did not install a runtime or explicitly
create a simulator.

## Repeating the rehearsal

Use an owned source copy containing the reviewed slice 3 scripts, preserving
executable modes and the complete declared module graph. Do not copy ignored
caches, signing files or credentials. Record a source manifest before running.

1. Starting from the recorded baseline, apply the reviewed patch only in the
   owned copy and verify its three paths and package identities. After adoption,
   copy the adopted files and verify their recorded hashes instead of applying
   the patch again.
2. Run `xcodebuild -resolvePackageDependencies -project ios-app/module.xcodeproj
   -scheme app -onlyUsePackageVersionsFromResolvedFile` with derived data under
   the owned copy; compare the resulting 15 pins with the reviewed candidate.
3. Run `./scripts/ci/run_job.sh ios-test` with `MOBI_VALIDATION=1`,
   `KOTLIN_IOS_BUILDER=gradle`, `IOS_TEST_PLAN=PullRequest`, owned Kotlin/Gradle
   caches and the existing simulator. Use the slice 3 executor's timeout,
   environment allowlist and process-group handling.
4. Require successful native tests, the expected resolved versions and unchanged
   before/after source manifests. Preserve sanitized results and patch/source
   hashes before removing only the owned directory and inspecting residual
   owned processes. A failure at any stage is not an adoption receipt.

## Adoption and recovery

Dependency adoption was explicitly approved on 2026-09-23. The exact reviewed
patch was applied to the working checkout: TCA 1.26.0, Sharing 2.8.1 and
IssueReporting 1.10.0. All three file hashes and all 15 resolved pins match the
passing rehearsal. The other 12 pins remain unchanged. No commit, push, schedule
or release-default change is included.

The first two post-adoption staged gates each passed all 38 Android/shared tests,
all 12 iOS tests and both debug builds, but failed during temporary-directory
removal with `ENOTEMPTY`. Gradle registry writes raced with removal. A five-second
retry alone was insufficient. Both runs remain failed gate attempts. Their
inactive owned directories were inspected and removed.

Gradle documents that its [Tooling API always uses a daemon](https://docs.gradle.org/current/userguide/tooling_api.html),
even when CLI daemon persistence is disabled. The executor now runs
[Gradle's stop command](https://docs.gradle.org/current/userguide/gradle_daemon.html)
for each installed version against only the copy's private Gradle user home.
Shutdown is offline, uses pinned Java, and has a 30-second deadline. Failure,
timeout or a missing/escaping launcher or registry retains the recovery path
and prevents success; it never falls back to a global Gradle installation.
The bounded removal retry remains for transient shutdown metadata. All 27
orchestration contracts pass on system Ruby 2.6.10 and pinned Ruby 4.0.6,
including shutdown failure, timeout, escaped registries/launchers, unavailable
launchers, caller-cache preservation and both removal-retry outcomes. This
cleanup defect is separate from the Swift compatibility diagnosis.

The final real `check.sh` run passed in a disposable staged checkout containing
the approved dependencies and pending slice 3 implementation. Its owned native
copy started with empty designated caches; installed SDKs and host caches were
available. The complete gate took **572.108 seconds**:

| Check | Result | Duration |
| --- | --- | --- |
| Pinned static analysis and staged-content guards | Passed | Included in total |
| Android/shared tests across five discovered modules | 38 passed | 232.007 seconds |
| iOS `PullRequest` tests | 12 passed, 0 failed, 0 skipped | 224.334 seconds |
| Android debug build | Passed | 35.642 seconds |
| iOS debug build | Passed | 59.981 seconds |
| Scoped Gradle shutdown and owned-copy cleanup | Passed | Included in total |

The source/index guards passed throughout. Gradle 8.14.3 reported two daemons
stopped; 9.6.1 reported none still running. All five Gradle processes recorded
during execution had exited at final inspection, and no process referenced the
removed native workspace. The caller index remained unchanged. The disposable
staged checkout was also removed after evidence capture. The 35 static-quality
contracts, classifier fixtures, Ruby syntax, whitespace and strict OpenSpec
checks passed.

The separate [adoption receipt](evidence/2026-09-23-ios-adoption.json) binds this
result to the copied source manifest, implementation, exact dependency files,
resolved pins and local log hashes. Documentation summaries written after the
run are identified separately. Earlier failed gates remain failed historical
evidence; the successful rehearsal alone was not treated as a full-gate pass.

The existing hosted workflow passed for the exact integrated commit. Keep the dependency update separately reviewable from the
quality-gate implementation. Recovery is to revert the three dependency files as a unit;
do not downgrade or rewrite unrelated pins. The old set remains incompatible
with Xcode 27 and is only known to pass the recorded hosted Xcode 26.6 baseline.

## Untested assumptions and limits

- Xcode 26.6 compatibility of this candidate has not been executed locally;
  only Xcode 27 is installed. The new exact-commit hosted pass validates its configured runner; it does not
  change the historical local Xcode 27 evidence.
- Native Intel, physical devices, signing, release packaging, fully cold
  clean-clone caches remain unverified. The local four-job staged gate is verified above.
- Public advisory lookup is incomplete vulnerability evidence; the broader
  direct/transitive inventory and policy remain separate maintenance work.
- The successful Gradle-backed run provides no direct Kotlin Toolchain parity
  or bridge-retirement evidence and does not change release defaults.
