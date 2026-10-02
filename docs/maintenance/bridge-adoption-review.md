# Revised retained-bridge adoption assessment

Date: 2026-10-02. **Adoption update:** the maintainer approved all three reviewed patches and their documented residual risk. They were applied after real normal age admission on October 2; passing final resulting-tree checks are recorded in [adoption validation](bridge-adoption-validation.md). Bridge removal remains deferred. The assessment below preserves its original measurement and decision scope.

Assessment status: the revised experimental paired assessment passed and the exact adoption packet is complete. Normal adoption was age-blocked at measurement and still requires real-time admission, fresh source/advisory/preimage checks and a named maintainer decision. At assessment, production pins and policy were unchanged. The later approved application changes only the three recorded patches; the bridge default, OS/architecture declarations, release defaults and schedules remain unchanged. The earlier [slice-9 review](ninth-slice-review.md) and [slice-10 direct evidence](tenth-slice-validation.md) retain their original scope.

## Exact scope

Assess bridge Kotlin 2.4.20 / Metro 1.4.5 / SKIE 0.10.15, holding bridge Compose 1.9.0 and coroutines 1.11.0. Toolchain 0.12.2 continues supplying Kotlin 2.4.10 and its own Compose defaults. Explicit Metro runtime/compiler declarations move together across the five existing modules and the bridge catalog. This does not qualify a direct Toolchain path or adopt new language, DI, Flow or coroutine interop features.

The six-file [dependency proposal](proposals/bridge-2.4.20-dependencies.patch) and separate [bounded Renovate proposal](proposals/bridge-2.4.20-renovate.patch) were unapplied review artifacts at assessment and are now the exact applied adoption artifacts. Both apply and reverse to exact original bytes in a disposable copy. The Renovate change lifts only the existing ceilings to <=1.4.5 and <=2.4.20; it does not change schedules or authorize future updates.

A third [maintenance companion](proposals/bridge-2.4.20-maintenance.patch) rebases
the reviewed baseline/nomination to those adopted pins and updates two existing
contracts to use deliberate invalid preimages/fixture policy instead of assuming
the old compiler and ceiling. Without the rebase, the workflow would correctly
refuse the adopted catalog as baseline drift. Its 20 compatibility and 24
inventory contracts passed in a disposable source copy using the proposed
Renovate ceilings; the proposed rebased nomination matches all coupled pins and
produces no obsolete edits. All three patches apply and reverse to exact bytes.
The complete adopted normal-admission tree subsequently passed real age admission
and final validation after authorization; see the adoption validation record.
No clock or publication date was faked.

## Primary sources and release age

Current GitHub publication evidence records Kotlin 2.4.20 on September 7 at 10:31:56 UTC, Metro 1.4.5 on September 24 at 15:15:00 UTC and SKIE 0.10.15 on September 25 at 17:59:28 UTC. The tuple's seven-day threshold is October 2 at **17:59:28 UTC (19:59:28 Europe/Copenhagen)**. Normal admission was actually attempted and refused before that threshold. The explicit experimental assessment records real timestamps and preserves the `release_age` gap and `adoption_authorized: false`; it neither backdates a publication nor changes policy.

The [Kotlin release](https://github.com/JetBrains/kotlin/releases/tag/v2.4.20), [Metro release](https://github.com/ZacSweers/metro/releases/tag/1.4.5), [versioned Metro compatibility table](https://github.com/ZacSweers/metro/blob/1.4.5/docs/compatibility.md) and [SKIE release](https://github.com/touchlab/SKIE/releases/tag/0.10.15) support assessing the tuple. Metro lists Kotlin 2.4.10 and 2.4.20 as tested; [SKIE 0.10.15](https://skie.touchlab.co/changelog/0.10.15) adds 2.4.20 support. These are source leads; Mobi's resolved graphs and consumers must pass separately.

The refreshed complete stable interval contains four Kotlin releases after 2.3.20, eleven Metro releases after 1.1.1 and three SKIE releases after 0.10.12. The earlier interval mapping remains applicable; added releases have these concrete implications:

| Change | Mobi exposure and assessment |
| --- | --- |
| Kotlin 2.4.20 Native ObjC export, linker, runtime and Compose compiler fixes | Recompile shared libraries/DI factories, link the framework, run the original Swift state adapters/tests and shared UI consumers. No new Swift export pipeline is selected. |
| Kotlin 2.4.20 Gradle and SwiftPM metadata changes | Resolve all bridge/plugin configurations and materialize the existing metadata producer before fingerprinting. Preserve framework embedding and native targets. |
| Metro 1.4.5 FIR multibinding and IR member-injection fixes | Compile actual graph factories against both Toolchain 2.4.10 and bridge 2.4.20; retain existing behavior tests. Individual upstream bug fixes are not exhaustively reproduced. |
| Metro 1.4.5 experimental graph API/report task relocation | Mobi does not call those report APIs/tasks; its collector uses Gradle public resolution APIs. Inspect usage and keep that distinction explicit. |
| SKIE 0.10.15 compiler support and Flow annotation addition | Validate current sealed-state adapters through native tests. Flow/coroutine interop remains disabled, so the new annotation feature is not adopted. |

The fresh lag-one OS review still selects iOS 26.0 and Android API 36; current app/package/Xcode declarations match. Patch/preview releases do not advance the stable-major window. Fresh source receipts are separate from the unchanged checked-in historical catalog; no support change is proposed.

## Advisory review

The fetched [Kotlin advisory](https://github.com/advisories/GHSA-r937-wjx7-w2jp) lists Kotlin Gradle plugin versions below 2.4.20-Beta1 as affected. Stable 2.4.20 lies outside that reported range; this is not full candidate graph clearance. The [OpenTelemetry advisory](https://github.com/open-telemetry/opentelemetry-java/security/advisories/GHSA-rcgg-9c38-7xpx) remains a separate tooling concern, assessed against actual resolution below.

The [final query/match receipt](evidence/2026-10-02-bridge-adoption-maven-queries.json)
exactly matches the verified report: 485 baseline and 495 candidate queries, with
562 distinct Maven package/version pairs across both. All response counts,
pagination absence, finding records, timestamps and hashes were retained.
Two moderate IDs match the baseline; only the OpenTelemetry ID matches the
candidate. No high/critical finding was returned for this mapped scope. The
candidate selects Kotlin Gradle plugin 2.4.20 and no longer matches the Kotlin
advisory. This does not clear shaded code, Native distribution internals,
Swift/Ruby/npm packages or Toolchain's delegated Android plugin internals.

OpenTelemetry API 1.41.0 occurs only in `:shared-kit`'s project
`swiftExportClasspathResolvable` configuration in both bridge graphs; it is
absent from the captured Toolchain app/module graphs. The selected jobs do not
execute Swift export. That inspection narrows likely applicability but is not
exploit/reachability proof. No override, suppression or vulnerability exception
is included. Adoption requires a named decision on this remaining tooling risk.

## Measured validation and remaining limits

Run `57718fe461282da2a79b4fd9817e0221` passed from 15:12:28 through 15:40:32 UTC
on October 2. Both phases passed all nine required cells: effective settings,
Toolchain graphs, bridge resolution, KLIB compilation, framework linking and
the four existing Android/iOS test/debug-build jobs. Each phase ran the same
12 original Swift cases. Both captured 92 Toolchain graphs and 185 bridge
configurations; resolvable configurations increased from 72 to 74, and every
resolvable scope completed. The bridge comparison records five added, five
removed and 49 changed configurations. Changes are retained, rather than
inferred compatible from a compiler version table.

The [public execution/review receipt](evidence/2026-10-02-bridge-adoption.json)
binds the caller working snapshot on `9f730ef`, the separately initialized
source copy, its single configuration overlay and exact six-file patch digest.
The isolated source identity is
`56a8627b40458f0386425ecd156059270a49e26d502c467591293882a7fb4b04`;
the executor patch identity is
`ba32b924a69792eb199f5b4c9c7053732b4e98f2fbb5a2d470f4a7b6f82d5c48`.
The isolated Git HEAD is intentionally null; its caller HEAD and source binding
are recorded separately. This is a prepared-host working snapshot, not a clean
public clone or hosted result. Source preservation is verified for both phases.

Post-build metadata is bound to the final product hashes: simulator framework
minimums are 14.0 for the baseline and 15.0 for the candidate; both debug/test
app products in each phase declare iOS 26.0. The measured candidate framework
therefore does not raise the app floor. Lower framework minima do not extend
Mobi's supported app OS window. Device framework compilation/execution and
execution at the declared iOS 26.0 floor remain unproven.

Recovery reported `quiescent`; cleanup reported `cleaned` and removed both
executor-owned workspaces/caches. Immutable evidence and the small prepared
source snapshot remain local. Reporting after cleanup verified all receipt
chains; the OSV query union was checked against that final report. Raw logs,
resource/process identities, source contents and provider responses remain in
ignored `.maintenance/`; public receipts omit host paths and credentials.

All 204 repository contracts across ten suites passed, all five pinned static
analyzers passed (5.339 seconds warm), and strict OpenSpec validation passed
15 items. The companion's 44 contracts and exact three-patch reversal checks
passed separately. The pinned Renovate validator passed `--strict --no-global`;
its existing missing native RE2 addon retained a fallback warning, so this is
schema/policy validation, not native RE2 proof. Final local Markdown, public
receipt/reference/privacy, production-input and whitespace checks pass.

## Adoption and recovery boundary

The runner uses an isolated source copy with a single recorded `maintenance-compatibility.json` overlay. Its source hash differs intentionally from the caller; the caller's production nomination and pins were unchanged during rehearsal. Baseline and candidate use the same existing graph/native jobs, private caches, SDK copies and owned simulators. Any failed phase keeps its actual evidence; candidate success cannot be inferred from source tables.

After a complete paired assessment, recover/clean owned resources and verify receipt chains. Publish the exact patches, residual advisory decisions, evidence freshness and rollback. Before adoption, verify the real seven-day threshold, source/patch/policy preimages and fresh advisories. Request a named decision only on a concrete, qualified packet. Applying approved contents, final validation, commits/pushes and hosted integration remain separate stages.

Physical-device compilation/execution, minimum-floor runtime, Full test plan/macro validation, release archive/export/signing and cold hosted results are not claimed by these debug/PullRequest checks. Direct-path lifecycle/generic/onboarding/retirement gates remain independent. Elixir stays dormant and mobile commands require none of its tools.

## Concrete decision

Recommendation: adopt the exact revised retained-bridge tuple, bounded Renovate
ceilings and maintenance companion after real age admission and fresh review,
if the maintainer accepts the documented residual tooling finding and untested
device/release/hosted scope. This removes the baseline's mapped Kotlin advisory
match from the bridge and keeps all measured native consumers passing; it is
not a project-wide security clearance or a bridge-retirement proposal.

Approval must name all three patches and the residual risk. Apply only their
reviewed bytes after verifying current identities. Run the complete resulting
snapshot's contracts and native pre-commit gate, retaining any failure; do not
claim final adoption validation from this earlier snapshot. Commit/push and
hosted integration require their own authorization. If the final gate fails,
retain evidence and reverse only those reviewed changes after verifying their
current postimages. The bridge stays selected throughout.
