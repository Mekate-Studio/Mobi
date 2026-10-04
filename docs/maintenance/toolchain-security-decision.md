# Toolchain adoption security decision packet

Reviewed: 2026-10-04. Recommendation: **defer Toolchain 0.13.0 adoption under the current policy and pursue an owner-supported remediation cohort**. Keeping 0.12.2 preserves the validated baseline but does not remediate defects shared by both stacks. This packet requests no adoption, exception, release operation or bridge transition.

Production remains Toolchain 0.12.2, compile/minimum/target Android SDK 36, minimum iOS 26.0 and ARM-only iOS with the retained bridge. The bridge tuple is Kotlin 2.4.20 / Metro 1.4.5 / SKIE 0.10.15 / Compose 1.9.0. HEAD is `ba8270fabed862ae52a09e918e9803390d0fd8cb`; intentional working changes remain unstaged. Historical receipts bind their own working snapshots, not this document's source or a clean commit.

## Decision evidence and limits

The [fresh primary-source receipt](evidence/2026-10-04-security-feasibility.json) retains 24 successful HTTP responses, exact bodies, SHA-256 digests and retrieval timestamps: release discovery, the 0.13.0 catalog, Google Maven metadata, four versioned AGP POMs and all 17 previously identified advisory records. The release response contains 26 entries; pagination headers were not retained, so this packet does not certify a complete release-history crawl. The separately browsed [public release page](https://github.com/JetBrains/kotlin-toolchain/releases) still identifies 0.13.0 as latest.

The [targeted fix lookup](evidence/2026-10-04-fix-boundaries.json) contains 22 exact Maven queries with complete, unpaginated results. Selected reference versions reproduce the 17 known IDs. Refreshed record classifications are 2 Critical, 8 High and 7 Moderate. This lookup refreshes these reference coordinates and fix leads; it is **not a fresh complete baseline/candidate selected-input inventory**, does not discover all possible newly affected inputs and supplies no new artifact-byte joins. The prior complete candidate/plugin review covered 549 exact pairs. Its attribution scope and uncovered shaded/Native/test inputs still apply.

An initial sandbox network attempt returned no HTTP responses; its [failed receipt](evidence/2026-10-04-security-feasibility-network-failure.json) remains separate. Exit diagnostics were not captured by that scratch collector, so the receipt establishes transport failure without a precise cause. A permitted public-network retry supplied the successful receipt. No incomplete response was treated as absence of findings. This collection executed no downloaded code and installed no dependencies.

Toolchain 0.13.0 remains published at 2026-10-01T06:36:56Z. Its seven-day threshold is **2026-10-08T06:36:56Z (08:36:56 Copenhagen)**. Admission requires refreshed release/advisory evidence within 24 hours of the eventual decision; reaching that date does not resolve security or compatibility gates.

## Available fixes versus a supported owner cohort

These exact fix leads returned no findings in this targeted OSV lookup. That means provider absence for the named version at collection time, not proof of safety, publication maturity, artifact authenticity or drop-in compatibility. The existing [finding-level triage](direct-advisory-triage.md) gives IDs, conditions and selected paths; the refreshed full records remain in the receipt.

| Owner and selected reference | Fix lead | What remains before Mobi remediation can be credited |
| --- | --- | --- |
| AGP builder/lint: bcprov and bcpkix 1.79 | Both ordinary jdk18on artifacts at 1.85 | Supported owner selection, exact bytes and signing/parser compatibility. BC 1.80.2 removes only GOST from these five IDs; Critical PKIX, High ASN.1 and two Moderate IDs remain. |
| Toolchain telemetry: Jackson core 2.21.1 | 2.21.7 in the same branch | Owner upgrade and actual selected/bundled replacement; three High IDs currently match. |
| AGP Jetifier: JDOM 2.0.6 | 2.0.6.1 | Advisory lookup improves, but the actual Jetifier helper still expanded the owned canary with this version. Consumer parser hardening and relevant configuration coverage are separate requirements. |
| AGP bundletool: jose4j 0.9.5 | 0.9.6 | Supported bundletool cohort and relevant archive/JWE consumer evidence; High remains in the selected reference. |
| Toolchain IntelliJ util: org.lz4 1.8.0 | at.yawk.lz4 1.11.1 | Owner-supported namespace/JNI migration, packaging and decompression compatibility; two High and one Moderate IDs. A force rule in the old namespace is not an established migration. |
| AGP: Kotlin Gradle Plugin 2.2.10 | Stable 2.4.20 reference | Actual bundled/selected KGP replacement and KAPT cache conditions. Toolchain application compiler 2.4.20 and bridge Kotlin 2.4.20 are different inputs. |
| Toolchain telemetry: OpenTelemetry API 1.60.1 | 1.62.0 | Supported coupled telemetry update and trace-propagator inventory; related packages need their own queries. |
| Lint: Commons Lang3 3.16.0 | 3.18.0 | Supported lint/Commons owner selection and byte attribution. |
| Lint: HttpClient 4.5.6 | 4.5.13 | Supported sdklib/HttpMime cohort; a HttpClient 5 migration is a separate API decision. |

Fresh [AGP 9.3.3 builder declarations](https://dl.google.com/dl/android/maven2/com/android/tools/build/builder/9.3.3/builder-9.3.3.pom) still specify BC 1.79. [AGP 9.4.1 builder declarations](https://dl.google.com/dl/android/maven2/com/android/tools/build/builder/9.4.1/builder-9.4.1.pom) specify 1.80.2; its Gradle POM still specifies KGP 2.2.10. Google metadata still lists 9.4.1 as the newest stable version found. Neither declaration is Mobi-selected evidence or a rehearsed Toolchain cohort. AGP age and supported override compatibility remain unestablished. The reviewed Toolchain catalog still uses AGP 9.3.1. No supported complete remediation cohort has been demonstrated by these sources.

## Demonstrated scoped conditions

The [mitigation review](advisory-mitigation-review.md) reproduced GOST counter reuse and PKIX constraint bypass using verified BC 1.79 library fixtures. Independent 1.85 controls corrected those bounded conditions. This is library evidence, not a trace of attacker-controlled application/build inputs into those functions. No BC fix has been applied to Mobi.

The actual Jetifier XML helper expanded an owned entity canary with both JDOM 2.0.6 and 2.0.6.1. Explicit parser entity hardening prevented that fixture expansion; it is not an installed mitigation. The [condition measurement](jetifier-condition-assessment.md) read effective Jetifier false in every captured generated Android scope, with zero observed Jetifier actions and positive listener controls. It covers the successful prepare/build scopes of run `52ef96bd596b24dc92c8288a12917b79`; unmeasured variants, parser callers and future inputs remain outside it. Its state stays `bounded_disabled`, advisory review stays required and mitigation verification stays false.

Earlier KAPT configuration/calls were unobserved in bounded jobs. Classpath ownership, no observed call, private caches, passing tests and absence of a packaged artifact claim do not establish universal unreachability. No finding is disposed as not affected or accepted risk here.

## Policy decision paths

`maintenance-policy.json` blocks High/Critical, requires unknown-severity triage, enforces seven-day release age and 24-hour evidence freshness, and disables automatic adoption. `scripts/maintenance/lib/policy.rb` contains no mitigation-exception mechanism. A maintainer saying “approve 0.13.0” cannot be recorded as satisfying this unchanged policy while blockers persist.

The recommended path is a supported owner cohort that selects remediated inputs. First obtain a versioned owner declaration or documented supported configuration covering BC 1.85 and the other High findings; pin its source and artifacts, establish age/support, then collect actual selected/bundled inputs in an isolated source copy. Stop before costly functional pairs if it still selects blockers. Rehearse native/packaging behavior only after new inputs or a specific unresolved compatibility concern justify it. A catalog-only BC upgrade or AGP 9.4.1 is insufficient. No upstream message is authorized or sent by this packet.

If a future maintainer instead requests a mitigation exception, it requires a **separate explicit policy proposal and approval**, followed by implementation and review before adoption. No exception is proposed for approval here because exposure evidence and enforceable controls are incomplete. A concrete proposal must specify:

- Exact advisory IDs, artifact hashes, owner versions, source snapshot, operations and trust boundaries covered; no family-wide or future-version exemption.
- Evidence supporting each condition, enforceable controls and their observed tests, residual exposure, and how uncovered variants/inputs fail closed.
- An accountable maintainer decision, explicit start/expiry timestamps, bounded scope and mandatory revalidation on source/tool/input/variant drift or advisory change.
- A distinct evaluator representation for accepted risk, preserving original findings and severities; no suppression or conversion into verified remediation. Update policy validation, adoption gating, expiry enforcement and meaningful refusal tests together.
- Rollback/revocation and what happens at expiry. Age, 24-hour freshness, unknown-severity triage, attribution gaps and functional/operational gates remain independently enforced.

A policy change would accept residual risk rather than fix inherited baseline defects. It must not silently authorize bridge switching, deletion, signed delivery, release publication or expanded platform support.

## Exact adoption packet still required

The [three-file rehearsal preview](evidence/2026-10-03-toolchain-rehearsal-preview.patch) is not an adoption package. A later package must include an exact allowlisted patch, content/mode preimages and postimages, unchanged unrelated/index state, source-bound rollback and a maintainer decision for these surfaces:

| Surface | Required integration evidence |
| --- | --- |
| Wrapper and baselines | `kotlin`, `kotlin.bat`, matching `maintenance-kotlin-toolchains.json`, `maintenance-compatibility.json` and any version-bound attribution/parser configuration; reviewed candidate distribution/checksum and source pins. Preserve historical replay rather than relabeling old receipts. |
| Android SDK 37 | `android-app/module.yaml` compile SDK only; min/target 36 retained. Public setup and repo-owned provisioning jobs must cover SDK/build tools, explicit license prerequisites and API-above-minimum checks. No automatic acceptance of host licenses. |
| Public onboarding and CI | Fresh clean-source/empty-cache onboarding and cold hosted evidence for exact content; preserve quality hooks, Renovate/probes, thin workflow callers and release/smoke separation. Prepared-host private provisioning is historical evidence only. |
| Native/API/plugin preservation | Existing Xcode app/test targets, test plans/macros, Swift sealed-state adapters, Metro/Compose/SKIE requirements, ARM outputs and framework consumers. Close remaining shaded/Native/test-compiler attribution or document a reviewed coverage disposition without claiming complete coverage. |
| Runtime/support | Existing API 36 launch smoke is bounded; permission/features need appropriate checks. Simulator 26.5 is not exact iOS 26.0. Record exact-floor availability and physical-device coverage decisions under the stable previous-major support policy; document support loss rather than retaining obsolete targets automatically. |
| Release and rollback | Historical fixture-signed Android APK/AAB, unsigned ARM simulator app and unsigned ARM64 archive remain bounded receipts. Record signed/export/device gates and their disposition; execute credentialed operations only with separate authorization. Validate restoration from exact reviewed content and rerun affected consumers. |
| Decision-time security | Fresh complete selected/bundled/plugin advisory receipts, release interval and age, each residual disposition and policy-compliant approval. This targeted query does not replace that collection. |

## Independent bridge-retirement handoff

After an explicitly approved adoption package is integrated and validated, start a fresh direct assessment against that adopted tuple. Preserve the [independent capability matrix](bridge-retirement-path.md): bridge unavailable, original native app/test targets, typed sealed-state adapters, compiler plugins, API/framework interop, lifecycle/failure/generic behavior, relevant runtime/device coverage, onboarding, cold hosted CI and release packaging. The historical 0.12.2 direct round trip remains its own receipt. Initial SwiftPM support is still unexecuted here and supplies no retirement credit. Review a reversible direct-default switch before a separate physical-deletion decision.

The common maintenance core remains reusable without private infrastructure or mandatory AI access. Kotlin and dormant Elixir/Phoenix adapters remain independent; no Go application prerequisite is introduced.

## Subsequent maintainer direction

On 2026-10-04 the maintainer chose adoption followed by priority bridge-retirement
assessment despite persistent inherited risk. See the [concrete adoption/risk
review](toolchain-adoption-risk-review.md). This changes the intended direction;
it preserves this packet's evidence and does not silently activate a policy or
release-age exception.
