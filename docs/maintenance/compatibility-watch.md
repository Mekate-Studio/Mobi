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

The shared release reader queries the first 30 GitHub release records for
Toolchain, Kotlin, Metro, TCA, Clocks and Concurrency Extras; the historical bridge
path also queries SKIE. It includes newer
stable and prerelease versions, including Alpha, Beta, RC, EAP and dev tags.
Drafts are excluded. Either GitHub's prerelease flag or a version suffix marks
the release as an **experimental prerelease** review lead, including RC tags
incorrectly marked stable upstream. Unknown tag formats, absent timestamps,
future dates, rate limits, malformed responses
and network failures yield explicit incomplete provider evidence. Each available
response has its URL, UTC retrieval time, content digest and HTTPS client digest.
The system HTTPS client verifies certificates; credentials used for hosted history and releases
are supplied through standard input, never command arguments. The pinned Ruby
runtime does not have an OpenSSL extension.

The three native comparison versions come from the app's tracked
`ios-app/module.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`,
not duplicated configuration pins or a fresh package resolution. Missing,
ambiguous, malformed, branch-only or repository-mismatched pins leave the
affected provider incomplete; a revision must have the expected commit-ID format.
The reader does not verify remote tag-to-commit correspondence, guess a version
or query an unusable pin's provider. These baselines do not establish compiler-specific build
graphs. Other native packages and Swift/SwiftUI/Xcode discovery remain manual.

`discovery.json` and the existing snapshot/summary expose the native providers,
reviewed versions and `review_requests`. Eligible TCA leads request **IOS-13**
timer/executor and **MOB-08** lifetime-owner reviews. Eligible Clocks and
Concurrency Extras leads request **IOS-13**, including its timer checks.
Age-blocked releases remain visible without issuing those requests; provider
failure cannot produce a request. The broad `native_dependencies` coverage gap
remains because these three feeds do not cover all native dependencies.

Newer versions are compared against the reviewed tuple, with numeric preview
ordering (Beta2 precedes Beta10) and case-insensitive labels. The configurable
seven-day age policy applies to both channels. New prereleases are visible
immediately with `age_blocked`; when eligible, they request rechecks of affected
workarounds. Major changes remain visible. A changed version, channel or age state
can notify; the same semantic observation stays quiet.

Discovery does not change the reviewed candidate. A separately reviewed tuple may
explicitly select a prerelease with `review_channel: experimental` on that release;
the compatibility adapter then reports experimental selection. A CLI age waiver
alone cannot select a prerelease. The seven-day age policy and captured source
evidence remain enforced. A maintainer may explicitly waive age for qualification
of one selected experimental release: `age_waiver` binds the approved decision
record, version and publication timestamp. A future publication, mismatched
waiver or another unwaived young companion still refuses. Reports retain the real
`age_blocked`/`eligible_at` and `adoption_authorized: false`; the waiver neither
accepts advisory risk nor grants adoption. The ordinary release/adoption policy
remains stable-only. The current
[RC qualification](evidence/2026-11-11-kotlin-250-rc-qualification.md) uses this
release-bound exception; a later tuple requires its own decision if still young.
Prerelease review requires official source review and actual-code qualification.
The watch's native probe still exercises the reviewed tuple; it does not build
discovered versions or run their retirement checks automatically.

An eligible release is only a review lead. The
[GitHub releases API](https://docs.github.com/en/rest/releases/releases#list-releases)
does not include tags without a release; Maven-only/nightly builds, sample changes,
documentation and YouTrack changes are not polled. This bounded page is **not a complete
release interval, dependency graph, vulnerability audit or semantic migration
assessment**. The watch does not refresh OS release policy or direct-integration
documentation; those require the separate support and compatibility assessments.

The current direct source uses `direct-mobile`, executing both phases on the
adopted direct content with all four repository native jobs. Its scope identity
is `kotlin-direct-mobile-v1`; historical `kotlin-bridge-compile-v1` observations
cannot serve as its baseline. Discovery omits retired SKIE. Historical retained
source can still execute its explicitly scoped bridge profile after complete
content recovery. Release discovery remains bounded and does not authorize
updates or claim a full advisory review.

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

Toolchain/FUS owner reviews must recheck the launcher dependency edge and
serializer selection described in the
[Jackson exposure review](evidence/2026-11-21-toolchain-014-jackson.md). Bind any
removal or patched cohort to the actual published distribution and fresh advisory
records; static non-use in one consumer is not policy clearance. Assess a CLI
JRE security release separately from `JAVA_HOME` and provisioned compiler JDKs,
including retained caches. Release discovery neither transfers an older waiver
nor authorizes cache deletion, dependency overrides or adoption.
The [0.14.1 runtime-chain assessment](evidence/2026-11-21-toolchain-0141-jre.md)
separates managed CLI JRE, explicit CLI override and compiler/project JDK.
Record actual selected versions and vendor CPU conditions in fresh and retained
owned-workspace checks; a new launcher pin alone does not verify every runtime.
Include `setup-java`'s preinstalled tool-cache selection: repository cache-free
mode excludes host tools. The [actual 0.14.1 qualification](evidence/2026-11-21-toolchain-0141-qualification.md)
observes a patched managed CLI alongside an older hosted `JAVA_HOME`.
The [native CI JDK review](evidence/2026-11-21-native-ci-jdk.md) qualifies one
exact vendor selector for Mobile CI. On Temurin, setup-action or runner-image
updates, review the package identity, release age and `version_data.semver`
mapping before changing `NATIVE_CI_JAVA_VERSION`; repeat actual cache-selection
controls and native jobs. JDK patch discovery/adoption is manual. Nightly and
release workflow selectors remain a separate candidate/delivery review.
The [0.14.1 module-input review](evidence/2026-11-21-toolchain-0141-inputs.md)
also binds the output-reader cost and module-advisory limits. On Toolchain
updates, check documented settings/graph commands and actual help for a supported
structured-output replacement; qualify complete module/target/test coverage and
failure controls before retiring pretty-output parsing. Keep historical version
cases only while retained replay/recovery needs them, using full-revision replay
when simplifying old support.
The [0.14.1 published-owner review](evidence/2026-11-21-toolchain-0141-dependencies.md)
distinguishes fresh archive identities/provider records from retained graph
captures. On updates, compare each owner's actual files, recheck changed consumer
bytecode and refresh omitted delegated-only queries before an adoption decision;
fewer queried packages or a JRE fix does not clear unchanged Maven findings.
The [fresh delegated capture](evidence/2026-11-21-toolchain-0141-delegated.md)
binds 0.14.1's observed settings classpath and named queries. Gradle 9.8 still
reports an incomplete transform observer. Recheck supported instrumentation and
event-coverage controls on owner updates before replacing that mechanism; a
passing build or disabled AGP option does not fill missing observation coverage.
The [retained JDK control](evidence/2026-11-21-toolchain-0141-jdk-cache.md)
records a version-bound project-cache refresh and supported project clean.
On owner updates, verify actual CLI/tool JDK versions and record code-version,
hit/recalculation behavior and cleanup scope. Revisit this manual review when a
supported freshness policy changes; explicit runtime overrides remain separate.

## Interop workaround retirement

The same watch writes `workarounds.json` and a retirement table in the step
summary. The [inventory and workflow](interop-workarounds.md) separate real app
improvements, temporary bridge mechanisms and experimental policy. Eligible
release leads request rechecks of matching IDs; absent candidate source and
unrun checks never imply retirement. Swift/Xcode, coroutines and other provider
coverage gaps remain explicit. Use `assess-interop-workarounds` for a report-only
local inventory. This adds no schedule or automatic update/removal authority.

Swift-export updates and workaround removal also require the
[source review](interop-workarounds.md#required-upstream-source-review) of official
docs, the official sample and relevant YouTrack issues. These are manual review
inputs; the current watch does not poll their changes or validate their claims.

Android presenter-test dependency and Toolchain update reviews must also assess
[AND-01](mobile-feature-follow-ups.md#and-01-presenter-host-test-harness-simplification):
record retained/removal-ready/incomplete status and actual host-test evidence in
the update PR. This manual check is outside the iOS interop retirement report;
the watch does not poll Circuit/Robolectric or automatically qualify this harness.

The same manual update review must assess
[AND-03](mobile-feature-follow-ups.md#and-03-shared-compose-ui-test-gap--candidate-deferred):
the Shared Home rendering gap remains open and draft #99's private-metadata/AGP
integration was deferred for complexity. Evaluate lower-cost supported Toolchain,
Compose common/Android, host and device runner candidates using the
[review playbook](dependency-review-playbook.md). Record versions, primary sources,
maintenance cost, measured performance/reliability and qualification gaps in the
update PR. This adds no runner, provider, scheduled search or automated benchmark;
release discovery and an executed replacement assessment remain separate evidence.

Toolchain and bundled HTTP-client update reviews must also assess
[AND-02](mobile-feature-follow-ups.md#and-02-toolchain-distribution-download-header-limit):
record installed-JDK native results separately from automatic cold provisioning.
A matching `JAVA_HOME` does not qualify the failing JDK download route; the
producer endpoint override also requires a cold check of the unmodified Maven
Central route before removal. This is another
manual adoption-review step, outside the automated iOS retirement report.

Toolchain, its IDE plugin, Xcode and Swift-export update reviews must also assess
[IOS-10 project integration](interop-workarounds.md): use disposable command-line
management controls, then actual IDE reopen/resync and branch switching with a
project left open. Preserve the producer, app/test module linkage and shared test
plans, qualify Debug/Release native results and one Kotlin runtime, and record
retained/removal-ready/incomplete with source/tool identities. The preflight can
be simplified with the custom producer only after supported integration replaces
both contracts; retain ordinary app/test/scheme assertions. The watch does not reproduce interactive IDE writes or remove
this protection automatically.

TCA, SwiftUI, Swift and Xcode update reviews must also assess
[MOB-08](mobile-feature-follow-ups.md#mob-08-home-scene-task-ownership-simplification):
try supported scene/effect APIs against the actual Home and Nearby timing and
late-result checks before removing either StoreTask owner. Nearby also requires
location-to-refresh ownership, all request triggers, gated stopped callbacks,
SwiftUI background/removal/re-entry and failure-aging checks. Review Apple
CoreLocation async API/diagnostic evolution on native SDK updates; the supported
one-result reader is separate from the TCA timing adapter. Record retained,
removal-ready or incomplete with executed evidence in the update PR. Eligible
TCA leads now request this review in the release table; the native-lifetime
simplification check remains outside automated Swift-export retirement results.
Discovery does not execute the check or qualify either owner's removal.

On Kotlin Toolchain updates, review the Android AAB helper against the official
Android-app packaging documentation. Exercise the existing release-candidate
lane with synthetic signing, verify its published bundle matches the final
`kotlin package` artifact, and check warm manifest/resource edits and reverts.
The documented artifact path is temporary: replace the helper's explicit locator
when a supported artifact-reporting interface is available, after validating the
same output/signing contracts. Do not restore Gradle cache-layout discovery.
This manual check is separate from the automated Swift-export retirement report.
The [0.14.1 unsigned Release record](evidence/2026-11-21-toolchain-0141-release.md)
binds actual optimized products and unsigned helper publication; it does not
replace warm/synthetic-signing or runtime delivery checks. On compiler/exporter
updates, re-evaluate supported optimized-image mode observability while preserving
optimization and one runtime; an absent constant is not an observed mode value.
The [0.14.1 Debug warm-build check](evidence/2026-11-21-toolchain-0141-invalidation.md)
confirms actual manifest/string packaging and reverts without cleaning, while
retaining stale baseline expectations. Repeat these packaged checks on updates;
this result does not cover assets/JNI, Release inputs or the synthetic-signing
and warm AAB lane. It introduces no app workaround to retire.
The [0.14.1 synthetic-signing AAB check](evidence/2026-11-22-toolchain-0141-aab.md)
separately passes the existing Release-candidate lane and six warm bundle stages
on both versions, including generated-certificate identity and helper publication.
Keep the explicit final-artifact locator under review against official packaging
APIs; this result does not qualify production credentials or broader input edits.
The one-off HTTP-429 JAR seed is qualification setup only: cold-delivery reviews
must repeat dependency retrieval without it before claiming cache-free delivery.

## Primary references

- [GitHub releases API](https://docs.github.com/en/rest/releases/releases?apiVersion=2022-11-28): release metadata and pagination boundaries.
- [Workflow runs API](https://docs.github.com/en/rest/actions/workflow-runs?apiVersion=2022-11-28): read-only same-workflow history.
- [Hosted runner specifications](https://docs.github.com/en/actions/reference/runners/github-hosted-runners): `macos-26` architecture.
- [Artifact download](https://github.com/actions/download-artifact) and [artifact upload](https://github.com/actions/upload-artifact): cross-run access, retention and explicit hidden-path inclusion.
- [Workflow commands](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands): annotations and step summaries.

These sources were checked on 2026-09-29. Repository contracts and measured runs,
rather than the existence of an upstream feature announcement, establish coverage.
