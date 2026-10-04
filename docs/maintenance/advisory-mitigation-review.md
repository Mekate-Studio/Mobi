# Advisory condition and mitigation review

Date: 2026-10-03. Decision: **adoption remains deferred; all 17 findings remain
review-required**. The captured classifications are two Critical, eight High and
seven Moderate. This follow-up measures selected consumer code and small library
conditions. It does not accept risk, change dependency pins, waive policy or
prove application exploitability. Production remains Toolchain 0.12.2 with the
Gradle iOS bridge. Continuing that existing baseline is not a new security
approval, and waiting for 0.13.0's release age does not resolve these findings.

Read this alongside the [original owner triage](direct-advisory-triage.md),
[retained-bridge adoption assessment](toolchain-adoption-assessment.md) and
[source-bound receipt](evidence/2026-10-03-advisory-mitigation-review.json).

## Verified inputs and evidence limits

The existing plugin producer `f0d6207beefc5d95faa0793e1a9a5a4e` replays
successfully after cleanup. Its retained provider lookup covers 549 exact Maven
pairs and reports 17 IDs, with full records retrieved at
2026-10-03T18:40:20Z–18:40:27Z. This review reuses those verified records; it does
not claim a newly refreshed advisory lookup. Evidence must be refreshed after
the policy's 24-hour window before an adoption review.

Thirty selected baseline owner/library JARs were independently obtained from
public Maven Central, Google Maven, JetBrains and IntelliJ release repositories.
Every JAR matches the original delegated graph by SHA-256 and byte length.
Class-file inspection covers 51,217 class files and 958 targeted constant-pool
method references; the public receipt retains 47 references outside the
inspected dependency libraries' own package families. These are potential static
references, not executed calls or a complete call graph. The
[official IntelliJ artifact guide](https://plugins.jetbrains.com/docs/intellij/intellij-artifacts.html)
identifies the release repository used for its two selected util artifacts.

Exact byte joins against the original candidate graphs match 28 of the 30
artifacts. That includes Bouncy Castle 1.79, JDOM 2.0.6, Jetifier beta10,
bundletool 1.18.3 and IntelliJ util 261.26222.65. Candidate bundled matches are
byte-reference attribution, not proof of a Maven resolver coordinate. Baseline
telemetry 0.12.2 and KGP's `gradle813` variant have no candidate byte join here;
their inspected code is not credited to different candidate files. The previous
[bundled assessment](bundled-input-assessment.md) still supplies their separate
identity/advisory evidence.

This is a selected-owner inventory, not the whole settings/lint classpath,
Toolchain internals, shaded code or packaged app. Reflection, service loading,
native code, complete certificate chains and actual sensitive signing operations
remain outside it. Absence of a targeted reference in this inventory cannot
close a finding.

## Measured conditions

The [fixture source](evidence/probes/AdvisoryConditions.java) compiled on the
recorded JDK 21. Each Java invocation had a 64 MiB heap limit and 30-second
timeout. Crypto uses synthetic zero key/IV/plaintext and reserved `.invalid`
names. XML references only a newly created known-content file inside the owned
probe directory. No network entity, private file, expansion bomb, production key
or shared cache is used. The fixed-version controls are isolated public artifacts,
not adopted dependencies or owner-supported replacement compatibility evidence.

| Condition | Selected input | Independent control | What the observation proves |
| --- | --- | --- | --- |
| GOST CTR counter wrap | bcprov 1.79 produces identical zero-plaintext output blocks 0 and 256 | bcprov 1.85 produces different blocks | The selected library exhibits the counter condition; Mobi use of this cipher is unproven |
| Excluded email name with trailing dot | bcprov 1.79 rejects the ordinary blocked domain, but accepts its trailing-dot form | bcprov 1.85 rejects both | The selected validator exhibits this bypass under the fixture's constraint |
| Excluded URI host with trailing dot | Same ordinary rejection / trailing-dot acceptance in 1.79 | Both rejected in 1.85 | Same bounded validator condition; no full certificate-chain proof |
| Default XML parser and Jetifier helper | JDOM 2.0.6 and Jetifier's actual helper expand the owned canary | Substituting JDOM 2.0.6.1 still expands it through the default parser and the same helper | A JDOM version change alone does not establish hardening of this default-parser path |
| Explicit XML entity setting | `setExpandEntities(false)` prevents canary expansion with JDOM 2.0.6 | Same result in 2.0.6.1 | A bounded mitigation fixture works; this setting has not been installed in Jetifier/Mobi |

The [GOST counter fix](https://github.com/bcgit/bc-java/commit/b42574345414e4b7c8051b16fa1fafe01c29871f)
and [name-constraint fix](https://github.com/bcgit/bc-java/commit/2c28b253a44681fbbc562561eab6ad383d2ae558)
support the tested conditions. The recorded fix boundary for the ordinary
`bcprov-jdk18on` name-constraint finding is
[1.85](https://github.com/advisories/GHSA-9pwp-9qqc-pr26); different FIPS/LTS
packages do not change that boundary. The counter fixture does not test every
cipher mode, and the name fixture does not test the fix's directoryName behavior.

The [JDOM advisory](https://github.com/advisories/GHSA-2363-cqg2-863c)
documents entity-expansion hardening. Its linked
[patch](https://github.com/hunterhacker/jdom/commit/dd4f3c2fc7893edd914954c73eb577f925a7d361)
synchronizes a parser feature setting with entity expansion; it does not
establish that callers choose hardened defaults. Canary non-expansion is not a
complete XML security or no-I/O test.

The first XML fixture attempt failed reflective method lookup because its
classpath lacked the already-selected `jetifier-core` artifact. The failed logs
and receipt remain. A fresh run added that fingerprint-verified fixture input;
all four fresh runs exited zero. Fixed-version control results did not authorize
transitive overrides. Their release ages, complete vulnerability status and
AGP replacement compatibility have not been assessed.

## Consumer observations and closure checks

Disassembly of the byte-verified Jetifier `XmlUtils` helper shows a default
`SAXBuilder` followed by `build(InputStream)`, with no intervening parser
hardening in that method. `PomDocument.Companion` references that helper.
The positive helper fixture establishes executable parser behavior, but the
original Mobi build did not trace a crafted POM into it.

Android's [AndroidX documentation](https://developer.android.com/jetpack/androidx)
states that `android.enableJetifier` defaults to false when unspecified.
That upstream default is useful context, not a measurement of Toolchain's
generated builds. No effective Jetifier option/transform trace was collected
here. Before proposing a disabled-Jetifier mitigation, capture the actual
generated value and transform inputs for baseline and candidate, and check that
all supported dependency/build variants work without it.

Bundletool's inspected transparency methods construct/parse `JsonWebSignature`
and constrain verification to RS256. Its inspected JAR has no targeted JWE or
generic JOSE-dispatch method reference. The
[jose4j advisory](https://github.com/advisories/GHSA-3677-xxcr-wjqv)
concerns compressed JWE. This narrows that specific consumer path; it does not
establish that every other classpath consumer avoids JWE or that reflective use
is impossible.

The inspected SDK `KeystoreHelper` has BC certificate/signing references and an
RSA/SHA256withRSA debug-keystore creation path. No external direct reference to
the two critical APIs appears in these 30 selected artifacts. Provider dispatch
and other uninspected consumers remain gaps; certificate generation/signing is
not proof that PKIX validation or GOST encryption cannot execute elsewhere.

IntelliJ `CompressionUtil` references LZ4 fast decompression and chooses native
or Java factories depending on host conditions. `CompressedAppendableFile`
references that wrapper. Some inspected methods allocate fresh output arrays;
the selected scope does not establish a universal fresh-buffer guarantee or
trusted-cache boundary. It does not clear all three distinct LZ4 findings.

All rows below retain `review_required`. Previously recorded package-specific
fix boundaries remain in the original triage; they are not validated drop-in
upgrades.

| Finding | Current bounded evidence | Required closure evidence |
| --- | --- | --- |
| Critical 574f-3g2m-x479 / GOST | Selected 1.79 condition reproduced; 1.85 control corrected it | Actual algorithm/provider consumers and inputs, or owner-supported replacement with regression/signing checks |
| Critical 9pwp-9qqc-pr26 / PKIX | Selected 1.79 email/URI condition reproduced; 1.85 control corrected it | Real certificate-path/provider/constraint consumers, or supported fixed owner stack and certificate/package regression |
| High 2363-cqg2-863c / JDOM | Actual Jetifier helper expands owned entity; explicit setting prevents fixture expansion | Effective Jetifier execution/input proof and enforced hardening/disablement, or hardened owner release with parser and build checks |
| High 3677-xxcr-wjqv / jose4j | Inspected bundletool transparency path uses JWS | Complete relevant JOSE consumers and compressed-input policy, or supported fixed dependency selection |
| High 7hhh-6rmp-j9qf / Jackson DataInput | Selected version retained; no relevant runtime input probe | Telemetry/schema DataInput parser callers, input bounds and supported fix |
| High p6pp-m3f8-5c89 / Jackson number check | Selected version retained; numeric-input path unmeasured | Caller/string bounds and supported fixed parser behavior |
| High r7wm-3cxj-wff9 / Jackson async | Selected version retained; chunk/parser path unmeasured | Async caller and chunk/number limits, including the later fix boundary |
| High qp49-qgx5-5m26 / lazy ASN.1 | Selected BC version retained; lazy forcing/nesting path unmeasured | ASN.1 decoding/trust/depth policy or supported fixed owner selection |
| High cmp6-m4wj-q63q / LZ4 reused output | Inspected IntelliJ wrapper uses fast decompressor; some output allocations visible | Actual decoder/output-buffer ownership and cache provenance; namespace/fork compatibility if replacing |
| High vqf4-7m7x-wgfc / LZ4 bounds | Java/native factory paths visible; no malformed-data probe | Actual factory/input bounds plus owner-supported fixed migration |
| Moderate c3fc-8qff-9hwx / BC LDAP | No actual LDAP query path measured | Provider/store configuration and attacker-controlled query handling or fixed selection |
| Moderate wg6q-6289-32hp / composite signatures | Library condition not exercised | Actual verifier/algorithm/signature consumers or supported fixed stack |
| Moderate xx22-p4ch-683r / LZ4 JNI XXHash | Invalid-reference/range condition not exercised | JNI caller/range provenance; a byte-only fixture would not answer it |
| Moderate rcgg-9c38-7xpx / OTel baggage | Candidate telemetry internals not scanned | Inbound extraction and header limits or supported fixed owner selection |
| Moderate j288-q9x7-2f5v / Commons Lang | Lint still selects 3.16; settings 3.18 does not replace it | Lint class-name caller/input bounds or supported lint update |
| Moderate 7r82-7xv7-xcpj / HttpClient | Lint still selects 4.5.6; settings 4.5.14 does not replace it | Lint/repository URI trust and authority validation or supported lint update |
| Moderate r937-wjx7-w2jp / KAPT | Original bounded builds observed no KAPT cache/configuration; candidate variant bytes differ | Exact candidate KAPT producer/cache conditions or replacement of AGP-selected KGP; compiler version alone is insufficient |

## Existing boundaries, assumptions and blockers

Verified repository boundaries: Mobile CI uses `pull_request`/main push/manual
events and read-only contents permission. Its build jobs cache Toolchain/Maven
and Gradle directories with hash-based keys and broader restore prefixes.
Release and nightly workflows are separate. Isolated maintenance runs use private
resources and retain producer hashes, failure logs and cleanup receipts.

These boundaries help review and recovery. They are not input sanitizers,
proof of trusted shared-cache contents, controls against all parser/crypto paths,
or a guarantee that untrusted builds lack every credential. The actual hosted
cache permissions, artifact provenance and effective generated parser/telemetry
configuration were not measured in this review. No mitigation is claimed solely
because a dependency belongs to build tooling.

`maintenance-policy.json` still blocks High/Critical adoption findings and
requires triage for unknown severity. It has no mitigation-exception mechanism.
No finding is marked not affected, remediated or accepted risk. No native/release
build was rerun for this documentation/fixture follow-up, and it supplies no
bridge-unavailable proof. Broader [adoption gates](toolchain-adoption-assessment.md)
and independent [retirement gates](bridge-retirement-path.md) remain open.

## Next small slice

Add a manual, source-bound consumer-condition observation to the existing
delegated resolution probe, starting with effective Jetifier options and
transform execution. Keep collection in the repository adapter rather than
workflow YAML. This is a proposal, not an implemented mitigation or a scheduled
watch. Preserve the current bridge and collect both settings and lint scopes.

Acceptance checks:

1. A fresh baseline/candidate pair records exact generated Jetifier option,
   source, transform task/input identities and relevant variants. Missing or
   unsupported observations produce `incomplete`, never implicit false.
2. Disabled/nonexecuted transforms can support only a bounded condition
   conclusion. If they execute, a supported parser-hardening/owner update is
   rehearsed with the same owned canary and normal POM/build fixtures. No ad hoc
   force-version rule or upstream patch is silently adopted.
3. Relevant host/native/package jobs preserve baseline behavior, compiler
   plugins, Swift adapters and original targets. All producer and observation
   bytes are bound; stale, altered or partial receipts refuse review credit.
4. Failure, timeout and missing fixture dependencies retain distinct receipts;
   private resources recover and clean up. No shared cache edits or new schedule.
5. Fresh release/advisory evidence and an explicit finding-level decision remain
   prerequisites. Jetifier closure alone does not resolve the two Critical BC
   findings, Jackson, LZ4 or the remaining owner-specific rows.

In parallel, discover supported Toolchain/AGP owner releases that actually
replace BC 1.79 and the other selected affected inputs. Rehearse changes by owner
cohort and compare exact graphs before presenting a complete adoption packet.
The tested BC 1.85 control identifies useful behavior to require; it is not yet
that packet. Waiting until 2026-10-08T06:36:56Z only closes 0.13.0's seven-day
release-age gate after a fresh check.

## Repeating the bounded fixtures

Use JDK 21 and a new owned temporary directory. Download only the seven JARs
identified in the receipt's `condition_probes.runs[*].artifacts`; join each
fingerprint to `inventory.artifacts` or `independent_controls.artifacts` for its
public URL. Verify SHA-256 and byte length before compilation/execution. The
inputs are BC 1.79/1.85, JDOM 2.0.6/2.0.6.1, Jetifier processor/core beta10 and
Kotlin stdlib 2.3.20. Use the baseline five-JAR classpath for compilation.

```sh
"$task_jdk/bin/javac" -cp "$task_baseline_classpath" -d "$task_classes" AdvisoryConditions.java
"$task_jdk/bin/java" -Xmx64m -cp "$task_classes:$task_baseline_classpath" AdvisoryConditions crypto
"$task_jdk/bin/java" -Xmx64m -cp "$task_classes:$task_bc_control_classpath" AdvisoryConditions crypto
"$task_jdk/bin/java" -Xmx64m -cp "$task_classes:$task_baseline_classpath" AdvisoryConditions xml "$task_owned_xml_directory"
"$task_jdk/bin/java" -Xmx64m -cp "$task_classes:$task_jdom_control_classpath" AdvisoryConditions xml "$task_owned_xml_directory"
```

The task-specific variables refer only to that directory and the chosen JDK;
control classpaths replace exactly one JAR. Enforce the same 30-second process
budget, record tool/source/input/output fingerprints and actual exit codes,
then remove only owned binaries/canary directories after quiescence. Retain
receipts and failed attempts. Reproduction supplies a new local fixture result,
not automatic adoption eligibility or Mobi reachability evidence.

The later [Jetifier condition assessment](jetifier-condition-assessment.md)
measures disabled effective options and no observed Jetifier actions in a fresh
retained-bridge build-input pair. It closes that bounded measurement gap only;
variant coverage, parser reachability, advisory clearance and adoption remain
separate. It also records declared upstream-owner remediation leads.
