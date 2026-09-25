# Fourth slice: pinned dependency inventory

Status: implementation and local verification completed on 2026-09-25. Base commit:
`2a2577db135cb992a4599b78ae161715d05159d6`. OpenSpec change:
`pinned-dependency-inventory`. See the [inventory guide](dependency-inventory.md)
for commands and the [source-bound receipt](evidence/2026-09-25-slice-4.json)
for input, tool, output and log identities.

## Verified behavior

The old ambient Renovate/npx lookup and optional OSV skip have been replaced by
explicit installation, offline receipt verification, isolated native extraction
and conservative evidence evaluation. `just deps` now produces inventory JSON;
it does not mean that available updates or advisories were queried. The existing
hosted Renovate configuration, compatibility probe and schedules are unchanged.

A real Apple Silicon installation verified the official Node 24.21.0 archive,
installed Renovate 44.93.5 with npm 11.19.0 and the complete reviewed lock, and
checked exact versions. Lifecycle scripts were disabled. A fresh probe of the final installer in an
empty temporary directory passed in 22.181 seconds, verified 45,111 installed
files and removed the owned directory. Missing/empty/changed
receipts, lock drift, archive traversal and unowned repair are rejected. Normal
discovery verifies every installed file and never downloads fallback tools.

Native extraction uses an owned source copy with no caller credentials, temporary
home/cache/base paths and an explicit execution configuration. Source file lists,
bytes and executable modes are checked; copied-file additions also fail. Failed
processes, source mutations and timeouts cannot return successful evidence.
Disposable failure fixtures prove cleanup leaves unowned siblings intact.

### Captured coverage

The repeated real extraction contains **866 component records**, representing
separate declaration, lock, tool and environment occurrences, not 866 unique
packages. All seven declared modules are inspected without a module allowlist.

| Surface | Captured result | Limit |
| --- | --- | --- |
| Native Renovate | Nine manager groups: Bundler, Dockerfile, Actions, Gradle, wrapper, npm, Ruby version, Swift and custom regex | Extraction is declarations, not candidate lookup or target resolution |
| Kotlin modules | All seven modules, Maven dependencies, annotation/compiler plugins and explicit SDK/compiler/Compose settings | Effective compiler, implicit runtime and per-target graphs remain missing |
| Gradle bridge | Catalog, scripts/properties and wrapper from native managers | Effective Native variants/artifact graphs remain missing |
| Xcode/Swift | Four Xcode package declarations inspected independently of the three Package.swift declarations; 15 locked packages/revisions | Lock has no target graph edges; declaration membership classifies direct versus transitive |
| Ruby tooling | 99 locked gem records, dependency constraints, direct/transitive classification, Bundler pin | Effective platform and artifact identities require rehearsal |
| Maintenance npm | 614 locked package entries with integrities, locations, constraints and optional/direct/transitive status | Installed optional subset is platform-specific |
| Tools/environment | Quality and maintenance pins, Toolchain wrapper checksum, SDK/Java/Swift/runner/image declarations | Floating image/OS packages and effective host identities are explicit gaps |
| Elixir | `not_applicable`, dormant required-check list | No backend/tool/service provisioned |

Native output records the RE2-to-JavaScript-regex fallback and missing GitHub-token
warning. The custom regex managers actually extracted module/compiler inputs.
Bundled presets are resolved from the pinned installation; full resolved config,
shallow config and enforced execution config have separate hashes. Nine inherited
ceiling rules are captured beyond Mobi's two explicit ceilings. The limited local
evaluator does not implement those inherited rules and records a required policy
gap. No preset constraint is silently treated as passed.

### Checks

| Check | Result |
| --- | --- |
| Inventory contracts | 23 passed under system Ruby 2.6.10 and pinned Ruby 4.0.6 |
| Existing static-quality contracts | 35 passed under pinned Ruby 4.0.6 |
| Existing pre-commit validation contracts | 27 passed under pinned Ruby 4.0.6 |
| Repository static gate | Five pinned analyzers passed; no new rule exceptions |
| Real discovery repeat | Matching source, tools, component/coverage/lock records and config identities; timestamps, inventory IDs and raw-log hashes may differ |
| Empty evidence against real inventory | `incomplete`, exit 2; missing advisories and required gaps remain visible |
| Tool verification/reuse | Verified existing installation; discovery did not reinstall |
| OpenSpec, Ruby/shell syntax, whitespace | Passed |

Fixtures cover seven-day boundaries, new/old/major/prerelease/ceiling-blocked
candidates, missing/future/unzoned timestamps, failed/stale/incomplete providers,
exact input mismatches, missing/duplicate advisory receipts, unknown severity,
high/critical findings, source drift, unsupported conditional policy and native
file/module/plugin omissions. Synthetic provider receipts exercise the evaluator;
they are not upstream vulnerability or release evidence.

The existing hosted quality job now calls `run_job.sh quality-contracts`, using
the already pinned Ruby runtime for all three contract suites. This adds no
separate workflow or schedule and does not bootstrap Node or contact providers
in ordinary quality checks.

## Untested assumptions

- Only Apple Silicon executed the maintenance tool install and real extraction.
  Node archives for Intel and Linux have reviewed official checksums but have not
  run here. Mobi's current front door reuses its macOS quality runtime; standalone
  portability is a common-core contract, not a verified Linux onboarding claim.
- Slice 4 hosted validation is not recorded here. The passing hosted run below
  validates slice 3, not these new files. The evidence receipt preserves the
  pre-integration source snapshot and does not claim an exact-commit hosted pass.
- Source guards and owned copies are not protection against hostile local code,
  restored transient writes or abrupt host failure. Cleanup after SIGKILL/crash
  needs the inspection procedure in the guide.
- Supplied provider URLs/digests are structurally checked, not authenticated or
  fetched. Complete response acquisition and review remain required.

## Blockers to a complete dependency assessment

There is no implementation blocker to using this inventory. A clean end-to-end
assessment is deliberately blocked by missing Toolchain and bridge resolved
target graphs, Swift target edges, effective gem platforms/artifacts, host and
image identities, full inherited candidate policy, and fresh advisory evidence
for every required input. Release discovery has not been requested. The inventory
reports these gaps rather than an empty or clean dependency result.

The next small slice is the shared owned-execution protocol: fake Kotlin/Elixir
adapters must prove baseline-first execution, resource ownership, interruption,
failure retention, recovery and cleanup before adding candidate edits/native
rehearsals. Kotlin Toolchain rehearsal remains the first real adapter priority.
Current bridge upgrades and direct Toolchain parity continue as separate tracks.
No bridge removal, mobile dependency adoption or release-default change occurred
in slice 4.

## Slice 3 integration, separately verified

The authorized commit `2a2577d` was pushed to `origin/main`. Its normal commit hook
passed 38 Android/shared tests, 12 iOS tests, both debug builds, static checks and
source/index/cleanup guards. [Hosted run 36127364544](https://github.com/Mekate-Studio/Mobi/actions/runs/36127364544)
passed all seven jobs, including the aggregate gate. GitHub accepted the direct
push using the account's existing branch-rule bypass; no repository rules changed.
The Xcode 27 compatibility issue is resolved for the recorded local configuration,
and the exact integrated source also passes the existing hosted iOS test/build
jobs. Neither result proves direct Toolchain parity or release packaging.
