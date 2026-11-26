# Automated local release assessment

`assess-releases` collects official changes and qualifies a candidate in owned
copies of the current app. It writes one local packet; it creates no PR and
grants no adoption, age/risk exception, merge, signing or retirement approval.
Complete local assessment precedes approval for the exact packet and one
adoption PR, as defined in the [playbook](dependency-review-playbook.md).

The automation prerequisite remains open while required stages report gaps.
An incomplete packet is evidence of a blocker, not permission to resume manual
new-release investigation. The older [compatibility watch](compatibility-watch.md)
remains available for historical reviewed-tuple comparisons.

## Run and inspect

Use the README's Apple Silicon/Xcode/Android setup, installed pinned quality
tools and the same reviewed native Java build as Mobile CI. Select `JAVA_HOME`
explicitly; a Homebrew alias is not an identity check. Set `ANDROID_HOME` to
the installed SDK. An explicitly selected supported Maven endpoint is retained
in the host receipt; there is no automatic endpoint fallback.
Credentialled or query-bearing Maven endpoint overrides are refused before a
host receipt is written. Optional
`MOBI_WATCH_GITHUB_TOKEN` is used only for public GitHub API requests, through
standard input, and never forwarded to builds or retained in evidence.

```bash
./scripts/dev/dependency_updates.sh assess-releases
./scripts/dev/dependency_updates.sh verify-release-assessment \
  .maintenance/release-assessments/<run-id>/report.json
```

The first command prints decision counts, the qualified candidate and the ignored report directory.
Read `summary.md` for decisions and blockers. `report.json` binds source, policy,
candidate patch, provider receipts, applicability, constraints, native results,
security and cleanup. Provider bodies and native logs remain ignored locally or
in artifacts. The verifier checks exact contents and freshness; verification of
an incomplete packet does not make it ready for adoption. Source, patch, policy
or evidence drift requires a fresh assessment before requesting approval.

Exit 0 means the bounded assessment has complete required evidence; exit 2 means
it recorded an incomplete assessment. Exceptions fail the operation. A passing
native build alone never produces an adoption recommendation.

## What is assessed

The current declared Toolchain, Kotlin exporter, Metro, TCA, Clocks and
Concurrency Extras are read from actual source and Swift locks. GitHub releases
and tags include stable and all recognized prerelease labels. Maven metadata is
cross-checked for the actual Toolchain publication, exporter and Metro coordinates. Versions without
official release notes, source tags or publication dates remain visible with
explicit gaps; fetch time is never substituted for publication time. Truncated
catalogs cannot mean no updates. Unpublished nightlies and other dependency
families are outside this bounded provider scope.

One age-eligible candidate is fully attempted per run, with provider rotation
recorded in the existing history snapshot. Other versions remain age-blocked,
incomplete or budget-deferred. Candidate preparation changes only owned copies;
it never relaxes reviewed exporter/output guards or Renovate ceilings. Existing
baseline inconsistencies are distinguished from newly exceeded ceilings.

The official commit interval includes source, configuration and documentation.
A bounded exact Git diff replaces truncated/missing GitHub patches. Deterministic
declaration, effect and configuration analysis maps changes to actual Mobi source
and registry replacement/retirement obligations. Symbol matches are possible
consumers, not proof of ownership or behavioral equivalence. Unsupported formats
and opaque runtime binaries remain gaps. Kotlin/Toolchain updates additionally
collect dated official Kotlin Swift-export docs and implementation, the official
sample as supporting guidance, and KT-64572/KT-80305 snapshots. Issue closure or
a release never establishes workaround retirement.

Both baseline and candidate run static quality, all maintenance contracts, the
Android/shared tests, iOS PullRequest test plan and both Debug builds. A failed
baseline is inconclusive; only a passing baseline and classified candidate
failure can establish a candidate regression. Infrastructure failures stay
separate. Device/exact-OS-floor, restoration, Shared Home UI and signed delivery
acceptance are separate capabilities.

Security compares fresh OSV records for named module graphs, locked Swift
commits, observed delegated Gradle configurations and embedded Maven claims
bound to downloaded JAR hashes. Both phases' advisory query batches run before
shared finding records are fetched once; archive checksum leads run afterward.
Each receipt reports `advisory_state` independently from its broader provider
state, so checksum-budget exhaustion cannot erase completed advisory coverage.
Partial byte/provenance evidence still blocks adoption and keeps the existing
finding-comparison guard conservative. The existing owned Gradle observer and compiler
telemetry reader capture selected plugin paths and artifact identities. Their
unsupported AGP/transform APIs and unrehearsed target scopes remain gaps. Published
checksums provide independent reference leads where available. Embedded claims
are not selected classpath or shaded-code attribution. Unassigned archives,
missing owner provenance, unsupported locks, partial provider pages and unknown
severity remain blockers; old scoped risk grants are never transferred. Findings
do not establish exploitability or runtime reachability. A partial provider pair
retains observations on each side but cannot label absent findings as resolved
or introduced.

## Bounds and existing weekly caller

The existing Monday 05:23 UTC workflow and manual dispatch call this command;
there is no second schedule or required AI/private service. It retains its
read-only token, same-branch history and 90-day artifact policy. History from the
older evaluator resets because the assessment scope changed. A compact summary
goes to the Actions summary; incomplete assessment exits remain visible.
Configured local app automations were also checked; none targets Mobi.

Each checkout permits one leased assessment at a time, with concurrency one,
a 45-minute assessment deadline, a
25-minute per-phase check cap, 128 official HTTP requests, four 100-row pages per
catalog, 4,000 versions per Maven metadata response, 8 MiB per HTTP body and a fresh URL/payload cache that lasts only that
run. Exact source transport has 120 seconds, 512 MiB storage, 2,000 files and
16 MiB total patch text. Archive inspection and reference requests have separate
bounded counts. Evidence export caps at 256 MiB and excludes workspaces/caches.

Qualification requires 14 GiB available before allocating one phase.
Test and Debug jobs share Swift package checkouts only within that phase;
their DerivedData directories remain separate, and baseline/candidate phases
never share those checkouts. Normal and explicit cold-validation behavior stays
unchanged.

Successful phase workspaces are deleted only after managed processes/resources are stopped,
before the next phase; logs and hashes survive. Failed workspaces remain under
the existing ownership/recovery protocol until final explicit runner cleanup.
This reduces simultaneous disk use without weakening source/resource checks.
Host SDK/tools/system caches and simulator runtimes remain outside the disposable
cache boundary. Raw provider logs and inventories do not belong in source commits.
