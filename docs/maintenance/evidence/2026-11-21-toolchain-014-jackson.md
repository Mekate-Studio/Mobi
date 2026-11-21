# Toolchain 0.14.0 Jackson exposure review — 2026-11-21

**Decision: retain the package findings and defer adoption under the current
policy.** The inspected telemetry path selects Kotlin serialization. This review
does not demonstrate Jackson exploitation in Mobi, establish universal
unreachability, accept risk or change the selected 0.13.0 wrapper.

The [dependency assessment](2026-11-18-toolchain-014-dependencies.md) identified
the regression. [PR #121's hosted qualification](2026-11-20-toolchain-014-hosted.md)
subsequently passed the scoped native checks. This increment traces the Jackson
owner and advisory prerequisites; it adds no runtime flag, dependency override,
build adapter or maintained test runner.

## Delivered owner and entry point

The independently re-downloaded 0.14.0 archive still matches its reviewed
420,236,123 bytes and SHA-256. All **375 launcher JARs** match the previous
file inventory. The launcher changes from Core 2.21.1 alone to Core, Databind,
Annotations and Kotlin Module 2.13.5. These are launcher dependencies; this is
not evidence that the vulnerable paths are packaged into the mobile app.

The tagged source's [analytics module](https://github.com/JetBrains/kotlin-toolchain/blob/95a158010b0afe7cda88251a9f1357dbeb731fac/sources/analytics/amper-fus-analytics/module.yaml)
selects `jetbrains.fus.validation`, which the
[catalog](https://github.com/JetBrains/kotlin-toolchain/blob/95a158010b0afe7cda88251a9f1357dbeb731fac/libs.versions.toml)
maps to `com.jetbrains.fus.reporting:ap-validation-all:2.0.253`.
Its publisher's [POM](https://packages.jetbrains.team/maven/p/apl/product-analytics-platform-public/com/jetbrains/fus/reporting/ap-validation-all/2.0.253/ap-validation-all-2.0.253.pom)
and Gradle module metadata declare runtime `serialization-jackson:2.0.253`.
That component's [POM](https://packages.jetbrains.team/maven/p/apl/product-analytics-platform-public/com/jetbrains/fus/reporting/serialization-jackson/2.0.253/serialization-jackson-2.0.253.pom)
declares Databind and Kotlin Module 2.13.5; the latter dependencies bring the
remaining Jackson files. This explains their presence without inferring usage.

Nine freshly downloaded FUS binaries match the captured distribution files by
whole-file SHA-256 and length. Their published source JARs support the path
review; this is source correspondence, not reproducible-build attestation.
The [actual Toolchain component setup](https://github.com/JetBrains/kotlin-toolchain/blob/95a158010b0afe7cda88251a9f1357dbeb731fac/sources/analytics/amper-fus-analytics/src/org/jetbrains/amper/fus/client/createFusClient.kt#L139)
supplies `jsonSerializer { FusKotlinSerializer() }`. Disassembling the delivered
`amper-fus-analytics-jvm.jar` confirms the constructor and provider registration.
The FUS builder passes that supplied serializer to remote configuration,
metadata storage and dispatch; it has no default Jackson serializer provider.

## Static boundary and advisory conditions

The scan enumerated **74,775 class entries** across all launcher JARs and parsed
the constants of **73,782 entries outside Jackson's four JARs**. Only
`FusJacksonSerializer` and `CustomPrettyPrinter`,
both in `serialization-jackson`, contain Jackson class references. No other
launcher class constant refers to `FusJacksonSerializer`. This is a bounded
class-constant observation, not a dynamic call graph or proof against reflection.
Three Jackson service-provider entries remain packaged. Delegated Gradle/plugin
processes, project-loaded code, shaded/dynamic code and mobile delivery are
outside this scan's exclusion claim.

The unused-in-this-path Jackson serializer has a `fromJson(String, KClass)`
method calling `readValue(String, Class)` and writes with `writeValueAsString`.
Its inspected mapper setup does not enable default typing or the features in
the table below. These observations narrow the named consumer; they do not
dispose of package-level findings for every possible launcher consumer.

Five fresh OSV package/version queries completed with all matching records:

| Delivered package | Version / phase | Matches, using OSV severity |
| --- | --- | --- |
| Jackson Core | 2.21.1 / baseline | 3 High |
| Jackson Core | 2.13.5 / candidate | 3 High |
| Jackson Databind | 2.13.5 / candidate | 4 High, 7 Moderate |
| Jackson Annotations / Kotlin Module | 2.13.5 / candidate | 0 each in this lookup |

The **17 package/version/advisory matches, 15 distinct IDs and record contents**
are semantically unchanged from the November 18 capture. Zero matches for the
two supporting artifacts do not clear their transitive dependencies. Core's
unchanged count exchanges the baseline-only number-regex finding
([p6pp](https://github.com/FasterXML/jackson-core/security/advisories/GHSA-p6pp-m3f8-5c89))
for the older core's nesting finding; counts are not an aggregate risk score.

| Candidate findings | Required behavior and inspected consumer |
| --- | --- |
| Core [h46c](https://github.com/FasterXML/jackson-core/security/advisories/GHSA-h46c-h94j-95f3), High | Deep JSON parsing without the later depth constraint. The selected telemetry serializer is Kotlin; the packaged Jackson String parser remains an unremediated capability if selected elsewhere. |
| Core [7hhh](https://github.com/FasterXML/jackson-core/security/advisories/GHSA-7hhh-6rmp-j9qf), High; [r7wm](https://github.com/FasterXML/jackson-core/security/advisories/GHSA-r7wm-3cxj-wff9), OSV High | DataInput invalid-token handling / chunked nonblocking number parsing. The inspected Jackson adapter uses a blocking String entry point, and is not the selected telemetry serializer. |
| Databind [cxp5](https://github.com/FasterXML/jackson-databind/security/advisories/GHSA-cxp5-3px4-pw24), [j3rv](https://github.com/FasterXML/jackson-databind/security/advisories/GHSA-j3rv-43j4-c7qm), [rmj7](https://github.com/FasterXML/jackson-databind/security/advisories/GHSA-rmj7-2vxq-3g9f), [wv8q](https://github.com/FasterXML/jackson-databind/security/advisories/GHSA-wv8q-qhhj-9h54), High | Respectively identity-enabled forward references, generic polymorphic type IDs, array subtype allowlisting, and name-based polymorphism with fallback. Those configurations were not found in the inspected serializer/model sources or Jackson references in model bytecode. |
| Databind [3wrr](https://github.com/FasterXML/jackson-databind/security/advisories/GHSA-3wrr-7qpf-2prh), [5gvw](https://github.com/FasterXML/jackson-databind/security/advisories/GHSA-5gvw-p9qm-jgwh), [5jmj](https://github.com/FasterXML/jackson-databind/security/advisories/GHSA-5jmj-h7xm-6q6v), [gx83](https://github.com/FasterXML/jackson-databind/security/advisories/GHSA-gx83-3vf8-gh7j), Moderate | Respectively JsonNode-toString recursion, view/unwrapped handling, ignored properties with case-insensitive binding, and Comparable polymorphic validation. These prerequisites were not found in the inspected consumer. |
| Databind [hgj6](https://github.com/FasterXML/jackson-databind/security/advisories/GHSA-hgj6-7826-r7m5), [vvgp](https://github.com/FasterXML/jackson-databind/security/advisories/GHSA-vvgp-rfg2-7rr6), [wjgm](https://github.com/FasterXML/jackson-databind/security/advisories/GHSA-wjgm-6hv5-3cvf), Moderate | Binding network-address or Path types from untrusted JSON, with additional provider conditions for Path side effects. No Jackson binding to these types was established in the named telemetry path. |

The publisher labels r7wm Moderate while the OSV record labels it High. Preserve
both observations; the table follows the existing assessment's OSV convention.
All candidate matches remain open. No exploit payload or application code ran.

## Options and next review

Prefer an owner-delivered dependency change: remove the unused Jackson runtime
edge from the FUS umbrella/Toolchain composition, or publish an aligned patched
Jackson cohort. Neither fix is qualified here. Updating only Core to the old
baseline leaves that version's three matches and does not repair Databind.
Mobi module dependency exclusions do not replace the CLI's own `lib/*` files.
Deleting/replacing those files locally would create a new maintained launcher
fork; this review proposes no such workaround.

Telemetry consent is not a verified security control: Toolchain's
[consent-reporting path](https://github.com/JetBrains/kotlin-toolchain/blob/95a158010b0afe7cda88251a9f1357dbeb731fac/sources/amper-cli/src/org/jetbrains/amper/cli/analytics/CliFusReporter.kt)
can create a temporary client to report rejection. Disabling sends also leaves
metadata/client work. The upstream full-disable flag is a distinct path, but
Mobi does not enforce it and no mitigation is accepted for it. Since the named
consumer already selects Kotlin serialization, adding a flag would not itself
repair the packaged Jackson files or prove every reflective path excluded.

The fresh five-release response also observes
[Toolchain 0.14.1](https://github.com/JetBrains/kotlin-toolchain/releases/tag/v0.14.1),
published **2026-11-19T17:46:59Z**, whose notes identify a CLI JRE fix for
CVE-2026-114938 and warn about previously cached provisioned JDKs. Its source
catalog still names FUS 2.0.253; this is not a binary Jackson assessment of
0.14.1. Review that security release before proposing 0.14.0 adoption. The
November 18 qualification exception does not transfer to 0.14.1; its ordinary
seven-day date is **2026-11-26T17:46:59Z**. No wrapper or cache is changed here.

On each Toolchain/FUS owner update, recheck the published dependency edge,
actual distribution identities, serializer selection and all retained advisory
conditions. A source declaration or JRE-only release does not demonstrate a
Jackson fix. Keep non-Jackson findings, attribution gaps and the Gradle 9.8
observer limitation separate and open.

## Evidence and limits

The [compact receipt](2026-11-21-toolchain-014-jackson.json) binds the source,
archive, provider responses, selected FUS binaries and static observations.
Raw archives, source JARs, constant rows and provider bodies remain in ignored
local evidence storage. No bulk inventory or maintained replay tool is added.
The inspection used class-file constants and `javap -c -p`; it did not initialize
Toolchain/FUS classes, run a mobile test, contact telemetry servers or alter
consent. Existing native qualification remains its own evidence, not a security
acceptance. High/Critical policy, release age, signed-delivery holds and IOS-10
retirement checks remain unchanged.
