# Direct-input advisory triage

Date: 2026-10-03. Decision: **17 findings remain review-required**. This is an
owner, affected-function and remediation review of selected build inputs, not an
exploit test or an exemption. No dependency adoption or bridge/default change
was made. See the [original build-input assessment](direct-build-input-assessment.md)
and [attribution receipt](evidence/2026-10-03-plugin-attribution.json).

The later [condition and mitigation review](advisory-mitigation-review.md)
adds selected consumer disassembly, candidate byte joins and bounded BC/XML
fixtures. Its measured results supersede this document's earlier untested
fixture observations within that scope; all 17 findings still require review.

The [Jetifier condition follow-up](jetifier-condition-assessment.md) measures
effective disabled options in both Toolchain phases and separately examines
newer AGP owner declarations. It supplies bounded condition evidence and
partial upstream remediation leads, without clearing these findings.

## Verified selection and ownership

The fresh 578-query lookup includes the original 576 module/delegated pairs and
two fingerprint-attributed compiler components. It returned the same 17 IDs,
with complete batches and full records, no pagination or transport errors.
Neither attributed plugin matched an advisory. This is a time-bound lookup;
provider absence does not establish absence of vulnerabilities.

The retained actual graphs put all 17 matches in delegated settings or Android
lint scopes. Representative shortest selected paths are recorded in the receipt:

- Toolchain settings plugin → schema/telemetry → OpenTelemetry → Jackson.
- Toolchain settings plugin → AGP 9.3.1 → builder → Bouncy Castle 1.79.
- Toolchain settings plugin → AGP → bundletool 1.18.3 → jose4j 0.9.5.
- Toolchain settings plugin → AGP → Jetifier processor → JDOM 2.0.6.
- Toolchain settings plugin → AGP → Kotlin Gradle plugin 2.2.10.
- Toolchain settings plugin → frontend API → IntelliJ platform util → LZ4 1.8.0.
- Lint 32.3.1 → sdk-common → Commons Compress → Commons Lang 3.16.0.
- Lint 32.3.1 → sdklib → HttpMime → HttpClient 4.5.6.
- Lint 32.3.1 → sdk-common → Bouncy Castle 1.79.

These are resolver selection paths, not executed call paths. They identify
upstream ownership and the inputs to examine. They do not establish that these
libraries are absent from APKs/frameworks or that vulnerable functions execute.

## Prioritized critical review

`bcprov-jdk18on` 1.79 is selected by AGP builder and lint tooling. The two Critical
classifications belong to the captured provider records; Mobi exploitability is
unmeasured.

For [GHSA-574f-3g2m-x479](https://api.osv.dev/v1/vulns/GHSA-574f-3g2m-x479),
the [primary counter fix](https://github.com/bcgit/bc-java/commit/b42574345414e4b7c8051b16fa1fafe01c29871f)
changes `G3413CTRBlockCipher` counter propagation. Exposure requires use of this
CTR implementation, enough blocks to wrap the vulnerable counter, and observable
ciphertexts under the relevant key/IV conditions. The captured builds provide
no evidence about those calls, algorithms or ciphertext access. They must not
be labeled either exploitable or unreachable. Recorded fixed branches are
1.80.2, 1.81.1 and 1.84; selecting one does not resolve the other BC findings.

For [GHSA-9pwp-9qqc-pr26](https://api.osv.dev/v1/vulns/GHSA-9pwp-9qqc-pr26),
the [primary validation fix](https://github.com/bcgit/bc-java/commit/2c28b253a44681fbbc562561eab6ad383d2ae558)
changes `PKIXNameConstraintValidator` matching, including trailing-dot handling
for email/URI constraints. Exposure requires BC certificate-path validation
with applicable constraints and attacker-influenced certificate names. A
signing/crypto library on a builder classpath does not prove this validation
path is used. Neither certificate handling nor an adversarial chain was
rehearsed. The ordinary Java artifact's recorded fix boundary is 1.85;
FIPS/LTS branches in the same record are different packages and are not Mobi's
selected component.

Action: trace AGP builder/lint consumers and supported upstream dependency
changes, then rehearse the owner-supported candidate with signing/package and
native regression checks. An arbitrary Bouncy Castle force-version rule is
not a validated remediation.

## Finding-level review

All rows have state `review_required`. A fix boundary is taken from the matched
package's captured record, not from a different artifact or namespace. Except
for the KAPT observation below, relevant runtime/input conditions were not
measured. Exact records and linked upstream fixes were captured with hashes and
timestamps; some records do not link a retrievable fix commit.

| Advisory | Selected input / owner | Affected function or required input to investigate | Recorded remediation boundary / limitation |
| --- | --- | --- | --- |
| [7hhh-6rmp-j9qf](https://api.osv.dev/v1/vulns/GHSA-7hhh-6rmp-j9qf) | Jackson core 2.21.1 / telemetry | Invalid-token handling in `UTF8DataInputJsonParser`; oversized untrusted DataInput tokens | 2.21.7 in the selected release branch; alternative branches differ |
| [p6pp-m3f8-5c89](https://api.osv.dev/v1/vulns/GHSA-p6pp-m3f8-5c89) | Jackson core 2.21.1 / telemetry | `NumberInput.looksLikeValidNumber`; adversarial numeric strings | 2.21.7 in the selected branch; parser/caller use unmeasured |
| [r7wm-3cxj-wff9](https://api.osv.dev/v1/vulns/GHSA-r7wm-3cxj-wff9) | Jackson core 2.21.1 / telemetry | Nonblocking integer parsing with small chunks and no terminator | 2.21.4; earlier async fix was incomplete |
| [rcgg-9c38-7xpx](https://api.osv.dev/v1/vulns/GHSA-rcgg-9c38-7xpx) | OpenTelemetry API 1.60.1 / telemetry | `W3CBaggagePropagator` extraction of oversized baggage | 1.62.0; build telemetry does not establish an inbound baggage path |
| [j288-q9x7-2f5v](https://api.osv.dev/v1/vulns/GHSA-j288-q9x7-2f5v) | Commons Lang3 3.16.0 / lint | `ClassUtils.getClass` with very long class-name inputs | 3.18.0; lint-owned transitive change needs upstream support |
| [7r82-7xv7-xcpj](https://api.osv.dev/v1/vulns/GHSA-7r82-7xv7-xcpj) | HttpClient 4.5.6 / lint | Malformed `java.net.URI` authority selecting the wrong request host | 4.5.13 in the selected major; 5.0.3 is a separate API line |
| [3677-xxcr-wjqv](https://api.osv.dev/v1/vulns/GHSA-3677-xxcr-wjqv) | jose4j 0.9.5 / bundletool | Processing compressed JWE with extreme expansion | 0.9.6; bundletool use of JWE unmeasured |
| [wg6q-6289-32hp](https://api.osv.dev/v1/vulns/GHSA-wg6q-6289-32hp) | bcpkix 1.79 / builder, lint | Composite verifier accepting an empty signature list | 1.84; does not close bcprov 1.85 findings |
| [574f-3g2m-x479](https://api.osv.dev/v1/vulns/GHSA-574f-3g2m-x479) | bcprov 1.79 / builder, lint | GOST CTR counter reuse; critical review above | 1.80.2 / 1.81.1 / 1.84 branches |
| [9pwp-9qqc-pr26](https://api.osv.dev/v1/vulns/GHSA-9pwp-9qqc-pr26) | bcprov 1.79 / builder, lint | PKIX name-constraint bypass; critical review above | 1.85 for this artifact |
| [c3fc-8qff-9hwx](https://api.osv.dev/v1/vulns/GHSA-c3fc-8qff-9hwx) | bcprov 1.79 / builder, lint | LDAP certificate-store helpers with attacker-controlled query values | 1.84; LDAP use unmeasured |
| [qp49-qgx5-5m26](https://api.osv.dev/v1/vulns/GHSA-qp49-qgx5-5m26) | bcprov 1.79 / builder, lint | Lazy ASN.1 forcing resetting nested-depth protection | 1.85; parsed ASN.1 trust and call path unmeasured |
| [2363-cqg2-863c](https://api.osv.dev/v1/vulns/GHSA-2363-cqg2-863c) | JDOM 2.0.6 / Jetifier | SAXBuilder external-entity behavior on crafted XML | 2.0.6.1; no Jetifier parser-hardening or malicious-XML probe |
| [r937-wjx7-w2jp](https://api.osv.dev/v1/vulns/GHSA-r937-wjx7-w2jp) | Kotlin Gradle plugin 2.2.10 / AGP | KAPT incremental cache deserialization | Record boundary 2.4.20-Beta1; stable 2.4.20 described; KAPT condition unobserved in prior bounded builds |
| [cmp6-m4wj-q63q](https://api.osv.dev/v1/vulns/GHSA-cmp6-m4wj-q63q) | org.lz4 LZ4 Java 1.8.0 / IntelliJ util | Java decompressor with reused uncleared output and crafted compressed data | Original namespace lists last-affected 1.8.1; fork 1.10.1 fixes this issue |
| [vqf4-7m7x-wgfc](https://api.osv.dev/v1/vulns/GHSA-vqf4-7m7x-wgfc) | org.lz4 LZ4 Java 1.8.0 / IntelliJ util | Out-of-bounds decompression of untrusted input | 1.8.1 fork/redirect path; original project archived; not a complete three-finding fix |
| [xx22-p4ch-683r](https://api.osv.dev/v1/vulns/GHSA-xx22-p4ch-683r) | org.lz4 LZ4 Java 1.8.0 / IntelliJ util | JNI XXHash with invalid array reference/range, rather than bytes alone | Original last-affected 1.8.1; fork 1.11.1 fixes this issue; namespace migration needs owner review |

The [Kotlin fix](https://github.com/JetBrains/kotlin/commit/bf51df665b458fda7c3eaf436c4d88dc119d7ec6)
restricts KAPT incremental-cache deserialization. The original paired build
observed no explicit KAPT configuration, KAPT arguments or Java/APT cache files.
That condition was unobserved in the bounded jobs; it is not proven unreachable
in all configurations. The selected Android KGP version differs from both the
Toolchain compiler and retained iOS bridge Kotlin versions. Updating either of
those declarations alone does not prove replacement of the AGP-selected KGP.

## Supported remediation assessment

The captured [Toolchain 0.13.0 release](https://github.com/JetBrains/kotlin-toolchain/releases/tag/v0.13.0)
was published 2026-10-01T06:36:56Z. Its seven-day eligibility time is
2026-10-08T06:36:56Z. On this assessment date it is age-blocked for normal
adoption. An explicitly marked experimental rehearsal may collect evidence,
but age and maintainer review remain separate gates.

The versioned [0.12.2 catalog](https://github.com/JetBrains/kotlin-toolchain/blob/v0.12.2/libs.versions.toml)
and [0.13.0 catalog](https://github.com/JetBrains/kotlin-toolchain/blob/v0.13.0/libs.versions.toml)
both declare AGP 9.3.1, Android tools 32.3.1, OpenTelemetry 1.60.1 and IntelliJ
platform 261.26222.65. The latter changes the default Kotlin compiler to 2.4.20.
Both catalogs declare Bouncy Castle 1.84, while the actual 0.12.2 delegated
settings/lint graphs selected 1.79. This discrepancy demonstrates why a catalog
pin cannot substitute for selected-graph evidence. Neither catalog inspection
nor the announced compiler upgrade proves the 17 findings are remediated.
The 0.13.0 delegated graphs and behavior have not been rehearsed here.

Next remediation slice: review and pin a supported Toolchain candidate, capture
its delegated settings/lint graphs and artifact identities, refresh exact
advisories, and compare selection and behavior. Identify which findings actually
change. If the owner retains affected inputs, investigate supported AGP/telemetry/
IntelliJ updates or documented mitigations; retain blockers instead of silently
forcing generated-build transitives. Major versions or namespace migrations
require an explicit compatibility and architecture decision. Fixed-version
release ages and drop-in compatibility have not been verified for these
transitive candidates.

Before requesting adoption, present a concrete reversible candidate with Android
host tests/builds, compiler plugins and ARM/native app/test preservation,
clean-clone and release-package checks appropriate to its changes, exact-input
advisory results, unresolved risk decisions and rollback evidence. This remains
independent of the [bridge-retirement workflow](bridge-retirement-path.md).
No waiver, automatic upgrade or bridge deletion follows from this review.

## Untested assumptions and blockers

The subsequent [Toolchain 0.13.0 upstream assessment](upstream-toolchain-assessment.md) passed its bounded builds but retained 16 baseline advisory IDs after exact artifact byte-reference attribution. It left 32 bundled files unassigned; the absent KAPT ID is not verified remediation. That result advances the proposed upstream rehearsal without resolving the exposure and adoption gates below.

The later [bundled identity follow-up](bundled-input-assessment.md) accounts for those files and restores KAPT: all 17 baseline IDs are reported by the fresh expanded lookup. No finding has been removed by verified remediation, and the exposure review below remains necessary.

There is no application reachability trace, signing/crypto call trace, packaged
artifact absence proof, adversarial input/cache rehearsal or complete shaded
code inventory. No finding has been designated not affected or accepted risk.
No new release or cold hosted direct build was run. Source-safe lookup and
fingerprint attribution close bounded evidence gaps, while these exposure and
retirement gates remain open.
