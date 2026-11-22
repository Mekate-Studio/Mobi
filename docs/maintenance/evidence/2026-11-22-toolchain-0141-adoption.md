# Toolchain 0.14.1 adoption proposal — 2026-11-22

**Draft for review, not an approved adoption.** This branch selects 0.14.1;
main remains on 0.13.0 until an explicitly approved merge. The version-specific
qualification exception did not approve adoption, dependency risk or publication.
Keep this PR draft until the decisions and validation below are resolved.

Base: `dfbe7807d68475914074424186248fce4a5d2d74`, merged reviewer PR #135.
The original draft was based on merged PR #133; prior evidence keeps its own heads.

## Actual change and cost

- Replace both launchers with the checksum-verified upstream 0.14.1 wrappers,
  retaining the repository's LF normalization. The distribution pin becomes
  `39fb5f7e0bd5148a02f5519e88d78752fb04e719ddb086258ff57e94d83c0fcb`.
- Make 0.14.1 the maintenance baseline and empty the completed candidate list.
  Keep all historical version pins and immutable evidence for recovery.
- Align the live compatibility record and its exact reviewed-version check.
  One refusal contract confirms that editing both caller/version declarations
  cannot authorize an unreviewed neighboring version.
- Update current onboarding/reference text and this decision record.

The existing producer already accepts exact 0.14.1 task records and still refuses
mixed compiler/task inputs. No producer, facade, native state, feature behavior,
Xcode project, CI workflow, dependency override or build adapter is added or changed.
Kotlin/exporter 2.5.0-RC, Metro 1.5.0 and platform floors remain fixed.
The seven-day rule, 24-hour evidence windows, blocking severities and
`automatic_adoption: false` remain unchanged.

The measured benefits are the managed CLI JRE security update and correct checked
Android Debug manifest/resource edit-and-revert packaging. An explicit older
JVM override still takes precedence; the wrapper does not patch every installed
or independently selected JVM. See the
[runtime qualification](2026-11-21-toolchain-0141-qualification.md),
[retained-JDK migration](2026-11-21-toolchain-0141-jdk-cache.md) and
[warm APK observations](2026-11-21-toolchain-0141-invalidation.md).

## Decisions required before adoption

| Gate | Current evidence / requested review |
| --- | --- |
| Release age | Published November 19 at 17:46:59 UTC; normally eligible November 26 at 17:46:59 UTC. Wait for eligibility or obtain an explicit 0.14.1 adoption-specific exception. The earlier exception covers qualification only. |
| Dependency risk | The [pending disposition](2026-11-22-toolchain-0141-risk-proposal.md) lists the 18 affected coordinate/file identities and requests a bounded decision for 33 High/three Critical candidate IDs, with attribution/observer gaps retained. Artifact presence and passing builds do not establish exploitation or remediation. |
| Evidence freshness | Revalidate release/advisory evidence within the unchanged 24-hour windows at the actual adoption decision. Older captures must not be relabeled as fresh or automatically accepted. |
| Android unseeded retrieval | The earlier local baseline attempt hit canonical Maven Central 429; its candidate never ran. Honor that endpoint's retry window until November 23 at 06:43:38 UTC. Original-head hosted cache-free CI separately passed all 94 Android/shared cases and Debug build without a JAR seed; the current local gate uses the supported, explicitly selected Google mirror. Each result keeps its actual endpoint/cache/source scope. |
| Exact PR validation | Revalidate the full updated adoption diff through the normal local hook using qualified JDK 25 and the supported mirror; retain source/index and cleanup checks. Refresh hosted checks on the new head. Actual results belong in the PR and final packet; green CI does not approve age/risk exceptions or adoption. |

The existing `maintenance-toolchain-risk-acceptance.json` is deliberately unchanged.
It binds 0.13.0 and its distribution, and expired November 3 at 05:48:38 UTC.
It is not reusable approval for 0.14.1. No new approval, expiry, risk overlay or
broader operation scope is invented here. Decide the bounded scope and evidence
before recording any new acceptance.

Merged [PR #135](https://github.com/Mekate-Studio/Mobi/pull/135) supplies the
explicit 0.14.1 packet reviewer and refusal contracts while preserving the old
0.13.0 route. The rebased adoption draft uses `review-toolchain-risk --packet`
without a decision. It must remain blocked until the maintainer approves the
exact proposed scope, finding/file bindings, coverage gaps and qualification
receipts. Final source/packet bindings are recorded outside the source they
bind, in the PR and ignored proposal. No acceptance is copied from 0.13.0.

The [published-owner review](2026-11-21-toolchain-0141-dependencies.md) retains
launcher/integration findings; the [fresh delegated observation](2026-11-21-toolchain-0141-delegated.md)
retains nine named matches including two Critical findings. Owner counts overlap
and are not a repository-wide finding total. The module, published-owner and
delegated advisory captures are from November 21 at 17:52, 19:08 and 19:56 UTC
respectively. Their age limits continue to apply while this draft is open.

## Qualification reused, with its limits

The [input review](2026-11-21-toolchain-0141-inputs.md) binds all nine modules and
104 roots; the [native qualification](2026-11-21-toolchain-0141-qualification.md)
records local and cache-free hosted native checks. The
[unsigned Release](2026-11-21-toolchain-0141-release.md),
[synthetic-signing AAB](2026-11-22-toolchain-0141-aab.md) and
[local iOS delivery](2026-11-22-toolchain-0141-delivery.md) records keep their exact
products, sources, seed/cold-cache conditions and unmeasured behavior explicit.
These are prior qualification results, not a fresh pass of this PR's staged gate.

Fully cold hosts, minimum-OS/physical-device and credentialed delivery remain
separate. The tested Debug app's relocated launch does not qualify raw generated
module relocation or Release runtime. Strict support is still blocked in both
support modules; IOS-10 and the other active interop mechanisms remain. The
[warning backlog](../compiler-warning-follow-ups.md) and artifact-locator
simplification checks stay open. This update retires no workaround.

## Draft validation and review workflow

Rebase the adoption diff onto the reviewed verifier and qualify that resulting
source, including all 22 contract suites and pinned static checks. Consolidate
the updated adoption changes for the normal commit hook so its selection covers
the entire version change rather than only the final documentation edits.
Native checks use qualified JDK 25, installed Android SDK and the supported
`KOTLIN_DEFAULT_MAVEN_CENTRAL_URL` override for Google's public Maven Central
mirror. This route avoids the active canonical-endpoint backoff; it does not
clear that endpoint or silently replace the repository's maintained default.
No hook or required hosted check is disabled.

The original draft's one-time local hook override remains historical preparation,
not a pass or an exception for the updated draft. Original-head normal CI
[45005093073](https://github.com/Mekate-Studio/Mobi/actions/runs/45005093073) and
cache-free CI [45018973576](https://github.com/Mekate-Studio/Mobi/actions/runs/45018973576)
passed all seven checks on `6a6ef4ef35fe72af28d7e2cf900c7e50fedc2bee`.
Their 30 absent-root checks and skipped repository-cache restores establish
that named cache boundary, not a fully empty host. Updated-head local/hosted
results, release/advisory freshness and the exact proposal bindings must be
presented together before the maintainer decision.

After the open decisions and exact validation are resolved, update this record
with the explicit approval scope and fresh evidence before marking the PR ready.
Recovery restores the complete prior published revision; do not mix old wrappers
with newly selected metadata or extend historical risk receipts. Retain the
producer's reviewed recovery versions until their resource/recovery obligations
are closed; narrowing that existing allowlist is a separate simplification review.
