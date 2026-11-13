# Robolectric 4.18 qualification — 2026-11-13

Robolectric 4.18 delivers patched Guava through the Android test owner's normal
dependencies and lets Mobi delete the JDK package opening added for 4.17. The
actual Android/shared suites pass unchanged. Qualification is prepared for
review; **the release-age waiver and adoption remain unapproved**. Normal local
and hosted gates are recorded in the PR before requesting that decision.

## Change and waiver boundary

Base: `13284496abd4ce3933ba7f40f033f83e1b8b6eac`, merged PR #103. The only
executable change updates `android-app/module.yaml` from 4.17 to 4.18 and removes
`--add-opens=java.base/jdk.internal.access=ALL-UNNAMED`. The existing
`--enable-native-access=ALL-UNNAMED` remains. No application behavior, test bodies,
assertions, runner/SDK annotations, compiler/exporter or iOS producer changes.
No transitive override, new runner or build integration is introduced.

The official stable [4.18 release](https://github.com/robolectric/robolectric/releases/tag/robolectric-4.18)
was published **2026-11-13 at 18:14:14 UTC**. The unchanged seven-day policy makes
it ordinarily eligible **2026-11-20 at 18:14:14 UTC**. The maintainer authorized
early qualification, reserving waiver approval until its results are reviewable.
This receipt records **pending / not approved** at qualification; any subsequent
version-specific decision belongs in the PR discussion. It does not alter the
global minimum age, approve automatic adoption, waive other checks or accept
remaining security findings. The existing Kotlin RC waiver is separate.

Annotated tag `6e80e8b6b3a64313593c59575ba16060a81713d9` identifies source commit
`276b95bb8d65f5258781eb9e746a5c754b515c17`. The
[versioned catalog](https://github.com/robolectric/robolectric/blob/276b95bb8d65f5258781eb9e746a5c754b515c17/gradle/libs.versions.toml)
requests Guava 33.7.2-jre, Bouncy Castle BOM 1.86.2 and Conscrypt 2.8.0.
The actual graph selects **bcprov 1.86**, not the BOM's version. Other owner
transitives also change; the paired JSON lists the complete observed delta.

## Guava: actual variant and fix

Toolchain's public graph labels Guava **33.6.0-jre → 33.7.2-jre**. Its published
Gradle module metadata selects the Android variants and their
**33.6.0-android → 33.7.2-android JARs**. The candidate's existing test dependency
record confirms the Android JAR on both compile and runtime classpaths. This is
one-time evidence inspection, not a new maintained reader of private records.
Both JARs match their Maven Central published SHA-256 checksums.

Fresh exact queries for both reported coordinates and both actual Android
artifact versions match [GHSA-xxph-c9ww-hj94](https://osv.dev/vulnerability/GHSA-xxph-c9ww-hj94)
on the baseline and return no match on the candidate. The reviewed database
classifies it **High**; the [vendor advisory](https://github.com/google/guava/security/advisories/GHSA-xxph-c9ww-hj94)
currently classifies it **Moderate**. Those are distinct source assessments.
The issue concerns excessive allocation from attacker-controlled serialized
collection sizes. This review does not establish Mobi reachability or run a
memory-exhaustion exploit.

The [upstream fix](https://github.com/google/guava/commit/b931fe9d6d5cf00bc55714ad3308d086f71850fe)
bounds initial allocation at 256 in `CompactHashMap.readObject`,
`CompactHashSet.readObject` and
`MapMakerInternalMap.AbstractSerializationProxy.readMapMaker`.
JDK 25 disassembly of the actual selected candidate Android JAR shows the
`min(size, 256)` calls in all three paths; the baseline lacks those bounds.
This supports artifact fix identity, not a complete library security audit.

## AND-01: one accommodation removed, one retained

All controls use the same installed JDK 25.0.4.1 and the unchanged 68 Android
tests at API 36. Failed controls fail in runner setup before feature code.

| Runner / control | Passed / failed | Evidence |
| --- | --- | --- |
| 4.17, native access retained, JDK opening omitted | 14 / 54 | `IllegalAccessException` for `jdk.internal.access.SharedSecrets` in FileDescriptor setup |
| 4.18, native access retained, JDK opening omitted | 68 / 0 | Updated shared-memory setup succeeds |
| 4.18, JDK opening absent, native access omitted, `--illegal-native-access=deny` | 14 / 54 | `IllegalCallerException: Illegal native access from an unnamed module` during native runtime loading |
| 4.18, JDK opening absent, native access retained, same deny control | 68 / 0 | Native runtime loads with explicit permission |

The new upstream [shared-memory shadow](https://github.com/robolectric/robolectric/blob/276b95bb8d65f5258781eb9e746a5c754b515c17/shadows/framework/src/main/java/org/robolectric/shadows/ShadowApplicationSharedMemory.java)
implements `create()` without the FileDescriptor setup that previously crossed
the JDK boundary. The interceptor still contains that access for other uses;
removal is qualified for Mobi's current suites. Mobi adds no replacement helper.

Upstream [PR #11482](https://github.com/robolectric/robolectric/pull/11482) adds
native-access permission to Robolectric's own tests and improves its loader
diagnostic. It explicitly says a library cannot self-grant this permission.
Therefore its release note does not retire consumers' native-access option.
The strict deny flag is only a control and is absent from final configuration.
[AND-01](../mobile-feature-follow-ups.md#and-01-presenter-host-test-harness-simplification)
keeps this remaining grant's removal check and whole-harness retirement separate.
Failed-run counts exclude the failure collector's appended historical logs.

## Graph scope and remaining findings

Both phases capture nine declared modules and all **104** public main/test
compile/runtime roots. Only Android test compile/runtime roots change; the other
102 are identical. The public graph produces **358 → 359** exact Maven queries,
each phase in four complete HTTP-200 batches without pagination. All three
baseline and both candidate finding records were fetched. The two additional
Android-variant queries are separate, not extra public roots or distinct findings.

The candidate retains only the captured exporter JVM graph's OpenTelemetry API
**1.41.0** matches, both **Moderate**:
[GHSA-ccrj-gw8r-854m](https://osv.dev/vulnerability/GHSA-ccrj-gw8r-854m) and
[GHSA-rcgg-9c38-7xpx](https://osv.dev/vulnerability/GHSA-rcgg-9c38-7xpx).
No new finding ID appears in this bounded lookup.

This does not clear shaded/native internals, complete compiler-plugin/delegated
Android tooling graphs, Swift/Ruby/npm or dynamic Robolectric instrumented-SDK
downloads. Test-root scope is not APK absence or exploitability proof. Historical
build-tool risk receipts and their separate findings are not rebound or cleared.

Robolectric's new API 36+ native resource mode is a later AND-03 evaluation lead.
This slice does not render Shared Home, prove delivery of missing dependency
resource classes, or adopt draft #99's deferred machinery.

## Validation and recovery

Unchanged 4.17 baseline: **94 Android/shared tests pass**. Initial 4.18 with both
old options: **94 pass**. Final 4.18 with just native access: **94 pass**, no
failures or skips. The repository contract suite, exact-staged source-copy gate
and hosted checks are reported separately in the PR. Warning debt remains.
Downloads were privately seeded; baseline app outputs were not imported.
Candidate iterations reused local outputs, so these runs are neither a fully
cold clean-clone claim nor a controlled performance comparison.

The [paired summary](2026-11-13-robolectric-418-qualification.json) records source,
query and artifact identities, full observed graph delta, control counts and raw
receipt hashes. Approval and final gate outcomes remain explicit PR decisions.
Recovery restores the complete prior source, including 4.17, its package opening
and linked guidance. Later runner/JDK updates must recheck actual variants,
advisories and AND-01 omission controls before the normal gates.
