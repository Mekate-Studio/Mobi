# Selected build-input assessment: current direct tuple

Date: 2026-10-03. Decision: **bounded build-input proof passes; advisory review
requires triage; bridge retirement remains deferred**. Production retains the
iOS Gradle builder and Kotlin 2.4.20 / Metro 1.4.5 / SKIE 0.10.15 bridge tuple.
No dependencies, target declarations, release defaults or schedules were adopted.
No commit or push is part of this assessment.

## Verified execution

The manual [direct-build-inputs profile](direct-build-input-proof.md) paired the
retained source baseline with the isolated typed-facade candidate on Toolchain
0.12.2 / effective Kotlin 2.4.10 / Metro 1.4.5. The hand-maintained iOS bridge was
unavailable in the candidate. Swift app/test targets and adapters survived the
transformation; this profile did not run Swift consumers. The earlier
[current round trip](direct-current-assessment.md) remains separate evidence.

Run `9c17d97f1070e64cbe7dad16149610da` used source snapshot
`d53589373d8177e04b93f91899162e4e146b721076388884aa5b2b38331e07ff` at
HEAD `ba8270fabed862ae52a09e918e9803390d0fd8cb`. This was a captured working
snapshot including uncommitted maintenance work, not an exact clean-commit or
hosted-CI result. Caller source bytes/modes, HEAD and index were verified unchanged
before publishing these documentation results. Both phases and the final report
passed; recovery was quiescent, cleanup completed and reporting replayed after
cleanup. See the [public receipt](evidence/2026-10-03-direct-build-inputs.json).

| Scope | Baseline | Bridge-unavailable candidate | Limit |
| --- | --- | --- | --- |
| Declared module resolution | 92 main/test compile/runtime roots, seven modules | Same coverage | Full graph-to-artifact attribution remains unproven |
| Android regressions | 38 successful tests and debug APK build | 38 successful tests and debug APK build | No release/distributable claim |
| Shared ARM compiler execution | All five shared modules compile for device and simulator KLIB targets | Same targets and modules | KLIB compilation is not device app execution or Swift test execution |
| Selected plugin inputs | 37 successful compiler invocations; two selected artifact files, byte hashes and sizes | Same counts and artifact hashes | Includes main/test/repeated Android compilations; configured Maven roots and transitive attribution remain distinct |
| Delegated Android resolution | Two generated task-project builds; 1,828 configuration entries; 136 resolved, 612 explicitly uncollected, 1,080 non-resolvable | Same counts | Reviewed debug-main/build-tool scope; inventories count entries across both generated projects |
| Selected delegated versions | Gradle 9.5.0, AGP 9.3.1, Kotlin Gradle plugin 2.2.10; 273 Maven pairs | Same | These versions come from actual delegated producers, not the iOS bridge catalog |
| Exact Maven advisory review | Identical query set to candidate | 576 unique pairs, six successful batches, 17 full finding records, no pagination or provider errors | Lookup covers named module/delegated inputs, not the entire dependency surface |

The selected plugin files are `compiler-1.4.5.jar` (5,966,028 bytes) and
`kotlin-compose-compiler-plugin-embeddable-2.4.10.jar` (949,238 bytes). Their
compiler invocation paths and content hashes are measured; these filenames do
not independently establish Maven attribution. Both phases select the same
bytes. The invocation collector covers Android, `iosArm64` and
`iosSimulatorArm64` for each reviewed shared module.

The observer classifies Toolchain's synthetic `localModule` / `unspecified`
file identifiers as opaque. The
[upstream producer](https://github.com/JetBrains/kotlin-toolchain/blob/v0.12.2/sources/android-integration/amper-android-gradle-plugin/src/org/jetbrains/amper/android/gradle/ResolvedAmperDependency.kt)
uses a Gradle module identifier for file inputs; that is not a published Maven
coordinate. No advisory queries were invented from injected cache paths.

## Findings and exposure review

The provider result is `triage_required`, with **17 matches across 10 selected
build dependencies**: two Critical, eight High and seven Moderate classifications
in the captured provider records. Severity describes the advisory, not measured
Mobi exploitability. All matches occur in delegated settings or lint-tool
resolution scopes; none matches the 305 named module pairs. Baseline and
candidate have identical exact query sets, so this review exposes existing
shared Android build-tool inputs rather than a candidate dependency regression.
It does not prove these libraries are absent from every packaged artifact or
that their vulnerable functions execute in this build.

| Selected dependency | Observed configuration owners | Primary advisory records |
| --- | --- | --- |
| `com.fasterxml.jackson.core:jackson-core` 2.21.1 | settings:classpath | [GHSA-7hhh-6rmp-j9qf](https://api.osv.dev/v1/vulns/GHSA-7hhh-6rmp-j9qf), [GHSA-p6pp-m3f8-5c89](https://api.osv.dev/v1/vulns/GHSA-p6pp-m3f8-5c89), [GHSA-r7wm-3cxj-wff9](https://api.osv.dev/v1/vulns/GHSA-r7wm-3cxj-wff9) |
| `io.opentelemetry:opentelemetry-api` 1.60.1 | settings:classpath | [GHSA-rcgg-9c38-7xpx](https://api.osv.dev/v1/vulns/GHSA-rcgg-9c38-7xpx) |
| `org.apache.commons:commons-lang3` 3.16.0 | project:androidLintTool | [GHSA-j288-q9x7-2f5v](https://api.osv.dev/v1/vulns/GHSA-j288-q9x7-2f5v) |
| `org.apache.httpcomponents:httpclient` 4.5.6 | project:androidLintTool | [GHSA-7r82-7xv7-xcpj](https://api.osv.dev/v1/vulns/GHSA-7r82-7xv7-xcpj) |
| `org.bitbucket.b_c:jose4j` 0.9.5 | settings:classpath | [GHSA-3677-xxcr-wjqv](https://api.osv.dev/v1/vulns/GHSA-3677-xxcr-wjqv) |
| `org.bouncycastle:bcpkix-jdk18on` 1.79 | project:androidLintTool, settings:classpath | [GHSA-wg6q-6289-32hp](https://api.osv.dev/v1/vulns/GHSA-wg6q-6289-32hp) |
| `org.bouncycastle:bcprov-jdk18on` 1.79 | project:androidLintTool, settings:classpath | [GHSA-574f-3g2m-x479](https://api.osv.dev/v1/vulns/GHSA-574f-3g2m-x479), [GHSA-9pwp-9qqc-pr26](https://api.osv.dev/v1/vulns/GHSA-9pwp-9qqc-pr26), [GHSA-c3fc-8qff-9hwx](https://api.osv.dev/v1/vulns/GHSA-c3fc-8qff-9hwx), [GHSA-qp49-qgx5-5m26](https://api.osv.dev/v1/vulns/GHSA-qp49-qgx5-5m26) |
| `org.jdom:jdom2` 2.0.6 | settings:classpath | [GHSA-2363-cqg2-863c](https://api.osv.dev/v1/vulns/GHSA-2363-cqg2-863c) |
| `org.jetbrains.kotlin:kotlin-gradle-plugin` 2.2.10 | settings:classpath | [GHSA-r937-wjx7-w2jp](https://api.osv.dev/v1/vulns/GHSA-r937-wjx7-w2jp) |
| `org.lz4:lz4-java` 1.8.0 | settings:classpath | [GHSA-cmp6-m4wj-q63q](https://api.osv.dev/v1/vulns/GHSA-cmp6-m4wj-q63q), [GHSA-vqf4-7m7x-wgfc](https://api.osv.dev/v1/vulns/GHSA-vqf4-7m7x-wgfc), [GHSA-xx22-p4ch-683r](https://api.osv.dev/v1/vulns/GHSA-xx22-p4ch-683r) |

The Kotlin Gradle-plugin lead is now selected-input evidence, rather than an
unverified filename observation. The
[primary record](https://api.osv.dev/v1/vulns/GHSA-r937-wjx7-w2jp) maps 2.2.10
to unsafe cache deserialization; its recorded fix boundary is 2.4.20-Beta1. The
[linked Kotlin fix](https://github.com/JetBrains/kotlin/commit/bf51df665b458fda7c3eaf436c4d88dc119d7ec6)
restricts deserialization in KAPT's incremental Java/APT cache manager.
No explicit KAPT configuration was found in the reviewed module/bridge
manifests; no KAPT compiler arguments or `java-cache.bin` / `apt-cache.bin`
files were observed in either bounded phase before cleanup. These observations
support a narrower exposure review, not a global exemption or a verified
unreachable-code proof. No malicious-cache or exploit rehearsal was performed.
All provider matches remain triage-required; no finding was waived or automatically
resolved. Updating the retained iOS bridge does not change this Toolchain-owned
Android settings classpath.

First follow-up: review owners, affected functions and input/cache trust for
these matches, prioritizing the two Critical Bouncy Castle records. Bind supported
upstream remediation options and their compatibility implications, then rehearse
an exact supported candidate before presenting an adoption decision. Changing
transitive inputs in a generated build is not assumed to be a supported upgrade.
Keep this work separate from the retained iOS bridge stack and direct retirement.

## Untested assumptions and remaining blockers

Selected compiler paths now have execution/fingerprint proof; **compiler-plugin
Maven/transitive coordinate attribution remains unsupported**. General module
artifact attribution, shaded code, Native bundle internals, non-Maven distribution
advisories and Swift/Ruby/npm surfaces remain incomplete. The 612 uncollected
configuration entries retain their explicit gap; this profile does not prove
unit/instrumentation/release variants of the synthetic delegated projects.
Android host tests are executed separately by the existing Toolchain jobs.

No lifecycle/cancellation/failure or bounded generic-export parity was added.
Swift Full test-plan/macro, device app/minimum-floor, release/archive/signing,
clean-clone onboarding and cold hosted direct operation remain independent
[retirement gates](bridge-retirement-path.md). A compatible tuple and complete
provider transport do not replace architecture review, maintainer approval,
reversible integration or a distinct bridge-deletion decision.

## Failure and validation receipts

Three earlier attempts remain failed/refused in the same owned store; none ran
the candidate. The first rejected unlocked Gradle resolution at buildFinished;
the second exposed unused synthetic test/artifact scopes; the third passed
Android and both ARM KLIB builds but refused Native's actual joined target
argument form. The collector was corrected before the successful fresh pair.
The last refusal also exposed synthetic module IDs during independent producer
replay; these are now handled by the observer as opaque files. Diagnostic replay
was not substituted for a source-bound paired pass.

Recovery and explicit discard cleanup completed for every attempt. Failed-run
command/control evidence remains; raw intermediate observer packets require
preservation before discard when the final collector has not emitted them to
control storage, as documented in the profile guide. The final passing pair's
compiler/artifact/delegated control producers remain replayable after cleanup.

Final validation passed 222 repository contracts (including eight build-input
contracts), pinned static gates, 17 strict OpenSpec items and whitespace checks.
Refusal contracts cover missing module/target/plugin scopes, joined/ambiguous
Native targets, failed compiler records, escaping artifacts, missing settings or
debug graphs, uncollected required scopes, unresolved edges, private content and
forged summaries that disagree with retained producers. Pinned primary source
URLs, hashes and capture times are retained in the public receipt.

## Next bounded proof

Close plugin-coordinate attribution before treating the compiler-plugin advisory
scope as covered. Prefer an authoritative Toolchain resolution export. If the
reviewed release cannot emit it, rehearse the configured plugin roots in an
independent, owned resolver and join selected component/variant identities to
the actual compiler plugin fingerprints. Require every selected plugin file to
have an unambiguous coordinate/version match; refuse missing, differing or
ambiguous hashes. Preserve plugin transitive exclusions and shaded-code limits.
An independently green resolver is insufficient unless its artifacts match the
compiler's measured inputs. This is assessment infrastructure and does not
reintroduce a production iOS bridge or authorize changing defaults.

Acceptance: baseline/candidate source bindings verify; all measured plugin
paths have complete, unique fingerprint-backed attribution; no coordinates come
from cache filenames; fresh exact-input advisory receipts include the attributed
inputs; unresolved findings remain review gates; source/index/HEAD preservation,
recovery and cleanup pass. Continue lifecycle/generic/native/release/onboarding
and cold hosted proof on their independent tracks.

Follow-up: the [compiler attribution assessment](compiler-plugin-assessment.md)
now closes coordinate attribution for these measured files. The
[advisory triage](direct-advisory-triage.md) records owner chains, affected
conditions and remediation boundaries; all 17 findings remain open. The limits
above describe this original build-input run and are not retroactively removed.
