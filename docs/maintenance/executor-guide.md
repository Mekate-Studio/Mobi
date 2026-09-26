# Isolated maintenance executor

Slice 5 adds a reusable execution and recovery protocol. Its public command runs
**synthetic Kotlin or Elixir fixtures**. It does not run native builds, change
Mobi dependencies or activate a backend. See [validation](fifth-slice-validation.md)
for measured results; real Toolchain rehearsal is the next adapter slice.

## Run a contract fixture

Use the existing pinned quality-tool setup. These commands need no Renovate,
Node, Kotlin, Xcode, Elixir, PostgreSQL, provider token or Codex installation:

```bash
./scripts/dev/dependency_updates.sh rehearse-fixture kotlin
./scripts/dev/dependency_updates.sh rehearse-fixture elixir candidate-failure
./scripts/ci/run_job.sh quality-contracts
```

The first command should return `checks_passed` with scope
`synthetic_adapter_contract`. The second intentionally returns `incompatible`
and exit 22. Available public cases are `pass`, `baseline-failure`,
`candidate-failure`, `missing`, `infrastructure`, `malformed`, `forged-success`,
`timeout`, `source-drift` and `child-survivor`.

The fixture's source is a temporary Git repository containing a dependency text
file. The executor captures those working bytes and Git identity, runs baseline
checks, then applies a checksum-bound replacement in an independent candidate
copy. A fixture database is a file in its own output directory. No database
server or backend application is created. The result explicitly lists native
builds, resolved graphs, provider evidence and release packaging as missing
capabilities; passing these fixtures cannot prove any of them.

Each run returns a `run_id`. Its private data lives under the ignored
`.maintenance/runs` store. The result JSON is suitable for review; journals,
command configuration and raw logs contain local paths and must stay local
unless separately reviewed and sanitized.

## Inspect, recover and clean up

Replace `RUN_ID` with the exact returned identifier:

```bash
./scripts/dev/dependency_updates.sh recover RUN_ID
./scripts/dev/dependency_updates.sh recover RUN_ID --stop
./scripts/dev/dependency_updates.sh cleanup RUN_ID
./scripts/dev/dependency_updates.sh cleanup RUN_ID --apply
```

`recover` inspects process ownership and the recorded outcome. `--stop` stops
only verified orphaned processes after acquiring the run lease. An active
coordinator holds that lease, so recovery and cleanup refuse to interfere.
Interrupt an active foreground run normally with Ctrl-C. Recovery never resumes
partial candidate work; a subsequent rehearsal creates a new run ID.

A killed coordinator can leave a journal without a final result. After processes
are quiescent, `recover RUN_ID --stop` records an inconclusive interrupted result.
It never replaces an existing result or promotes an earlier failure to success.

Cleanup without `--apply` is a dry run. Default retention is seven days for
successful workspaces and fourteen days for failed ones. To discard a reviewed,
inactive fixture's disposable copies sooner, use:

```bash
./scripts/dev/dependency_updates.sh cleanup RUN_ID --apply --discard
```

This removes only ledger-owned workspace directories. It preserves the original
result, append-only event history, process/check receipts and logs. Evidence has
a minimum policy retention of ninety days; automatic evidence deletion is not
implemented. `--discard` does not override uncertain ownership, active leases or
review holds. Cleanup failures remain separate from the original check outcome;
a retry verifies the recorded directory identity and continues idempotently.

Review holds are explicit:

```bash
./scripts/dev/dependency_updates.sh recover RUN_ID --hold
./scripts/dev/dependency_updates.sh recover RUN_ID --release-hold
```

If a marker, path, host, PID/start identity or history prefix does not match,
leave the resource intact and inspect the local journal. Do not repair a nonce
or edit a result to force cleanup. A crash between allocation and ownership
confirmation may require manual inspection; an unknown directory is never
removed merely because its name resembles a run ID.

## Execution contract

The common core accepts a schema-1 adapter plan containing an ID, scope, required
checks, missing capabilities, resource types and exact candidate edits. Checks
use argv arrays with an explicit executable and timeout; shell metacharacters
are passed as arguments. The first edit format only replaces existing source
files and requires matching before/content/after hashes. Creation/deletion,
version resolution and native dependency patch generation remain later work.

Only `filesystem` and `process-group` resources are supported. A required
PostgreSQL/simulator/container handler returns `incomplete` before checks start.
Independent fixture adapters live under `scripts/maintenance/fixtures/executor`;
the dormant production [Elixir profile](elixir-profile.md) remains unchanged.

The executor binds source bytes, HEAD/index, plan, patch, runtime/executable,
implementation and policy hashes. Working snapshots include nonignored untracked
files rather than silently substituting HEAD. Copies contain no caller Git
metadata, hooks or remotes. Baseline and candidate have independent source,
home, cache, temp and output directories. Authored source must remain unchanged
apart from the declared candidate edit; generated output belongs outside it.

Only declared environment names are passed to checks. Git/process inspection
also clears inherited environment and user Git configuration. Mobi's front door
uses the existing pinned Ruby; the independent core additionally runs under
system Ruby in contracts. No SDK/runtime installation happens during rehearsal.

`maintenance-execution-policy.json` sets a 45-minute outer ceiling, bounded
startup/termination grace and retention. Checks declare their own smaller limits;
there is no automatic retry or extension of the outer deadline.

A supervisor remains identifiable as group owner until its check and descendants
are quiescent. Startup/grant records close the unrecorded-spawn window: a worker
cannot start the check without the coordinator's nonce grant. Recovery compares
host, uid, PID, group, start identity and the random nonce in the live command
line. A PID or coarse `ps` timestamp alone is insufficient. On coordinator loss
the supervisor stops its own group; on timeout the coordinator verifies ownership
before TERM and again before KILL after bounded grace.

These mechanisms use Ruby's documented [process-group, environment and argv
options](https://docs.ruby-lang.org/en/4.0/Process.html) and
[file leases](https://docs.ruby-lang.org/en/4.0/File.html#method-i-flock).
They are an ownership protocol, not an OS sandbox against hostile code or a
malicious same-user process. A child that detaches into a different process
group is outside this first adapter contract. Real native daemons, simulators,
databases and shared caches need explicit handlers and negative probes before
using this executor; existing pre-commit and compatibility jobs are not migrated.

## Outcomes and evidence

| Result | Exit | Meaning |
| --- | --- | --- |
| `checks_passed` | 0 | The named check plan passed; no adoption authorization |
| `incomplete` | 20 | Required resource handler or prerequisite is missing |
| `inconclusive` | 21 | Baseline failed, infrastructure failed, deadline expired or execution was interrupted |
| `incompatible` | 22 | Passing baseline followed by an attributable candidate regression |
| `refused` | 23 | Source/plan/tool drift, candidate identity mismatch or invalid control input |
| `executor_failure` | 24 | Missing/malformed/contradictory result, supervisor or process-cleanup failure |

Recovery and cleanup return their own `operation` field. Operational success is
exit zero, ownership/lease refusal is 23, and cleanup failure is 24. This does not
change the original rehearsal outcome. Existing inventory/evaluation exit codes
remain as documented in the [inventory guide](dependency-inventory.md).

The result records binding hashes, named outcomes, attempted checks, elapsed
check time, exit status, environment names and log/result digests. Private
allocation/resource journals precede creation; completed results are written
atomically and never overwritten. An immutable prefix digest lets recovery
verify the original event history while appending later recovery/cleanup events.
Raw partial logs remain available for failed checks. A zero exit with absent,
malformed or contradictory check JSON cannot become a passing result.
