# Toolchain adoption with inherited risk: local integration

Date: 2026-10-04. Maintainer direction: **proceed toward Toolchain adoption, then prioritize independent iOS bridge retirement**. The instruction acknowledges persistent vulnerabilities; it does not establish that fixes are impossible. Fixed library versions exist, while the inspected Toolchain releases do not select a complete supported remediation cohort.

Following explicit maintainer approval, Toolchain **0.13.0** and Android compile SDK **37** are applied locally. The adopted retained-bridge path passed Android/iOS tests and debug builds. The independent bridge-unavailable round trip also passed, including incremental propagation and exact bridge restoration. The scoped manual risk review returns `accepted_risk_for_scoped_manual_use`; this remains uncommitted local integration, without hosted or signed-delivery proof.

The approved residual-risk window ends **2026-11-03T05:48:38Z**. The one-release early-age exception preserves the real seven-day threshold of **2026-10-08T06:36:56Z**. Exact scope, source bindings, controls and approval are in [maintenance-toolchain-risk-acceptance.json](../../maintenance-toolchain-risk-acceptance.json). All seventeen findings remain visible; no remediation is claimed. The generic security policy is unchanged. This follow-up supersedes the preferred direction in the earlier [security packet](toolchain-security-decision.md), whose evidence and limits remain intact.

## Historical preparation

The original [twelve-file draft](evidence/2026-10-04-toolchain-adoption-draft.patch) and [byte/mode manifest](evidence/2026-10-04-toolchain-adoption-draft.json) prepared:

- Exact vendor Toolchain 0.13.0 Unix/Windows wrappers, including the checksum-pinned distribution.
- Android compile SDK 37, preserving min/target 36, iOS 26.0, ARM-only support and `studio.mekate.mobi`.
- Matching wrapper baseline, compatibility baseline and 0.13.0 plugin mapping; retain historical versions and 0.12.2 mapping for independent old producers. Clear already-adopted Toolchain candidates rather than nominating the production version as its own upgrade.
- Compatibility adapter admission for reviewed 0.13.0 plus a baseline-independent drift-refusal test and an explicitly historical SDK 36 fixture.
- Public SDK/build-tools/license setup and README compiler/Compose declarations.

The draft preserved Gradle as the iOS default, native targets/tests, Swift sealed-state adapters, compiler plugin declarations, release jobs, quality hooks, Renovate and schedules. Its Windows wrapper had vendor CRLF bytes. The [applied patch](evidence/2026-10-04-toolchain-adoption-applied.patch) normalizes that caller wrapper to LF consistently with existing rehearsal contracts; the cached vendor wrapper pin remains exact.

Application and reverse application in a disposable checkout restored exact preimage bytes and modes for all twelve files. The assembled candidate's wrapper/compatibility/bridge declarations agree. Its 25 compatibility contracts pass after preserving the two originally failing checks: the historical SDK fixture assumed production compile SDK 36, and a drift test only replaced literal wrapper version 0.12.2. Those failures remain in the review record; neither was an application build failure. Across the preserved run and corrected continuations, all 260 contracts in 16 suites pass. The candidate also passes the five pinned static analyzers, using the existing verified installation after checking that analyzer configuration bytes/availability agree. An initial static helper assumed an optional absent .shellcheckrc existed; that setup failure is retained separately. All 23 strict OpenSpec items pass. Historical support and plugin-mapping fixtures were also corrected without weakening their refusal assertions. The risk overlay and remaining operational/advisory gates are still pending; these passing checks do not make the draft a complete adoption package. New cold-host SDK installation, license onboarding and hosted checks are not credited by these content checks.

## Residual-risk decision history

The historical [risk proposal](evidence/2026-10-04-toolchain-risk-proposal.json) lists all ten High/Critical IDs with exact component/artifact identities. Activation replays the verified selected/bundled/plugin producers with fresh, complete 549-query provider evidence. These retained producers are explicitly identified; they are not a new integrated dependency collection. Seven Moderate findings remain visible; unknown severity still requires triage. Accepted risk is recorded separately from remediation.

The maintainer approved the following bounded terms for local use:

| Term | Approved scope |
| --- | --- |
| Purpose | Carry inherited build-input risk while adopting the reviewed Toolchain and assessing bridge retirement |
| Scope | Exact ten advisory/component/artifact tuples and exact 0.13.0 distribution/patch; no future-version or family-wide exemption |
| Allowed operations | Public-source development builds, repository tests and owned isolated compatibility assessment |
| Excluded operations | Credentialed release delivery, direct-default switching and physical bridge deletion |
| Duration | At most 30 days from actual approval; exact start/expiry recorded at activation |
| Revalidation | Within 24 hours at adoption decision; new advisory, changed artifact/patch/source, unknown severity, expiry or revocation refuses acceptance |
| Controls | Owned disposable rehearsals, guarded cleanup, explicit input/trust-boundary review and no implicit credentialed operations; consumer reachability remains unmeasured |
| Policy behavior | Preserve High/Critical classifications and current discovery findings; a separate manual acceptance overlay reports accepted risk without calling it a fix |

These controls narrow the execution scope and preserve auditability. They do not prove malicious input cannot reach vulnerable functions. This is a residual-risk choice, not mitigation verification. `maintenance-policy.json` and its evaluator remain unchanged; the separate overlay and twelve refusal contracts implement the approved manual scope.

## Independent age decision

0.13.0's normal seven-day threshold is **2026-10-08T06:36:56Z / 08:36:56 Copenhagen**. The maintainer explicitly approved its early-age exception conditional on compatibility. The manual report preserves `age_blocked_with_explicit_exception` until that threshold. Provider freshness and operational limits still apply; no global maturity policy or schedule changed.

## Adoption and retirement acceptance

Complete the [adoption requirements](toolchain-security-decision.md#exact-adoption-packet-still-required), including fresh complete advisories, SDK/license onboarding, cold hosted evidence, remaining attribution and explicit dispositions for exact iOS-floor/runtime/physical-device/signed-delivery coverage. Earlier local 38 Android/12 original Xcode test pairs and packaging receipts remain source-bound historical evidence. No repeated unchanged functional pair is required merely to restate those results; changed integration content and unresolved compatibility gates do require appropriate checks.

The [OpenSpec proposal](../../openspec/changes/toolchain-adoption-risk-review/proposal.md), [design](../../openspec/changes/toolchain-adoption-risk-review/design.md), [spec](../../openspec/changes/toolchain-adoption-risk-review/specs/bounded-toolchain-risk-acceptance/spec.md) and [tasks](../../openspec/changes/toolchain-adoption-risk-review/tasks.md) retain the distinction between completed local integration and outstanding hosted, release and retirement work.

After explicitly approved adoption is applied and validated, prioritize fresh direct-roundtrip and build-input collection against the adopted tuple with the hand-maintained iOS bridge unavailable. Preserve Xcode app/test targets, adapters, plugin/API behavior, resources, relevant runtime/device coverage, public onboarding, hosted CI and release packaging. Initial SwiftPM support is unexecuted here. Android Toolchain builds may still use delegated Gradle/AGP, so bridge retirement must not be presented as remediation of these build-tool findings without new selected-input evidence.

A reversible direct-default switch precedes a separately reviewed physical deletion. Commit, push, signed delivery and publishing remain separate authorizations. The maintenance core and dormant Elixir/Phoenix adapters stay independent, with no private infrastructure, mandatory AI service or Go application prerequisite.

## Approved local integration follow-up

The maintainer explicitly permitted the residual-risk and early-age exceptions,
conditional on compatibility, on 2026-10-04. The twelve-file draft has been
applied locally, preserving unrelated work and the index. The Windows wrapper
uses the existing repository LF normalization; its raw vendor pin is retained.
Current architecture/iOS documentation has matching Toolchain declarations.

`maintenance-toolchain-risk-acceptance.json` records the exact approval scope,
source bindings and expiry. The default security policy still blocks High and
Critical findings. A separate repo-owned `review-toolchain-risk` command replays
retained artifact/plugin producers and fresh complete providers, checks the
exact decision/source/artifact scope, and refuses until integrated compatibility
passes. Twelve new contracts cover approval, expiry, drift, new findings,
provider completeness, compatibility, attribution, scope and exact age waiver.
The fresh 549-query review retains all seventeen IDs; no remediation is claimed.

The integrated native round trip passed in run
`96942bc52fc76b115913cf5011cc6bf4` (`adoption-direct`). Baseline and direct candidate
each passed 38 Android tests and debug builds; all twelve original Swift cases
survived, with thirteen cases including the probe on direct/incremental stages.
Warm-cache propagation changed three framework copies. Exact bridge source/modes
were restored, then the original twelve Swift tests and iOS build passed again.
Recovery reached quiescence, owned copies were discarded, and evidence replay
passed after cleanup. The root gate passed 272 contracts in seventeen suites,
five static analyzers and 23 strict OpenSpec items.

Revalidate the manual scope with `./scripts/dev/dependency_updates.sh review-toolchain-risk`.
The report remains bounded to measured inputs and never grants automatic adoption.
Cold hosted, empty-host/license, physical-device, exact-floor and signed-delivery
gates remain unmeasured and are not cleared by this local exception. Current
production iOS consumption remains the Gradle bridge; the direct candidate is
an isolated architecture experiment. The [retirement path](bridge-retirement-path.md)
records the remaining independent capability gates.
