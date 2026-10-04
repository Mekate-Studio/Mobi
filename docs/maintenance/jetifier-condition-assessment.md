# Jetifier conditions and upstream-owner remediation

Date: 2026-10-03. Decision: **adoption remains blocked**. This follow-up adds effective-option and transform observations to the existing isolated build-input workflow. A bounded disabled Jetifier condition cannot clear the JDOM advisory, accept risk or authorize a dependency upgrade. The retained iOS Gradle bridge remains in production.

## Verified build conditions

Run `52ef96bd596b24dc92c8288a12917b79` completed both phases successfully at HEAD `ba8270f`, with working-source SHA `70d5b9c3927238487935b3d5e88e410b97f504bea7de05b5d7a2478cc7bf3760`. The receipt predates these final documentation edits and supplies no clean-commit/hosted validation. It compares Toolchain 0.12.2 with experimental 0.13.0; only the candidate copy uses compile SDK 37. Both phases retain the Gradle iOS bridge, Android min/target SDK 36 and minimum iOS 26.0.

Both phases passed 38 Android tests, produced a debug APK, and compiled the five shared modules' ARM device and ARM simulator KLIBs. This profile did not run XCTest, link the Xcode app/framework, execute SwiftPM, sign/export release packages or remove the bridge.

| Phase | Generated Android scopes | Effective option / explicit property | Identity events / all transform actions | Jetifier actions observed | Condition state |
| --- | --- | --- | --- | --- | --- |
| Baseline 0.12.2 | Prepare + build; all six Android projects in each | `false` / absent in every project | 8,501 / 1,413 | 0 | `bounded_disabled` |
| Candidate 0.13.0 | Prepare + build; all six Android projects in each | `false` / absent in every project | 9,005 / 1,557 | 0 | `bounded_disabled` |

Counts sum each phase's two captured generated builds; repeated projects are not extra independent capabilities. The listener observed other transforms in both phases. Zero Jetifier actions applies only to these successful observed builds. It does not establish absence from unmeasured variants or remove JDOM from the classpath.

The probe obtains `ProjectOptions` from the actual internal AGP plugin instance, fingerprints its loaded class containers, and records the effective `ENABLE_JETIFIER` boolean separately from the explicit property. It does not collect arbitrary project properties. The current private API binding accepts AGP 9.3.1; other versions remain incomplete until their APIs are reviewed.

The version-bound Gradle listener covers initialization through build completion, including resolution triggered by evidence collection. It observes planned transform steps, transform-identity progress and actual transform actions. Planned-step events alone are insufficient: Gradle can execute transforms during resolution without a planned-step descriptor. The actual pair uses Gradle 9.5.0. API bindings also accept 9.6.1, whose primary interfaces were inspected; a full 9.6.1 execution was not performed in this follow-up. [Gradle execution implementation](https://raw.githubusercontent.com/gradle/gradle/v9.5.0/platforms/software/dependency-management/src/main/java/org/gradle/api/internal/artifacts/transform/AbstractTransformExecution.java), [planned-step implementation](https://raw.githubusercontent.com/gradle/gradle/v9.5.0/platforms/software/dependency-management/src/main/java/org/gradle/api/internal/artifacts/transform/TransformStepNode.java).

A separate disposable fixture used a cloned, fingerprint-checked AGP classpath and local JAR. Its disabled control read `false` and recorded no Jetifier action; requesting Android class artifacts with Jetifier explicitly enabled detected one executed `JetifyTransform` action and the actual AGP container. The enabled control remained incomplete: several transform identities shared one enclosing operation, and the identity API does not expose an exact input-byte path. The fixture is a listener control, not a Mobi capability receipt; the original build-input reader correctly refused its different generated-task/schema scope. Plain classpath resolution with an enabled option recorded no Jetifier action, demonstrating why an enabled setting alone is not execution proof.

`compatibility-report` now derives `jetifier_conditions` from verified retained graph packets. Its states distinguish `bounded_disabled`, `review_required`, `incomplete` and historical unmeasured builds. Missing or contradictory options, unsupported APIs, missing identity coverage, unknown implementations, unfinished actions and unverifiable executed inputs cannot become a disabled result. Older graph receipts remain usable for their original capability and report the new capability as unmeasured. Every condition result retains `advisory_state: review_required`, `mitigation_verified: false` and `adoption_authorized: false`.

## Upstream replacement discovery

The current complete first-page Toolchain release response contains 26 entries and no next page. Its latest release remains 0.13.0, published 2026-10-01T06:36:56Z. Both inspected 0.12.2/0.13.0 catalogs declare AGP 9.3.1. A catalog's separate BC 1.84 declaration does not replace delegated AGP/lint selection of 1.79. [Toolchain releases](https://github.com/JetBrains/kotlin-toolchain/releases), [0.13.0 catalog](https://raw.githubusercontent.com/JetBrains/kotlin-toolchain/v0.13.0/libs.versions.toml).

| Owner family inspected | Declared BC inputs | Evidence and remaining gates |
| --- | --- | --- |
| AGP 9.3.1 used by the pair | builder 1.79 | Actual selected graph and container identities; existing critical conditions remain unresolved |
| Latest 9.3 patch found: 9.3.3 | builder / sdk-common 1.79 | Versioned POMs; no BC remediation lead in these declarations; not rehearsed |
| Newer stable family: 9.4.0 / 9.4.1 | builder / sdk-common 1.80.2 | Versioned POMs and declared-version advisory lookup; only partial BC remediation; not selected or rehearsed through Toolchain |

Google Maven metadata lists 9.4.1 as the latest stable AGP version found. Metadata and POM retrieval times do not establish each version's publication age. The inspected 9.4.x AGP declarations still include KGP 2.2.10, Jetifier 1.0.0-beta10 and bundletool 1.18.3; inspected sdk-common still declares Commons Compress 1.27.1, and sdklib still declares HttpMime 4.5.6. These are declared owner inputs, not a complete selected graph or proof of how all advisories change. No Toolchain release adopting this newer AGP family was found, and no forced transitive substitution was made. [Google metadata](https://dl.google.com/dl/android/maven2/com/android/tools/build/gradle/maven-metadata.xml), [9.3.3 builder POM](https://dl.google.com/dl/android/maven2/com/android/tools/build/builder/9.3.3/builder-9.3.3.pom), [9.4.1 builder POM](https://dl.google.com/dl/android/maven2/com/android/tools/build/builder/9.4.1/builder-9.4.1.pom), [9.4.1 AGP POM](https://dl.google.com/dl/android/maven2/com/android/tools/build/gradle/9.4.1/gradle-9.4.1.pom).

A fresh OSV batch checked exactly `bcprov-jdk18on` and `bcpkix-jdk18on` at 1.79 and 1.80.2, followed by all five unique full records. All responses were complete and unpaginated. The 1.80.2 lookup omits GOST counter-reuse ID `GHSA-574f-3g2m-x479`, consistent with its recorded backport. It retains the Critical PKIX constraint issue, High lazy ASN.1 issue and Moderate LDAP/composite-signature issues. This is a declared-version discovery result, not verified remediation in Mobi. [GOST record](https://api.osv.dev/v1/vulns/GHSA-574f-3g2m-x479), [PKIX record](https://api.osv.dev/v1/vulns/GHSA-9pwp-9qqc-pr26), [ASN.1 record](https://api.osv.dev/v1/vulns/GHSA-qp49-qgx5-5m26).

## Failures, recovery and validation

The corrected implementation passed 260 contracts across 16 suites, the existing ktlint/detekt/SwiftFormat/SwiftLint/ShellCheck static gate, and all 22 strict OpenSpec validations. The full contract suite first encountered sandbox process-inspection restrictions; another launcher attempt selected an incompatible Intel Git binary and failed before the new tests. The native-system-Git rerun with required process access passed. Those environment failures are recorded separately from the passing suite.

All three rehearsal attempts reached quiescent recovery and guarded cleanup, preserving control evidence. A report request during active cleanup correctly refused its lease; after cleanup completed, replay produced a byte-identical corrected report. The task-created fixture's cloned caches/SDK and checksum-verified inspection JAR were also removed after verifying its process marker absent. Production pins, native/bridge sources, workflow defaults and policy have no changes in this slice.

The first full attempt bound only Gradle 9.6.1 although the actual delegated runner was 9.5.0, and it selected a plugin without the required option service. It was interrupted after preserving raw graphs; an initial recovery correctly refused its active coordinator lease. Only an identity-checked owned coordinator was then stopped; recovery reached quiescent state and guarded discard removed its work. The second pair passed functional checks but still had incomplete options and lacked transform-identity progress coverage. Its source-bound receipt remains inconclusive for Jetifier. Both failed/inconclusive attempts retain logs and control evidence independently of the corrected pair.

The disposable fixture initially could not resolve an offline plugin marker from Toolchain's cache. Reusing the exact already-resolved owner classpath addressed that fixture setup gap. Its class-name diagnostic exposed the public wrapper/internal service distinction. The first offline fixture log was overwritten during iteration; its observed failure is recorded separately, without claiming a retained original log hash. No failure was converted into a compatibility pass. Control receipts, raw producer hashes, primary-source byte hashes and cleanup outcomes are retained in the [public evidence](evidence/2026-10-03-jetifier-conditions.json); ignored local logs contain the longer diagnostics.

## Untested assumptions and adoption blockers

The measurement does not cover every Android variant, parser caller, hosted cache, compiler/native shaded input or dependency trust boundary. It does not establish JDOM parser unreachability across Mobi, remove the vulnerable JAR or prove that changing JDOM alone hardens Jetifier. The earlier [mitigation review](advisory-mitigation-review.md) reproduced unsafe XML helper behavior even with JDOM 2.0.6.1; that condition remains separate from a disabled generated build.

The earlier complete selected/plugin/bundled review still has 17 review-required findings; this follow-up is not a refreshed attribution-complete lookup for all 17 on a new source. Its new declared-owner lookup covers five BC records only. High/Critical policy blocking and unknown-severity triage remain unchanged, and the policy has no mitigation-exception mechanism. Toolchain 0.13.0 reaches the normal seven-day threshold at 2026-10-08T06:36:56Z; release maturity alone cannot close those security gates.

The next useful review is a supported owner cohort whose selected inputs actually remediate the critical/high findings, followed by fresh complete attribution/advisories, compilation/native/packaging checks and a concrete adoption packet. A newer AGP POM or a successful library fixture cannot supply Toolchain compatibility, release age, signed packaging or clean-host onboarding evidence. Any proposed target/architecture change must record support loss and policy implications before a maintainer decision. Existing [adoption gates](toolchain-adoption-assessment.md) and [bridge-retirement gates](bridge-retirement-path.md) remain independent. SwiftPM execution and bridge-unavailable parity receive no credit from this work.

## Repeat the repository-owned measurement

```sh
./scripts/dev/dependency_updates.sh rehearse-upstream \
  --experimental --compile-sdk 37 --profile build-inputs --store jetifier-review
./scripts/dev/dependency_updates.sh compatibility-report RUN_ID --store jetifier-review
./scripts/dev/dependency_updates.sh recover RUN_ID --stop --store jetifier-review
./scripts/dev/dependency_updates.sh cleanup RUN_ID --apply --discard --store jetifier-review
```

Use the returned run ID and review the verified report before discarding work. The experimental switch permits isolated collection before release-age admission; it grants no adoption exception. The candidate compile-SDK edit stays inside its copy, with min/target SDKs unchanged. Cleanup retains logs, packet hashes and the recorded outcome; it does not resume or adopt the rehearsal. Ordinary shell tools suffice, with no mandatory AI service or private infrastructure.
