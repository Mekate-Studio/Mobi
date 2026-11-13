# Robolectric-owned Bouncy Castle update — 2026-11-13

This candidate changes the Android test dependency from Robolectric 4.16 to
stable 4.17. The actual public graph selects Bouncy Castle 1.85 through the
owner's published BOM, replacing 1.81 without a transitive override. Fresh exact
package/version queries drop all five Bouncy Castle matches, including the two
Critical findings recorded in PR #102. Three other matches remain. This is a
bounded component remediation, not application-wide security clearance.

## Actual change and review cost

Base: `dd30d637cd32c3375f9345fbe46eb9df9c5829e7`, merged PR #102. One dependency
pin changes. One documented test-JVM option is added:
`--add-opens=java.base/jdk.internal.access=ALL-UNNAMED`. The existing native-access
option remains. Effective settings put the new option only in the Android
module's JVM test configuration.

The unchanged baseline passed all 94 Android/shared tests. The first 4.17 trial
resolved Bouncy Castle 1.85 but failed 54 of the 68 Android-module tests before
feature code: Robolectric's FileDescriptor interceptor could not access
`jdk.internal.access.SharedSecrets`. The remaining 14 Android-module tests
passed. That failed run is retained; it is not a successful candidate result.
After adding the package-access option, the same 68 Android tests and 26 shared
tests pass with no failures or skips. No test body or assertion changes.

Robolectric's [official Java 17+ setup](https://robolectric.org/getting-started/#running-with-java-17-and-higher)
documents package opening for JDK internals. Mobi selects the one observed
requirement for its current JDK 25 / API 36 suites. This is a runner/JDK
accommodation under AND-01,
not a Toolchain bridge, new test target or resource-class adapter. Recheck on
Robolectric/JDK updates by omitting this option, keeping the actual suites and
assertions. Remove it when the updated runner no longer needs the package access
and the omission run plus normal gates pass. Whole-harness removal stays separate.

Robolectric 4.17 also changes Conscrypt, Guava, ASM, ICU, SnakeYAML and other owned
test transitives; the paired JSON lists the complete observed package/version-set
delta. Conscrypt becomes 2.6.2 and Guava becomes 33.6.0-jre. All nine runner suites
still explicitly use API 36. The app's compile/target/min SDK and Kotlin, Metro,
coroutines, exporter, native code and producer settings are unchanged. No new
runner machinery or Shared Home rendering test from draft PR #99 is adopted;
that deferred resource-test gap is not qualified by this update.

## Source and affected-operation review

The official [4.17 release](https://github.com/robolectric/robolectric/releases/tag/robolectric-4.17)
was published September 10, 2026 at 21:00:44 UTC and exceeds the unchanged
seven-day threshold. No additional age waiver is used. Annotated tag
`f3733ba3c8c3744cae83bd59e37c7433c996b7de` identifies commit
`0706415db828e1bdcf4f0c820784fa760d0185a2`.
The [versioned catalog](https://github.com/robolectric/robolectric/blob/0706415db828e1bdcf4f0c820784fa760d0185a2/gradle/libs.versions.toml)
sets Bouncy Castle 1.85; the
[owner declaration](https://github.com/robolectric/robolectric/blob/0706415db828e1bdcf4f0c820784fa760d0185a2/robolectric/build.gradle.kts)
exports the platform BOM and provider. The actual Mobi selection, not an
intermediate changelog entry, establishes the delivered versions.

The [owner's test environment](https://github.com/robolectric/robolectric/blob/0706415db828e1bdcf4f0c820784fa760d0185a2/robolectric/src/main/java/org/robolectric/android/internal/AndroidTestEnvironment.java)
registers a Bouncy Castle security provider during setup. Therefore this is an
available test-runtime component, not merely an unused catalog declaration.
A bounded search of the Mobi Android/shared test sources found no direct Bouncy
Castle, JCE encryption, certificate validation or keystore calls. It does not
exclude reflective, framework or future calls and is not an unreachability proof.

The Critical GOST issue concerns counter wrap and observable ciphertext under
relevant key/IV conditions; the [upstream fix](https://github.com/bcgit/bc-java/commit/b42574345414e4b7c8051b16fa1fafe01c29871f)
changes counter propagation. The Critical name-constraint issue requires BC
certificate-path validation with relevant constrained names and attacker-controlled
certificate input; the [vendor advisory](https://github.com/bcgit/bc-java/wiki/CVE%E2%80%902026%E2%80%908763)
and [fix](https://github.com/bcgit/bc-java/commit/2c28b253a44681fbbc562561eab6ad383d2ae558)
identify 1.85 as patched for this artifact. No exploitability or harmlessness
claim is made about the original tests.

The resolved 1.81 and 1.85 JARs have retained SHA-256 identities and verified
published checksums. JDK 25 multi-release-aware disassembly of those actual
bytes shows the old single-byte counter increment replaced by carry propagation
and overflow handling. The candidate also has trailing-dot normalization calls
in the email and URI constraint paths, absent from those baseline paths. This
supports the two Critical fix identities; it is static byte inspection, not an
adversarial Mobi execution or a complete cryptographic audit.

## Fresh graph and advisory evidence

Both phases cover nine declared modules and 104 public main/test compile/runtime
roots, including their declared platforms. Only Android test compile/runtime
roots differ; the other 102 public graphs are identical. The baseline has 357
named Maven package/version queries; the candidate has 358, including the new BOM.
Each lookup uses four HTTP-200 batches with exact result cardinality and no
pagination, followed by all full finding records (eight baseline, three candidate).
The existing repo-owned parser and OSV transport are reused; no new maintained
collector, private metadata adapter or risk-acceptance flag is added.

| Bouncy Castle match on 1.81 | Captured severity | Candidate 1.85 lookup |
| --- | --- | --- |
| [GHSA-574f-3g2m-x479](https://osv.dev/vulnerability/GHSA-574f-3g2m-x479) | Critical | No match |
| [GHSA-9pwp-9qqc-pr26](https://osv.dev/vulnerability/GHSA-9pwp-9qqc-pr26) | Critical | No match |
| [GHSA-c3fc-8qff-9hwx](https://osv.dev/vulnerability/GHSA-c3fc-8qff-9hwx) | Moderate | No match |
| [GHSA-p93r-85wp-75v3](https://osv.dev/vulnerability/GHSA-p93r-85wp-75v3) | High | No match |
| [GHSA-qp49-qgx5-5m26](https://osv.dev/vulnerability/GHSA-qp49-qgx5-5m26) | High | No match |

Remaining: Guava **33.6.0-jre** still matches High
[GHSA-xxph-c9ww-hj94](https://osv.dev/vulnerability/GHSA-xxph-c9ww-hj94) in Android
tests; its version increase is not remediation. The exporter's JVM graph retains
OpenTelemetry API **1.41.0** and Moderate
[GHSA-ccrj-gw8r-854m](https://osv.dev/vulnerability/GHSA-ccrj-gw8r-854m) /
[GHSA-rcgg-9c38-7xpx](https://osv.dev/vulnerability/GHSA-rcgg-9c38-7xpx).

Scope limits remain: shaded code, Native internals, complete compiler-plugin and
delegated Android tooling attribution, Swift/Ruby/npm and Robolectric's dynamic
instrumented-Android runtime downloads are not cleared. Public test-root scope
is not APK absence proof. This result does not rebind historical build-tool risk
receipts or clear their separate findings. The
[paired summary](2026-11-13-robolectric-bc-review.json) records exact query hashes,
changes, artifact identities, counts and raw receipt hashes within this scope.

## Validation and recovery

The paired Android/shared tests pass on the installed JDK 25 and Android SDK.
The complete repository contract suite passes under pinned Ruby 4.0.6.
Downloads were privately seeded; baseline application outputs were not imported.
Candidate tests reused this checkout's baseline build cache, so this comparison
is not a cold clean-clone or controlled performance measurement. Warning debt is
retained. Final exact-staged source-copy and hosted gates are recorded in the PR;
unsigned/signed release and device acceptance are separate scopes.

The normal exact-staged gate for code commit
`0a9058de143e7110a1d402c2a952477af95cfb67` passes static checks, 94 Android/shared
tests, 79 native functions / 173 executions, both Debug builds and source/index/
owned-cleanup checks. The retained native result has no failures or skips. This
source-copy gate starts without this checkout's application outputs. The later
documentation-only receipt update runs the normal static/source gate separately;
final hosted results remain in the PR.

Recovery restores the complete pre-update source, including the dependency pin,
JVM option and linked guidance. On later owner updates, refresh actual selected
versions and advisories, run the option-omission control, compare graph scope and
run normal gates. No security acceptance or automatic upgrade follows from a
successful lookup.
