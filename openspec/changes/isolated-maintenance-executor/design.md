## Context

See proposal.md. Slice 4 is integrated at `313c714` with every hosted job passing.
Its Ruby core already captures source manifests and isolated native extraction.
The pre-commit runner has a separate, tested native lifecycle with scoped Gradle
shutdown; migrating that path now would broaden this slice unnecessarily.

## Goals / Non-Goals

**Goals:** A small independently testable execution protocol, source-bound
baseline/candidate receipts, durable process/resource ownership and recovery.

**Non-Goals:** Native SDK execution, real dependency edits, provider acquisition,
release/advisory completeness, backend activation, resource handlers for real
simulators/databases, automatic adoption or migration of existing native jobs.

## Decisions

- Reuse the source manifest and standard-library runtime. Capture working bytes,
  HEAD and index identity explicitly; never substitute HEAD for dirty inputs.
  Use plain independent copies, without Git metadata/hooks/remotes. Each phase
  gets separate home/cache/temp/output directories. Generated output belongs
  outside authored source and is never reused across phases.
- Bind adapter schema/id, check argv and executable hashes, candidate edits,
  execution implementation, policy and source hashes. First-version candidate
  edits replace declared existing files only, with before/after checksums. Reject
  unsupported resource types before execution. Commands are argv arrays from
  reviewed repository adapters, never strings extracted from provider text.
- Create an allocation journal before the run directory. Atomic journal/result
  writes and append-only events preserve original failure history. A file lease
  excludes concurrent run/recover/cleanup actions. Private journal paths/nonces
  remain local; public results use relative paths, environment names and hashes.
- Keep a small Ruby worker alive as process-group owner. Its startup receipt,
  random command-line nonce, host, uid, pid, process-group and start identity
  must agree before signals are sent. The worker waits for authorization before
  executing a check; lost coordinators and expired deadlines stop its own group.
  PIDs alone never authorize recovery. Escaping process groups are unsupported
  by this first protocol; real daemon/resource handlers need separate evidence.
- Run the identical required check plan on a passing baseline, then apply the
  exact candidate edits in a fresh copy and run it again. Typed result JSON and
  process exit must agree. Baseline failure/timeouts/interruption are inconclusive;
  attributable candidate regression is incompatible; missing prerequisites are
  incomplete; malformed results are executor failures; drift is a refusal.
- Keep failed and successful copies until explicit cleanup. Default retention is
  seven/fourteen days; review holds and active leases prevent deletion. Cleanup
  defaults to inspection; explicit discard can remove a verified inactive run's
  disposable directories early. Journals/results stay available (at least the
  proposed ninety-day evidence retention; no automatic evidence deletion here).
  Recovery never resumes partial candidate state: rerun creates a new run ID.
- Expose fixture execution and recover/cleanup through the current maintenance
  entry point. Independent fixture adapters demonstrate Kotlin and Elixir
  contracts without importing either application/toolchain. Fake database/cache
  ownership is represented by files only, never a live PostgreSQL service.

## Risks / Trade-offs

- Ownership checks are not an OS sandbox against hostile code or a malicious
  same-user process → explicit supported-process contract and fail-closed recovery.
- POSIX process inspection differs by host → execute macOS contracts now; keep
  Linux unverified until run there. Combine start identity with a random worker
  nonce rather than trusting coarse `ps` timestamps alone.
- An abrupt host failure can leave allocation intent without a complete marker
  → retain and report uncertain ownership rather than deleting by directory name.
- Native build tools daemonize → retain the existing pre-commit runner and add
  native resource handlers only in a separately tested slice.

## Migration Plan

Add the executor and contracts beside inventory. Existing commands keep their
semantics; no schedule calls the new executor. Demonstrate fixture scenarios,
record exact input/results and recovery, then review slice 6's Kotlin adapter.
Rollback removes this additive entry point and leaves existing native jobs intact.
