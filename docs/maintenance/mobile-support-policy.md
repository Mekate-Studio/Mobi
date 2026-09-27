# Mobile support and architecture assessment

Mobi defaults to one stable major OS release behind the latest reviewed stable
release, independently for iOS and Android. Versions are pinned in source; they
do not float with the installed SDK or the calendar. A release assessment reports
required changes, their impact and missing evidence. It never adopts an update.

## Current policy

The 2026-09-27 primary-source review selects iOS 26.0 and Android 16/API 36:

| Platform | Latest stable major reviewed | Previous stable major | Proposed minimum |
| --- | --- | --- | --- |
| iOS | 27, released 2026-09-14 | 26, released 2025-09-15 | 26.0 |
| Android | 17, released 2026-06-16 | 16, released 2025-06-10 | API 36 |

Apple's [iOS 27 release](https://developer.apple.com/news/releases/?id=09142026a)
and [App Store Connect release history](https://developer.apple.com/help/app-store-connect/release-notes/)
distinguish stable releases from RCs. Android's
[17 announcement](https://developer.android.com/blog/posts/android-17-is-here)
and [16 rollout announcement](https://developer.android.com/blog/posts/product-manager-guide-to-adapting-android-apps-across-devices)
provide dated stable-release evidence. The
[Android SDK declarations](https://developer.android.com/guide/topics/manifest/uses-sdk-element)
distinguish minimum, compile and target SDK roles. Android 16 maps to API 36;
OS marketing versions are not API levels.

[`maintenance-support-policy.json`](../../maintenance-support-policy.json)
configures `stable_major_lag` per platform. Mobi uses `1`; another project can
choose `0`, `2`, or another reviewed window after providing sufficient release
history. Selection follows stable release order, not arithmetic: iOS 18 → 26 →
27 is valid. Patch, minor, quarterly, beta, RC and preview releases do not advance
the major window. Changing this configuration is itself a support decision.

[`maintenance-platform-releases.json`](../../maintenance-platform-releases.json)
is a reviewed catalog, not an automatic global release feed. Each stable family
records its publication date, minimum/API mapping, primary URL, retrieval time
and response SHA-256. The current catalog contains only the two required stable
families per platform; a longer window requires more verified history. Evidence
must be at most 24 hours old for a new assessment. The offline static gate does
not fetch sources or fail merely because this catalog has aged.

A maintainer must inspect current primary release histories for newer stable
families before refreshing the catalog. Fetch and hash actual response bytes,
check the date/channel/mapping against their content, and record the real retrieval
time. A new timestamp on an old response is not evidence of a fresh review.
Retain downloaded responses in an ignored local evidence directory and publish
only reviewed, public-safe metadata and excerpts. An unavailable or ambiguous
source produces an incomplete assessment, never a claim that no new OS exists.

## Manual update workflow

```bash
./scripts/dev/dependency_updates.sh assess-support > /tmp/mobi-support.json
just deps > /tmp/mobi-inventory.json
```

`assess-support` needs the repository Ruby runtime but no provider token, Renovate
execution, native compiler, private service or Codex. Exit 0 means declarations
match the reviewed policy. Exit 2 means `requires_decision` or `incomplete`; inspect
the JSON state, drift, reasons and blockers. Malformed/unsupported declarations
fail nonzero. `just deps` includes the same support assessment and explicitly
marks broader architecture assessment as requiring manual review. Neither command
writes app declarations or reports adoption authorization.

The mobile adapter inventories Android `minSdk`, `compileSdk`, `targetSdk`, the
Swift package floor, and all six Xcode project/app/test Debug/Release configurations.
An implicit Xcode floor is visible as `implicit`, even when the package declares a
minimum. These are app support floors; lower library/dependency compile minima do
not extend the supported OS range of the Mobi app. An Android minimum above compile/target SDK blocks the candidate; updating
compile/target SDK needs its own compatibility and behavior assessment.

For each dependency or Toolchain candidate, complete this review:

| Review item | Required evidence/decision |
| --- | --- |
| Upstream support | Official versioned release notes, migration guides, artifact variants and relevant source; record URL/date/digest and affected local declarations/usages |
| Supported architectures | Host, simulator and device support separately; list retained and lost targets/contributors; try a supported-target candidate when upstream removes an old target |
| OS window | Fresh stable-major history; proposed app/test/package floors; list excluded versions and any SDK/API prerequisites |
| API and behavior | Compiler/plugins, generated interfaces, Swift state adapters, actual tests and release packaging; add focused probes for changed behaviors |
| Alternatives | Supported migration, scoped adapter/facade, deliberate deferral, or documented temporary pin; explain cost and rollback |
| Decision | Exact source/patch/evidence identities, checks passed, gaps, implications, maintainer approval or defer reason |

The workflow automates inventory, bounded policy checks, known target edits,
source binding, baseline/candidate execution and cleanup. It does **not** infer
that arbitrary architecture changes are safe. Unknown declaration shapes or
unsupported Toolchain output require adapter work and tests. Compatibility-impacting
architecture removals, API/behavior changes, OS floors, Toolchain defaults and
bridge retirement require an informed maintainer decision. A passing build is
one piece of evidence, never permission to silently change those boundaries.
Routine updates still follow the existing manual adoption policy.

The validated Toolchain 0.12.2/Apple Silicon migration is a concrete example:
Mobi can follow current Compose artifacts while explicitly dropping Intel iOS
simulators. The retained Gradle bridge and the direct Toolchain retirement path
remain separate tracks. See the [target assessment](apple-silicon-assessment.md).

## Rehearse an OS candidate

Prepare the reviewed Toolchain wrapper cache, then run a separate OS-only plan:

```bash
./scripts/dev/dependency_updates.sh prepare-kotlin
./scripts/dev/dependency_updates.sh rehearse-support inputs --store support-review
./scripts/dev/dependency_updates.sh rehearse-support mobile --store support-review
```

The `inputs` profile is optional preliminary resolution evidence. Only the
`mobile` profile runs Android/shared host tests, Android debug packaging, native
Swift tests and iOS debug packaging through existing repository jobs. The candidate
changes only the Android app minimum, Swift package minimum and six explicit
Xcode deployment settings. Both phases use the adopted Toolchain version and
retain bridge/plugins/native targets/adapters. Baseline runs first, using the
newest installed iOS simulator; candidate requires a runtime in the proposed
minimum major and an iPhone device type declared compatible with that runtime. The result records the exact runtime difference. This is a support
acceptance comparison, not a controlled performance or Toolchain-version benchmark.

Missing minimum-major simulator support fails as missing evidence; the candidate
never silently substitutes a newer runtime. Effective Android SDK settings and
built iOS app `MinimumOSVersion` are checked against declarations and recorded.
Declaration coverage is deliberately specific to Mobi's six Xcode configurations;
other project structures need their own adapter coverage and contracts.

Keep source and tool inputs unchanged during execution. Each phase owns a private
source/build copy, SDK copy, caches and simulator; baseline outputs do not feed
the candidate. The existing executor preserves explicit failures, source drift,
timeouts, resource ownership and evidence hashes. The result always records
`adoption_authorized: false`. Apply only the reviewed bytes after maintainer
approval and validation; commit/push are separate actions.

A fresh named store is optional. `--store NAME` accepts a short lowercase name and
uses `.maintenance/runs-NAME`. It cannot transfer a historical store to a new host,
rewrite an ownership marker, or authorize deletion of another run's resources.
Use the same name for inspection and cleanup:

```bash
./scripts/dev/dependency_updates.sh recover RUN_ID --store support-review
./scripts/dev/dependency_updates.sh cleanup RUN_ID --store support-review
./scripts/dev/dependency_updates.sh cleanup RUN_ID --apply --discard --store support-review
```

Inspect the dry run before discard. Results, journals and control evidence remain
when owned disposable workspaces are removed. Historical ownership failures remain
blockers for those historical resources; a successful new run does not resolve them.

## Reuse and evidence limits

`SupportPolicy` is a Ruby standard-library evaluator independent of mobile paths.
`MobileSupport` owns Mobi's Android/Swift/Xcode parsing and exact candidate recipe.
Kotlin rehearsal supplies native tools and resource handling. Elixir remains an
independent dormant profile and needs none of this mobile toolchain.

Local simulator tests demonstrate the exact installed OS patch and test plan.
They do not establish every supported OS patch, Android device execution, physical
iOS devices, clean hosted onboarding, signed releases or direct Toolchain parity.
Keep these gaps visible in each review. No schedule or automatic updater is added.
