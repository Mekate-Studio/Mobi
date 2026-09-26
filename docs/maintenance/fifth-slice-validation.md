# Fifth slice: isolated maintenance executor

Status: implemented and locally verified on 2026-09-26; uncommitted for review.
Base commit: `313c714f8f1629dd6b9bf2ca49b144a005fcc7ef`. OpenSpec change:
`isolated-maintenance-executor`. See the [executor guide](executor-guide.md)
for commands and the [source-bound receipt](evidence/2026-09-26-slice-5.json)
for implementation, runtime, policy, output and log identities.

## Verified behavior

The existing maintenance command now exercises a common Ruby executor through
independent Kotlin and Elixir fixtures. Baseline checks must pass before a
candidate workspace is allocated. Each phase has separate source, home, cache,
temporary and output directories. Candidate replacements require matching input
and output hashes. The caller's source bytes and Git index remain unchanged.

The executor records allocation and resource intent before creation, retains
typed outcomes and partial logs, and requires an exclusive lease for execution,
recovery or cleanup. Process ownership combines host, uid, PID/group, start
identity and a random nonce in the live supervisor command. A coordinator grant
precedes check execution. Timeout and coordinator-loss contracts verify bounded
process termination, including children that ignore TERM.

Recovery cannot turn a failed run into a passing one. Cleanup defaults to a dry
run, respects retention and review holds, and removes only verified disposable
workspaces. Interrupted cleanup is retryable. Original results, journals and
check logs remain available after workspace deletion. Uncertain ownership is a
refusal, including changed PID identity, symlinks, replaced markers and truncated
event history.

The existing `quality-contracts` job includes the new executor suite. Workflow
YAML, native pre-commit execution, compatibility probes, dependency versions,
release defaults and schedules did not change. Actual native resource handlers
are required before those jobs can use this executor.

### Local checks

Host: Apple Silicon, macOS 27.0 build `26A428`. The public entry point and
integrated contract job used the repository's pinned Ruby 4.0.6. The executor
suite also passed separately under system Ruby 2.6.10.

| Check | Result |
| --- | --- |
| Existing repo-owned `quality-contracts` job | 112 passed: 35 static-tool, 27 pre-commit, 23 inventory and 27 executor contracts |
| Executor suite on system Ruby | 27 passed, zero failures |
| Existing static gate | Ktlint, detekt, SwiftFormat, SwiftLint and ShellCheck passed; 5.573 seconds total |
| Public fixture/recovery/cleanup commands | Five expected outcomes; all runs quiescent and disposable copies removed after explicit discard |
| Caller source/index guard around public probes | Unchanged; each published result excludes local absolute paths |
| Existing real pinned inventory extraction | `inventory_recorded`, 866 component occurrences across nine native manager groups; Elixir `not_applicable`, advisories `incomplete` |
| Ruby syntax, strict OpenSpec validation and whitespace | Passed |

The 27 executor contracts cover isolation between phases and concurrent runs,
baseline failure, candidate regression, missing prerequisites, infrastructure
failure, malformed or contradictory results, source/index/plan/tool drift,
literal argv handling and inherited-environment isolation. They also cover
timeouts, surviving children, TERM interruption, coordinator SIGKILL, lease and
hold refusal, PID/start/nonce mismatch, invalid resource ownership, partial
cleanup recovery and immutable result/history checks. Elixir's fixture database
is an isolated file; these tests do not start PostgreSQL.

### Public entry-point probes

Each row ran `dependency_updates.sh rehearse-fixture`, then `recover`, a cleanup
dry run and explicit `cleanup --apply --discard`. Timings cover the rehearsal
command, including its wrapper. Recovery found no live owned check processes;
cleanup preserved each original result byte for byte.

| Adapter / fixture | Outcome | Exit | Seconds |
| --- | --- | --- | --- |
| Kotlin / pass | `checks_passed` | 0 | 1.499 |
| Kotlin / candidate failure | `incompatible` | 22 | 1.478 |
| Kotlin / baseline failure | `inconclusive` | 21 | 1.212 |
| Elixir / pass | `checks_passed` | 0 | 1.594 |
| Elixir / timeout | `inconclusive` | 21 | 3.135 |

Both baseline-failure probes (explicit failure and timeout) stopped before
candidate allocation. Every result has scope `synthetic_adapter_contract` and
`adoption_authorized: false`. Baseline success followed by a fixture regression
proves the classification contract, not a real dependency compatibility result.

## Untested assumptions and limits

- Slice 5 has run locally on Apple Silicon only. Hosted execution, Intel macOS
  and Linux are unverified. Ruby standard-library use alone does not establish
  portable process inspection or onboarding behavior.
- Native builds, effective dependency graphs, upstream provider evidence and
  release packaging are explicitly missing from fixture results. No native app
  build/test was repeated for this Ruby executor slice. A passing SKIE/Gradle
  framework build or Swift export announcement would not fill these gaps.
- The ownership protocol is not an OS sandbox against hostile code or a
  malicious process running as the same user. Detached process groups, native
  daemons, simulators, databases, containers and shared caches need dedicated
  handlers and failure probes. Unsupported declared resources return
  `incomplete` before checks run.
- Candidate edits currently replace existing files only. Real version
  selection, patch generation, effective graph capture and native execution
  remain adapter work. Recovery records an interrupted result rather than
  resuming a partial run.
- Workspace retention is seven days after success and fourteen after failure.
  Evidence has a ninety-day minimum; automatic evidence deletion is not
  implemented. Private journals/control files and raw logs need separate review
  before sharing. A crash during allocation or an ownership mismatch can require
  manual inspection; unknown resources remain untouched.

## Blockers and next acceptance boundary

There is no known blocker to reviewing and integrating this fixture executor.
It cannot yet authorize a real dependency assessment: required native resource
handlers, effective Toolchain/compiler/plugin and target graph identities, and
fresh complete provider evidence are missing.

Slice 6 should implement the Kotlin Toolchain adapter first. Begin with a
passing baseline in owned resources, record effective tool and graph identities,
and prove timeout/interruption/cleanup for the actual processes involved before
rehearsing one explicit candidate. Failed baseline, missing graph evidence or
uncertain process ownership must prevent a compatible verdict. Preserve the
existing Xcode app/test targets, native tests, Swift sealed-state adapters,
compiler plugins, clean-clone path and release packaging requirements.

Keep current bridge-stack rehearsal separate from a direct Toolchain path with
the bridge unavailable. Neither slice 5 nor the next adapter alone is bridge
retirement evidence. The production Elixir/Phoenix profile stays dormant, with
its independent checks and PostgreSQL isolation requirements documented in the
[Elixir profile](elixir-profile.md).

## Slice 4 integration, separately verified

The integrated base commit `313c714` passed all seven jobs in
[hosted run 36185666930](https://github.com/Mekate-Studio/Mobi/actions/runs/36185666930):
classification, quality/contracts, Android/shared tests, iOS tests, both debug
builds and the aggregate gate. This is evidence for that exact earlier commit.
Hosted native Renovate extraction was not part of the run. Slice 5 still needs
its own normal integration checks after review.
