# Toolchain 0.14.1 published dependency owners — 2026-11-21

**Findings retained; adoption remains unqualified.** This follows merged
[#126](https://github.com/Mekate-Studio/Mobi/pull/126), source
`f3dfd9bcbee05fc0b81bc3a8371e6de9b0058b6e`. The app stays on 0.13.0.
The [compact receipt](2026-11-21-toolchain-0141-dependencies.json) binds the
archive, retained references, provider records and selected artifact identities.
Full inventories, source bodies, bytecode comparisons and provider packets stay
in ignored local evidence storage; no build adapter or replay runner is added.

## Actual files and attribution

The independently downloaded 0.14.1 distribution is **420,237,101 bytes**, SHA-256
`39fb5f7e0bd5148a02f5519e88d78752fb04e719ddb086258ff57e94d83c0fcb`, matching the
reviewed wrapper pin. Archive entries were streamed for inspection; selected
telemetry JARs were copied for disassembly. No Toolchain code was executed.
The 0.13.0/0.14.0 inventory and attribution files were verified
against their [published receipt](2026-11-18-toolchain-014-dependencies.json).
These are retained reference captures, not newly executed baselines.

All **632 JAR paths** match 0.14.0: **620 files are byte-identical**, and 12
Toolchain-owned files changed. All **478 Maven-attributed entries** retain their
whole-file hashes and lengths. The single ambiguous Maven entry also retains its
bytes; both possible versions remain queried. Historical attribution is reused
only on that exact identity, not from filenames, a source catalog or a presumed
dependency upgrade. Uniqueness remains relative to the reviewed references.

The Android integration's published classpath index is unchanged: 215 files,
of which 211 are byte-identical and four Toolchain-owned files changed. Updated
source-module correspondence checks use the tagged project/module declarations
and embedded Kotlin metadata; they do not establish reproducible binary
attestation or invent Maven coordinates. The launcher retains 84 unassigned
JARs and one ambiguous entry; other extras retain 24 unassigned JARs.

This measures the **published integration files**, not a new delegated build,
selected variant or loaded classpath. The earlier 0.14.0 build observation and
Gradle 9.8 transform-observer limitation remain version-bound. No transform-free
or Jetifier-mitigation conclusion follows for 0.14.1.

## Fresh advisories, with explicit scope

The lookup combines these attributed distribution identities with the actual
0.13.0/0.14.1 module queries retained by
[#126's input qualification](2026-11-21-toolchain-0141-inputs.md). It freshly
queries **768 package/version pairs**: eight complete HTTP 200 batches, 768
response rows, no pagination, and all **73 distinct matching records** fetched
in full. It retains **83 package/version/advisory matches**. The receipt records
retrieval times and response hashes. Findings and record contents are unchanged
for the refreshed query set compared with the November 18 capture.

| Measured owner | 0.13.0 queries / matches | 0.14.1 queries / matches |
| --- | --- | --- |
| Launcher, uniquely attributed among reviewed references | 265 / 56 | 268 / 64 |
| Published Android integration classpath | 192 / 23 | 192 / 19 |
| Public module graphs from #126, including exporter tooling | 359 / 2 | 359 / 2 |
| Other attributed extras | 24 / 0 | 18 / 0 |
| Ambiguous launcher byte versions, queried conservatively | 2 / 0 | 2 / 0 |

Owner counts overlap and must not be added. The candidate's launcher and
integration counts match the earlier 0.14.0 assessment; the JRE security release
does not repair these files. The launcher retains one Critical advisory ID in
OSV's captured severity field; the integration retains two. The earlier
assessment's severity discrepancies and package-specific prerequisites remain.
These are package matches, not proof of exploitability in Mobi or its mobile app.

The older lookup had 804 queries. This refresh excludes its **36 delegated-graph-only
queries**, because no new delegated graph was captured. The older Guava
33.4.0-jre, Commons Lang 3.16.0 and HttpClient 4.5.6 findings in that scope remain
open; the lower total is not remediation. The compact receipt names their IDs.
Unassigned files, shaded code, Native internals and other package ecosystems
remain uncovered.

## Jackson consumer and remaining decision

The launcher retains Jackson Core/Databind/Annotations/Kotlin Module 2.13.5 and
the reviewed FUS Maven bytes. Its Toolchain telemetry setup JAR changed, so the
earlier [consumer review](2026-11-21-toolchain-014-jackson.md) was not carried
forward solely from its filename. Both checksum-verified archives were compared
at the uncompressed entry level for the 12 changed JARs. Disassembling the actual
`CreateFusClientKt` class with `javap -c -p -constants -s` shows only its product
version string changing from 0.14.0 to 0.14.1; it still constructs
`FusKotlinSerializer` and registers its provider. The
[tagged source](https://github.com/JetBrains/kotlin-toolchain/blob/f53674bce744f0b5e9ff235110dcc1d565d2c114/sources/analytics/amper-fus-analytics/src/org/jetbrains/amper/fus/client/createFusClient.kt)
agrees. This rechecks the named static consumer; it does not repeat the complete
launcher constant scan, prove reflective unreachability or accept Jackson risk.

The [upstream release](https://github.com/JetBrains/kotlin-toolchain/releases/tag/v0.14.1)
fixes the managed CLI JRE. Keep that runtime decision separate from these
unchanged Maven files, compiler/project JDK selection and retained-cache
migration. High/Critical policy and normal release-age eligibility remain;
inspection grants no adoption, dependency override or risk acceptance.
The owned downloaded archive and selected disassembly JAR copies were removed
after inspection; inventories, identities, disassembly and provider evidence
were retained. The earlier archive used as a reference was left intact.

Before an adoption proposal, complete a fresh 0.14.1 delegated-owner observation
and review its findings/visibility gaps, retained project-JDK cache migration,
version-bound Release/resource/relocated delivery and the dependency-risk
decision. Device/signed delivery and active interop retirement checks remain
separate. This documentation-only increment uses the normal staged gate and
required hosted selection; their results are recorded in the final PR comment.
