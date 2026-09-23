# Third slice: conservative pre-commit validation

Status: implemented; full local staged gate passed on 2026-09-23. Base: `10319cd`.
OpenSpec change: `conservative-precommit-validation`. This slice remains local
for review. The preceding two slices were committed and pushed separately.

## Implemented behavior

The existing [classifier](../../scripts/ci/classify_changes.sh) gives module/app
manifests, Toolchain/dependency inputs and unknown paths full validation before
platform-specific cases can match them. Git input is NUL-delimited with rename
detection disabled, preserving deleted paths and both names of a move. Newline
fixture files remain supported through their explicit interface.

[`check.sh`](../../scripts/dev/check.sh) now invokes the pinned-runtime
[orchestrator](../../scripts/dev/validate.rb). `--plan` shows the complete staged
change against HEAD; `--manifest` retains static inventory inspection. Every
commit run checks static inputs once. Selected native jobs then run once each:

| Change surface | Native jobs |
| --- | --- |
| Documentation only | None; static checks and staged-content guard still run |
| Android presenter/state behavior or host tests | `android-test` |
| iOS feature/client behavior or tests | `ios-test` |
| Shared core/feature behavior | `android-test`, `ios-test` |
| Platform UI/resources | Affected test and debug-build jobs |
| Module/app manifests, shared UI/DI, dependencies, Toolchain/build/CI inputs, unknown/empty changes | Both test jobs and both debug builds |

CI's `quality-check` remains static-only. CI separately selects native jobs using
the same classifier. The quality job also runs the orchestration contracts using
fake native jobs; it does not recursively build mobile apps.

## Source identity and preparation

The caller must have a complete staged checkout before any test execution.
The plan binds HEAD and index identity. Static checks retain their existing
before/after guard. The orchestrator copies tracked files and executable modes
to an owned temporary directory without creating a Git checkout, staging files,
registering a worktree or copying ignored credentials/caches. Copied bytes and
modes must match the captured staged Git objects. Tracked copy contents, caller
index and HEAD are checked around jobs. Unexpected new source in authored
module/Swift-package source roots also invalidates the run.

Android test preparation preserves version fields, configures the declared
Java/SDK environment, and creates only synthetic debug signing files. It skips
release credentials, version rewriting and Bundler installation. Validation-mode
debug builds use the existing Kotlin wrapper directly; release paths retain
their previous preparation. Executable bits must already be correct; validation
does not repair them. iOS retains Xcode's `app`/`appTests`, the `PullRequest` plan,
Swift adapters and the Gradle bridge. It uses an existing simulator and refuses
to provision one in validation mode.

The shared YAML graph reader also drives [host-test discovery](../../scripts/ci/test_modules.rb).
New declared Android-capable modules containing `test` or `test@android` Kotlin
tests join the host job automatically. The staged plan excludes ignored,
unstaged test files. Native jobs rediscover tests from the copied source.
Unsupported Kotlin test targets fail explicitly, so introducing `test@ios`
cannot silently claim host/native coverage. Fastlane and the local Android test
helper consume the same discovered module list.

## Failure, recovery and cleanup

Jobs inherit only named host-tool settings. Each has a 45-minute deadline and
an owned process group. Failure, timeout, interruption, HEAD/index changes,
tracked copy changes or unexpected authored source prevent a pass. Child groups
are stopped before cleanup; an uncooperative child receives a bounded TERM/KILL
sequence. Before removal, each installed Gradle version is stopped offline
against only the copy's private Gradle user home, using the pinned Java runtime
and a 30-second deadline. Missing or escaping launchers/registries, shutdown
failure and timeout retain the owned copy for inspection and prevent a pass.
The temporary copy is removed on ordinary completion/failure. The
executor retries directory-not-empty removal errors for up to five seconds to
allow native shutdown metadata to settle. Persistent cleanup failure reports
the owned recovery path and prevents success; other removal errors are not
hidden. The caller is never restored, stashed or repaired. After a hard kill, inspect the
reported owned path/processes before manually removing that specific directory.
Process-group cleanup covers children that remain in that group. Gradle's
[Tooling API always uses a daemon](https://docs.gradle.org/current/userguide/tooling_api.html),
so `org.gradle.daemon=false` alone does not prevent detached Android Gradle
processes. The explicit per-version shutdown closes that gap without stopping
caller daemons. Broader detached-process ownership remains work for the common
executor slice; automatic cleanup is not a hermetic guarantee.

Project outputs and designated dependency caches stay in the owned copy. Native
tools may also use host caches; the SDK and simulator remain host prerequisites,
not hermetically isolated resources. The gate does not install analyzers or adopt
versions. Logs stream to
the terminal; capture them if needed because native result bundles disappear
with the temporary copy. A final JSON summary identifies the plan, source/index
and completed jobs. It cannot be reused to skip a subsequent gate.

## Verified facts

- The prior slice's [hosted run](https://github.com/Mekate-Studio/Mobi/actions/runs/35645400892)
  passed classification, pinned quality setup/contracts/static checks, Android
  tests/build, iOS tests/build and the aggregate gate on commit `10319cd`.
  This is slice 2 hosted evidence; it does not validate this unpushed change.
- Local classifier fixtures pass, including both app manifests, dependency
  files, unknown/empty input, platform-qualified shared behavior and NUL filenames.
- Initial slice 3 validation passed 35 static contracts and 20 orchestration
  contracts under system Ruby 2.6.10 and pinned Ruby 4.0.6. They cover job order/counts,
  plan-only/docs behavior, new tests, rename/delete handling, environment filtering,
  content/mode/HEAD/index drift, staged Git-object binding, interruption and cleanup.
- The 2026-09-23 cleanup follow-up expands orchestration coverage to 27 passing
  contracts on both Ruby versions: scoped per-version shutdown, pinned Java,
  caller-cache preservation, missing/escaping launchers, redirected registries,
  shutdown failure/timeout and transient/persistent removal failures.
- Two post-adoption gate attempts passed all 50 native tests and both debug
  builds but failed cleanup. The removal retry alone did not fix the detached
  Gradle registry writer. Neither attempt is a gate pass; their inactive owned
  directories were inspected and removed.
- After explicit per-version shutdown was added, the full staged `check.sh`
  passed in **572.108 seconds**: pinned static checks, 38 Android/shared tests,
  12 iOS tests and both debug builds. The copied-source/index guards passed,
  all five recorded Gradle processes exited, and the native workspace and outer
  disposable staged checkout were removed. The caller index stayed unchanged.
  [Adoption evidence](evidence/2026-09-23-ios-adoption.json) binds this run to the
  adopted Swift pins and pending slice 3 source; later documentation edits are
  identified separately.
- The initial static probe passed with 39 ktlint, 36 detekt, 24 Swift and 44
  shell inputs in 5.754 seconds; the adoption run took 5.288 seconds. Classifier fixtures, Ruby
  syntax, whitespace checks and strict OpenSpec validation pass.
- An owned Android/shared-test probe passed 38 tests across five discovered
  modules in 61.687 seconds using the recovered probe's warm dependency cache.
  Its tracked-input manifest remained unchanged. Cleanup and subsequent metadata
  recovery are described above.
  The interrupted cold attempt printed passing tests but lacked a completion
  record and is not counted as a completed run.
- The local iOS probe and an exact `10319cd` archive both failed linking
  `swift-sharing`'s `Sharingdynamic-product` under Xcode 27.0 (27A266a).
  Both reported undefined `Sharing.SharedReader.__generation` and
  `Sharing.Shared.__generation` initialization symbols. Neither reached tests;
  tracked inputs stayed unchanged and both temporary workspaces were removed.
  The [source-bound evidence](evidence/2026-09-22-slice-3.json) records results
  separately from the successful hosted slice 2 run.

## Blockers

The original lockfile was incompatible with local Xcode 27. A subsequent
[isolated investigation](ios-xcode27-investigation.md) traced three failures to
Sharing, TCA and IssueReporting and verified a three-package candidate with
12 native tests passing twice, including fresh Xcode derived data. The candidate
was explicitly approved and adopted locally on 2026-09-23. The subsequent full
staged gate passed after fixing owned Gradle shutdown. No local iOS blocker
remains for this tested configuration. The historical baseline failures and
rehearsals remain separate from the adoption receipt. No Xcode or release
default was changed. Hosted validation of the exact integrated source remains
an outstanding integration gate.

## Untested assumptions and limits

- This slice has not run on hosted CI or native Intel. Slice 2's green run cannot
  substitute for the new orchestration and discovery behavior.
- Warm hosted cache restore has not been measured. The full local four-job
  staged path passed with empty owned caches and existing host prerequisites;
  it is not fully cold clean-clone or hosted evidence. Earlier standalone native
  probes preceded final guard refinements and retain their separate input
  hashes. Cold per-commit caches can be expensive; sharing mutable caller caches
  is deliberately deferred to the common executor work.
- Snapshot symlinks and unsupported module/test layouts fail explicitly. This
  implementation does not extend Kotlin/Native test coverage, add test targets,
  prove bridge retirement, or validate release packaging.
- Source checks detect persistent drift and bind copied bytes to Git objects.
  They are not an OS sandbox or a defense against malicious native build code,
  hostile local processes or transient edits entirely restored between checks.
- Effective dependency versions can differ from declared versions. The Android
  probe reported existing transitive overrides; that Android probe did not
  change declared dependencies. Complete resolved inventory/advisory policy
  remains slice 4.

Next: review this slice and the separately approved Swift update, then validate
the exact integrated commit through the existing hosted workflow. The next
implementation slice is the pinned dependency inventory; discovery/rehearsal and bridge retirement
remain separate work.
