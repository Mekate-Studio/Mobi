# Dependency compatibility watch

Slice 8 connects the existing weekly workflow and its manual entry point to the
[isolated compatibility evaluator](compatibility-runner.md). It discovers public
release leads and compares observations. It never selects a new candidate,
adopts dependencies, changes support policy or qualifies bridge retirement.
See the [validation record](eighth-slice-validation.md) for actual execution.

## Run locally

Use an Apple Silicon Mac with Xcode, Android SDK and Java 21, following the
[README](../../README.md) setup and [Kotlin preparation](kotlin-rehearsal.md).
The watch needs the pinned quality runtime and reviewed Kotlin distributions;
it does not require Renovate, GitHub authentication or an AI service. Hosted runs
use the existing read-only workflow token for public release queries to avoid
unauthenticated access failures. Local callers may optionally set
`MOBI_WATCH_GITHUB_TOKEN`; the token is neither retained nor passed to native jobs.

```bash
./scripts/dev/dependency_updates.sh prepare-kotlin
./scripts/dev/dependency_updates.sh watch-compatibility \
  --output .maintenance/watch-reports/first
./scripts/dev/dependency_updates.sh watch-compatibility \
  --previous .maintenance/watch-reports/first/snapshot.json \
  --output .maintenance/watch-reports/next
```

The old `scripts/ci/check_skie_kotlin_compatibility.sh` entry point forwards to
the same command. Output directories must be new and below the ignored
`.maintenance/watch-reports/` directory. Omit `--output` for a unique directory.
Legacy `SKIE_COMPAT_*` environment overrides are refused: review the candidate
and source evidence in `maintenance-compatibility.json` instead. Keep source and
index unchanged while a probe runs; all transformations happen in owned copies.

## Evidence and meaning

The Kotlin adapter queries the first 30 GitHub release records for Toolchain,
Kotlin, Metro and SKIE. It excludes drafts, GitHub prereleases and semantic
prerelease tags, including RC tags incorrectly marked stable upstream. Unknown
tag formats, absent timestamps, future dates, rate limits, malformed responses
and network failures yield explicit incomplete provider evidence. Each available
response has its URL, UTC retrieval time, content digest and HTTPS client digest.
The system HTTPS client verifies certificates; credentials used for hosted history and releases
are supplied through standard input, never command arguments. The pinned Ruby
runtime does not have an OpenSSL extension.

Newer stable versions are classified against the reviewed tuple and configurable
seven-day age policy. Major changes and versions still too young are visible.
An eligible release is only a review lead. This bounded page is **not a complete
release interval, dependency graph, vulnerability audit or semantic migration
assessment**. The watch does not refresh OS release policy or direct-integration
documentation; those require the separate support and compatibility assessments.

Only the reviewed `bridge-compile` profile executes. It runs the unchanged
baseline before the candidate, verifies effective Kotlin settings, KLIB compilation
and framework linking, and reads the common source-bound result. Direct-path
prerequisite states come from reviewed configuration. Native app/test, device,
release, clean-clone, lifecycle, incremental and retirement requirements remain
missing capabilities in this narrow observation.

| Output | Meaning |
| --- | --- |
| `discovery.json` | Normalized release leads, provider failures and available source identities |
| `native-report.json` | Verified evaluator result, baseline/candidate cells, source bindings and path-free setup exception diagnostics |
| `recovery.json`, `cleanup.json` | Owned-resource recovery and disposable-workspace cleanup outcomes |
| `snapshot.json` | Versioned, digest-bound semantic observation and comparison scope |
| `report.json`, `summary.md` | Operation state, assessment state, changes and explicit gaps |
| `probe-failure.json`, if present | Controlled exception class/stage; private exception text is excluded |

`operation_state: observation_recorded` means the observation and owned cleanup
completed. Its assessment may still be `incompatible`, `inconclusive` or
`incomplete`. Provider failure cannot become “no updates”; nominal compile success
cannot close missing capabilities. Invalid native evidence, ownership refusal,
executor failure or unsafe cleanup makes the watch operation fail with exit 1.
Every result has `adoption_authorized: false` and `bridge_retirement: defer`.

## Quiet comparison and existing hosted caller

The common snapshot/comparison library is separate from the Kotlin provider and
probe adapter. It ignores run IDs, acquisition times, durations and log hashes
when comparing observations. Version/age eligibility, provider blockers, required
cells and assessment changes remain meaningful. Candidate/policy/build-input
changes reset comparison; documentation-only edits do not. A candidate cell
changing from passed to failed is called a compatibility regression only when
the evaluator attributes the current result to incompatibility. Infrastructure
or unattempted cells are changes in evidence, not proof of a regression.

Unchanged observations produce no workflow annotation, even when they retain a
known incompatibility or provider gap. Every run still records its actual status
and summary. Missing, corrupt, future-dated, expired (31 days), out-of-scope or
unavailable history cannot suppress notification. The first observation is explicit.

The existing `Dependency Compatibility` workflow retains its manual trigger and
Monday 05:23 UTC schedule. No schedule is added. It uses an Apple Silicon
`macos-26` runner, prepares declared runtimes, serializes same-ref executions,
and reads the latest completed same-workflow/same-branch run via the Actions API.
Its snapshot is downloaded with read-only permissions. A failed download is a
history gap, never an unchanged verdict. Snapshots and public evidence artifacts
are retained for 90 days; restore selects the latest observation rather than
silently skipping failed runs to find an older passing one.

Meaningful changes emit a controlled Actions notice/warning and a step summary.
This does not promise email delivery and does not publish issues, pull requests
or releases. A green watch job describes operation completion; read the separate
compatibility assessment. Hosted uploads are restricted to the new public report
directory. Raw native logs, process/resource identities and host paths remain in
the local ignored run store. Hosted summaries retain their hashes but do not
retain the full raw log chain after the runner disappears.

## Recovery and adoption review

The watch requests recovery, stops only verified owned resources, and removes
only its disposable workspaces after proving quiescence. Run evidence remains in
`.maintenance/runs-compatibility-watch`. If interrupted, use its run ID:

```bash
./scripts/dev/dependency_updates.sh recover RUN_ID --stop --store compatibility-watch
./scripts/dev/dependency_updates.sh cleanup RUN_ID --store compatibility-watch
./scripts/dev/dependency_updates.sh cleanup RUN_ID --apply --discard --store compatibility-watch
```

Inspect the dry-run cleanup first. Do not edit ownership markers or force-delete
an uncertain store. A recovered run needs a new watch observation; missing evidence
is not retroactively made successful. Reverting the workflow caller is the
integration rollback; no production tuple or release default needs reverting.

A changed watch is input to discover → assess → rehearse → review → adopt.
Use the existing full mobile and direct-facade profiles when appropriate, complete
release-interval/advisory/graph review, assess supported architectures and OS
minimums, and present support loss or architectural tradeoffs to the maintainer.
Adoption requires an explicit decision bound to the reviewed source and changes.
Bridge retirement remains a separate deferred decision. Elixir stays dormant.

## Primary references

- [GitHub releases API](https://docs.github.com/en/rest/releases/releases?apiVersion=2022-11-28): release metadata and pagination boundaries.
- [Workflow runs API](https://docs.github.com/en/rest/actions/workflow-runs?apiVersion=2022-11-28): read-only same-workflow history.
- [Hosted runner specifications](https://docs.github.com/en/actions/reference/runners/github-hosted-runners): `macos-26` architecture.
- [Artifact download](https://github.com/actions/download-artifact) and [artifact upload](https://github.com/actions/upload-artifact): cross-run access, retention and explicit hidden-path inclusion.
- [Workflow commands](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands): annotations and step summaries.

These sources were checked on 2026-09-29. Repository contracts and measured runs,
rather than the existence of an upstream feature announcement, establish coverage.
