# Quality gate and dependency workflow design

Status: proposed, not implemented. See the [audit](audit.md) for current behavior
and the [implementation proposal](implementation-proposal.md) for ordering.

## Pre-commit contract

Choose **index equals checkout**, checked before and after validation. This
keeps failure recovery understandable and avoids hidden stashing. Manual lint
can inspect unstaged work, including new nonignored source; a commit gate must
reject it until the complete intended inputs are staged.

1. Discover inputs from Git plus the declared workspace, not from a fixed module
   list. In manual mode union tracked files and nonignored new files using
   NUL-delimited paths, deduplicate and verify existence. Deletions, modes,
   symlinks and renames are part of the input identity. Reject symlinks escaping
   the source root. Compiler-generated output is excluded by owned output-root
   configuration, never merely because a filename contains `generated`.
2. Parse `project.yaml`, every declared module, source-set/layout settings and
   referenced templates. Enumerate `src`, `test`, platform-qualified roots and
   explicitly configured roots; initially reject unsupported layouts rather
   than silently omit them. Kotlin scripts and all owned Swift/package sources
   need separate coverage. Keep vendored wrappers and embedded scripts explicit.
3. Before commit, reject unmerged entries, intent-to-add, unstaged tracked
   changes, nonignored untracked inputs and inputs outside the approved root.
   Initially reject all nonignored untracked files for an unambiguous contract.
   Use forced content comparison as well as Git diff; do not trust unchanged
   timestamps, assume-unchanged flags or sparse/skip-worktree omissions. Reject
   unsupported sparse/submodule cases until deliberately handled.
4. Capture index tree, source content/mode manifest, policy, scripts, analyzer
   versions/checksums and selected checks. These define the receipt identity.
   Check analyzers are installed and match approved pins; never download
   analyzer tools, upgrade dependencies, format, stage, stash or commit during
   the hook. Selected native jobs may populate owned caches with the existing
   Toolchain and declared dependencies; cold native setup requires network access.
5. Run static checks once, then impact-appropriate tests from the existing
   repository job contract. Test workspaces and generated artifacts are owned
   snapshots. Preserve current Android version fields for test mode; reject
   unexplained tracked mutations, including those caused by build preparation.
   Do not wire today's mutating Android prep directly into this gate.
6. Recompute the source and index identities after execution; check the
   snapshot's tracked input manifest too. Any drift invalidates the run even
   if analyzers passed. A successful receipt names exactly what was checked.

The hook and `just check` should converge on the same pre-commit implementation.
`just lint` stays a manual static check. `run_job.sh quality-check` remains the
static CI job; CI separately invokes selected test/build jobs, consuming the
same policy, tool pins and check IDs. Do not make the quality job run those
tests again. Local pre-commit orchestrates static + selected jobs once. CI is
independent defense in depth because local hooks are bypassable.

Conservative selection follows the existing classifier: behavior changes select
host/shared and affected native tests without an extra package build; UI,
resources, manifests, toolchain, dependencies, build/CI scripts and unknown
paths select native validation. Fix app-manifest case precedence first. For a
local staged change classify the complete index diff against HEAD; for an
integration review use the whole diff from the reviewed base. Deletions and
both sides of renames matter. Make path handling NUL-safe end to end.

A receipt cache can avoid rerunning an equivalent whole-tree gate during the
same integration, but only when source, base, policy, tools, environment,
selection and evidence freshness match exactly. Do not accept a human “already
ran tests” assertion as a receipt. Baseline, candidate and changed final content
are distinct inputs and need their own evidence. A receipt reuse path must
still perform current drift and required advisory-freshness checks.

## Common core and independent adapters

Keep a small repository tool rather than a new general-purpose framework.
Use the existing shell entry points and maintenance area. A reasonable first
implementation is a Ruby standard-library executor because Ruby is already
declared for mobile tooling. Pin/test its runtime explicitly; do not rely on
system Ruby. Validate this choice in the first executor slice before expanding
the core. No Go compiler, application profile or agent runtime is required.

| Common responsibility | Kotlin adapter | Dormant Elixir adapter |
| --- | --- | --- |
| Versioned JSON schemas; strict validation; policy and source hashing | Toolchain/module/bridge/SPM/gem/CI inventory | Elixir/OTP/Hex/tool/image inventory |
| Candidate eligibility and source evidence | Exact compiler/plugin/native/SDK compatibility assessment | Exact OTP/Elixir/framework/analyzer compatibility |
| Copy creation, process ownership, timeouts, logs, resource ledger | Repo-owned jobs, framework/app/native checks, Xcode result inspection | Mix commands, ExUnit, owned PostgreSQL, release compilation |
| Base/candidate diff, failure classification, review receipt | Dependency graph/export/architecture probes | Lock graph/Boundary/context behavior probes |
| Drift-safe adoption, recovery and cleanup | Kotlin-specific mutations only in candidates | Hex-specific mutations only in candidates |

Project configuration owns module roles, forbidden edges, build/test selections,
platform requirements, output roots, scan policy and behavior probes. The core
must not know names such as Home or Nearby Map. An adapter declares supported
schema version, prerequisites, discover/resolve/rehearse/validate actions,
owned resources and available capabilities. Actions return typed JSON and
execute argv arrays, never shell strings supplied by release notes. An absent
adapter reports `not_applicable`; explicitly requested but missing prerequisites
produce `incomplete`. Kotlin-only contributors need no Erlang/PostgreSQL.
Elixir-only consumers of the adapter need no Android SDK/Xcode/Toolchain.

Evolve [dependency_updates.sh](../../scripts/dev/dependency_updates.sh) as the
public front door; preserve `just deps` as safe discovery. The proposed verbs
are `discover`, `assess`, `rehearse`, `review`, `adopt`, `recover`, `cleanup`.
Slice 4 implements `discover`, `verify` and a limited `evaluate` evidence-contract
check, documented in the [inventory guide](dependency-inventory.md). Slice 5 adds
`rehearse-fixture`, `recover` and `cleanup`, described in the
[executor guide](executor-guide.md). Real native rehearsal, full assessment and
adoption remain interface proposals. `integrate` is the
separately authorized normal repository workflow, not an automatic push lane.
Consolidate the existing compatibility script behind `rehearse` rather than
creating a competing execution system.

## Lifecycle

| Stage | Inputs and operation | Required output and boundary |
| --- | --- | --- |
| Discover | Source snapshot + pinned providers; native Renovate managers first; extra extraction only for demonstrated gaps | Complete component/coverage ledger, raw candidate versions including blocked ones, source URLs, release times and failures; no manifest mutations in caller checkout |
| Assess | Exact candidate/coupled set; all intervening official release notes, migrations and relevant source changes | File/API/settings impact map, breakage/risk/unknown/feature separation, required probe plan, age/security decisions; no compatibility inferred from SemVer |
| Rehearse | Immutable reviewed source snapshot, verified exact artifacts, same check plan for base and candidate | Isolated baseline first, then exact candidate; full resolved dependency diff, logs, per-check outcomes, resource ledger and missing capabilities |
| Review | Evidence bundle and candidate patch | Human-readable diff and matrix; source/patch/policy-bound review decision. Technical success alone is not approval |
| Adopt | Explicit maintainer authorization for exact reviewed patch | Preconditions verified, patch applied without drift, final content validated; no push/publish/release or bridge removal by implication |
| Integrate | Authorized final content and review | Small integration into `main` under existing protections. Commit only if specifically authorized; rebase/merge changes invalidate affected receipts |
| Recover | Interrupted run ID + ownership ledger | Inspect and stop only proven owned processes/resources; append event; incomplete work never upgraded to success |
| Cleanup | Retention policy + ownership proof + dry-run plan | Remove only owned inactive disposable data; preserve evidence and record each removal |

### Discovery and release policy

Use a pinned Renovate executable or immutable image for supported manifests.
Pin its Node/runtime, checksum/digest and config/schema version. Resolve presets
to captured content/hashes. Toolchain wrapper/checksum, built-in catalogs,
compiler plugins, analyzers, Xcode/SDKs, runners and downloaded tool archives
need explicit coverage tests. Verify native extraction for Gradle catalog and
wrapper, Swift, Bundler and Docker rather than assuming a config proves a run.

Maintain two views: raw available releases and policy-eligible releases. Keep
ceiling-blocked, too-new, prerelease and unknown-date versions visible with
reasons. [Renovate minimumReleaseAge](https://docs.renovatebot.com/configuration-options/#minimumreleaseage)
helps where timestamps exist; the common policy evaluator must also handle
missing/failed providers and blocked candidates outside Renovate's filtered
output. Proposed default: stable channel, verified publication timestamp at
least seven full days old, majors separately reviewed, no automatic adoption.
Security exceptions require a recorded advisory, reason, exact scope and
maintainer decision; they do not waive tests or artifact verification.
Explicit prerelease experiments never become normal eligible upgrades.
An upstream release with a normal version number can still belong to an Alpha
product, as Kotlin Toolchain does; channel eligibility is not API-stability or
compatibility evidence.

Inventory direct and transitive resolved artifacts separately for each target
and compiler/plugin configuration. The Toolchain graph must come from supported
resolution/introspection or a versioned adapter proven against fixtures, not
assumed Gradle lockfiles. Follow `./kotlin --help` and `show … --help` on the
selected version before scripting its [documented introspection](https://kotlin-toolchain.org/latest/cli/).
Capture platform variants, repository identities, artifact digests, Kotlin
stdlib/Native libraries, Compose built-ins, plugin dependencies and constraints.
Bridge-only and Toolchain-only artifacts must remain distinguishable.

Compare resolved graphs by package identity, variant, version, checksum and
dependency edges; include additions/removals and changed artifacts at unchanged
versions. Count expected managers/modules against successful results. Missing
pages, truncated API results, unresolved artifacts or empty output from a
failed parser produce a coverage gap, never “no updates.”

Proposed vulnerability policy: every required ecosystem scan uses the exact
resolved input and a successfully refreshed advisory snapshot no older than
24 hours. Record provider, advisory revision/digest, fetch time, scan time,
ecosystem mapping and coverage. An unchanged pinned input may reuse a matching
fresh receipt offline; missing, stale or unavailable required data fails the
gate as incomplete. Findings block according to a versioned severity/exception
policy; unknown severity requires triage. Start by blocking unsuppressed high
and critical findings, report all findings, and document narrower exceptions
with expiry. Low findings must not be silently discarded. This policy is a
proposal, not current coverage. Secret scanning is local and independent of
advisory availability.

### Isolation and execution

Copy a selected commit/tree or an explicitly captured dirty-source snapshot
into an owned run directory. Record all included untracked files and patch
hashes for a dirty snapshot; do not silently substitute HEAD. Use independent
Git metadata, exclude credentials/ignored build products, disable inherited
hooks and remote writes, and do not share mutable lockfiles with the caller.
A copy is preferable to a linked worktree for the first executor because it
avoids registration/cleanup mutations in the caller's `.git`.

Use a journal written before each resource creation. Record canonical root,
nonce, host, process group and process start identity, child ownership,
workspace, caches, simulator IDs/database names, creation/heartbeat time and
cleanup state. PIDs alone are insufficient because they can be reused.
Pass only declared environment variables; strip signing/provider secrets and
store-upload endpoints from normal runs. Separate the read-only discovery
credential scope from test/build credentials. Do not dump environment values.

Kotlin runs scope bootstrap/user/temp/Gradle caches, Xcode DerivedData, SPM
checkout caches and result bundles. Repository wrappers need explicit cache
arguments wherever Xcode otherwise writes to shared user locations. Simulator
creation uses a run-owned device ID and deletes only that device. Keep an
explicit warm-cache experiment separate from a cold bootstrap. Never let a
candidate consume the baseline's built framework or compiled caches; verified
immutable downloads may be reused only when the run declares it is not cold.

Default baseline and candidate command limits must be declared per check;
initially inherit the existing 45-minute compatibility ceiling as an outer
bound, then calibrate using measured runs. On timeout send TERM to the owned
group, allow a bounded grace period, then KILL only verified descendants.
Record truncated/incomplete logs and the interruption point. Do not retry a
compiler incompatibility automatically. Bounded network retries retain each
attempt and do not reset the total deadline. Baseline failure stops causal
candidate comparison; a diagnostic-only candidate run must stay inconclusive.

## Evidence contract and result states

The following are required fields of the proposed versioned result schema:

| Group | Fields |
| --- | --- |
| Identity | schema version, run/parent ID, UTC start/end, stage, adapter/version, execution-tool hash, source commit/tree/content hash, clean/dirty capture mode |
| Inputs | exact base/candidate version tuples, candidate patch hash, policy/config/tool hashes, lockfile hashes before/after, artifact checksum verification |
| Sources | canonical primary URL, release/tag/commit or advisory identity, published/retrieved timestamps, raw response hash, response status/pagination completeness, claim supported |
| Resolution | direct/transitive graphs per target, full graph diff, unresolved nodes, managers expected/observed, ceiling/age/security classifications |
| Environment | OS/architecture, selected Xcode/SDK/compiler/JDK/Gradle/Ruby versions, permitted environment names with safe values only, warm/cold cache mode |
| Execution | argv, working directory relative to run root, start/end/duration, exit/signal/timeout, process ownership, redacted stdout/stderr hashes, test/result artifacts |
| Evaluation | each check's required/optional/not-applicable status, outcome and causal reason, covered/missing capabilities, matrix change and blocking findings |
| Review/resources | review identity/decision and exact patch binding, resource ledger, recovery/cleanup events, retention and redaction manifest |

Logs remain immutable within a run; append follow-up events instead of rewriting
failure history. Results must be written atomically even when a subprocess
crashes. Public reports use relative paths and sanitized excerpts. Never publish
credentials, signing identities, simulator personal data or raw absolute user
paths. Hash sensitive values only when useful and safe; prefer omitting them.

| Result | Meaning | Proposed CLI exit / review behavior |
| --- | --- | --- |
| `incomplete` | A required input, artifact, provider, prerequisite or check is absent/unavailable | 20; cannot review as ready |
| `inconclusive` | Baseline failed, run interrupted/timed out, or failure cause cannot be assigned | 21; rerun after recovery with a new receipt |
| `incompatible` | Comparable passing baseline, attributable candidate failure | 22; keep concrete failure and next probe |
| `checks_passed` | The named check set passed, with its coverage limits | 0; not adoption approval; missing retirement rows remain missing |
| `ready_for_review` | Complete required evidence, policy eligibility and assessment | 0 plus explicit state; waits for human decision |
| `review_rejected` / `adopted` | Separate decision/execution events bound to evidence | Rejection prevents adoption; adopted requires final validation |

Exit 23 can represent policy/drift refusal and 24 executor/internal failure;
the result reason distinguishes them. Individual static checks can use ordinary
nonzero findings exits, normalized by the executor. Artifact hash mismatch is
an integrity failure, never an invitation to update the expected digest.
Malformed/missing result JSON is executor failure even if a child exited zero.
Use a separate notification field for actionable changes; never exit 2 merely
because compatibility was found. A scheduled runner may classify expected
incompatibility as a completed observation, but its result must visibly remain
non-compatible and must never be consumed as a green compatibility receipt.

## Adoption, recovery and cleanup

Adoption is interactive/manual and disabled in scheduled clients. Require the
exact reviewed base tree, candidate patch, policy and required receipts. Reject
dirty checkout, changed manifests/locks, expired advisory evidence, changed
candidate bytes or unexplained source drift. Apply a checked patch atomically
after preflight; validate resulting files and native checks required by impact.
If validation fails, stop with the visible diff and a recovery plan. Do not
overwrite new user work with an automatic reset. An interrupted apply should
compare current bytes with the journal's before/after bytes before offering
restoration. Receipt reuse follows the strict identity rules above.

`recover RUN` inspects the journal and reports owned survivors. If process or
resource ownership cannot be verified, record the blocker and require explicit
selection instead of killing by process name, port or directory glob. Restart
baseline/candidate comparison after interruption; do not continue from an
unknown partially generated framework.

`cleanup` should default to a dry-run list. Proposed retention: keep successful
disposable copies seven days, failed/interrupted copies fourteen days, and
sanitized evidence ninety days or longer for a reviewed integration. Retention
is configurable and subordinate to active-run leases/review holds. Resolve
canonical paths, reject symlink traversal and refuse paths outside the owned
root. Delete only ledger-owned caches, simulators, copies and trial databases;
never a user's global cache, main checkout or arbitrary database. Cleanup failure
is recorded separately from test outcome and is retryable/idempotent.

## Acceptance properties of the reusable core

Use contract fixtures for both adapters without bootstrapping either mobile or
backend tools. Exercise unavailable provider, missing timestamp, changed bytes
at the same version, hash mismatch, unsupported manifest, empty extraction,
baseline failure, candidate compile failure, malformed logs/results, timeout,
TERM/KILL interruption, stale lock, PID reuse, concurrent runs and cleanup
failure. Deliberately introduce semantic regressions and verify they change the
result. Check recovery after removal of the regression. No test should pass
merely because it repeats implementation branches.

Keep the code under Mobi's existing license/contribution conventions and the
documentation public-safe. Demonstrate Kotlin-only use and a fixture-backed
dormant Elixir contract before discussing independent packaging. A human can
perform the [review playbook](dependency-review-playbook.md); an optional AI
skill may invoke commands and help interpret upstream changes, but scripts must
enforce every safety and evidence rule without that skill.
