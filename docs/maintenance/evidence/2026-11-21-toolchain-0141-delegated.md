# Toolchain 0.14.1 observed delegated Android owners — 2026-11-21

**Build and scoped graph checks passed; findings and transform visibility remain
open.** This follows merged [#127](https://github.com/Mekate-Studio/Mobi/pull/127),
source `807f1a71fca02a804d744f9a52fb8e144ea9f51f`. The app stays on 0.13.0.
The [compact receipt](2026-11-21-toolchain-0141-delegated.json) binds the actual
run, source/implementation identities, provider records and owned cleanup.

## Actual comparison and cost

Run `e93423fbc43c6fd1ed264adad95e637f` used the existing baseline-first executor,
delegated Gradle collector, graph validator, source guards and resource handlers.
The 0.13.0 baseline passed before the 0.14.1 candidate was allocated. Only the
candidate's reviewed wrapper pair changed; Kotlin/exporter 2.5.0-RC, Metro
1.5.0, app sources, platform floors and native packages stayed fixed.
This uses the existing [0.14.1-only qualification exception](2026-11-21-toolchain-0141-qualification.md).
Selection remains `experimental`, `age_blocked`, and `adoption_authorized: false`;
normal eligibility remains November 26 at 17:46:59 UTC.

Each phase used separate owned SDK/home/cache directories, seeded from the
existing accepted SDK installation. Both used explicit `JAVA_HOME`; its VM
probe reported Temurin `25.0.5.1+2-LTS`. This is not an older project-provisioning
cache migration check or proof that every independently selected JVM is patched.
One-off ignored orchestration reused the earlier collector recipe. No maintained
adapter, build project, dependency override or observer accommodation is added.

| Actual check | 0.13.0 baseline | 0.14.1 candidate |
| --- | --- | --- |
| JVM/version/settings/dependencies/Android Debug commands | All exit 0 | All exit 0 |
| Effective public module scope | Nine modules, 104 roots, 359 Maven queries | Same counts |
| Declared module/target/main/test/compile/runtime input replay | Passed | Passed |
| Delegated Gradle / observed AGP | 9.5.0 / 9.3.1 | 9.8.0 / 9.3.1 |
| Delegated captures / total configuration rows | Two / 1,828 | Two / 1,828 |
| Resolved / outside Debug-main scope / non-resolvable rows | 136 / 612 / 1,080 | Same counts |
| Observed settings classpath files | 215 | 215 |
| Exact published integration set match, SHA-256 and length | Passed | Passed |
| Named delegated Maven package/version pairs | 83 | Same 83 queries |

The archive inventories were verified against the earlier
[published-owner receipts](2026-11-21-toolchain-0141-dependencies.md). Matching
their complete integration sets now binds the **observed settings classpaths**,
rather than merely showing that files were published. Retained Maven/source
attribution keeps its original byte-reference and correspondence limits.
Equal query sets/counts do not establish identical graphs, binaries or runtime
behavior. Full graph/variant/artifact captures and command logs remain ignored.

## Transform visibility stays incomplete

Actual AGP project options report Jetifier **disabled** in all 12 observations
per phase. The unchanged transform observer reports `observed` for Gradle 9.5.0
but **`incomplete / unsupported_gradle_api`** for both Gradle 9.8.0 captures.
Its zero candidate counters are not a no-transform observation. No transform-
based mitigation or observer compatibility is inferred from the successful build.

Keep this gap explicit. On Gradle/Toolchain updates, evaluate supported transform
instrumentation and qualify its planned/identified/executed-event coverage before
replacing or retiring the current mechanism. An additional private API adapter
would require its own bounded design/cost/removal review; this increment adds none.

## Fresh advisories for the observed graph

One fresh OSV lookup covers the identical baseline/candidate sets: **83 queries**,
one complete HTTP 200 batch, 83 response rows, no pagination and all **nine full
matching records**. Retrieval was **2026-11-21T19:56:05Z–19:56:09Z**.
It is one shared provider observation. The nine package/version/advisory matches
remain **two Critical, three High and four Moderate** using captured OSV severity.

The two Critical Bouncy Castle 1.79 findings remain
[GOST counter reuse](https://github.com/advisories/GHSA-574f-3g2m-x479) and
[Name Constraints bypass](https://github.com/advisories/GHSA-9pwp-9qqc-pr26).
Their package-specific prerequisites from the earlier assessment still apply;
presence does not establish exploitation in Mobi or delivery in its mobile app.

This fresh actual graph includes the **36 queries omitted by #127's narrower
published-file lookup**. Its Guava 33.4.0-jre
[finding](https://github.com/advisories/GHSA-xxph-c9ww-hj94), Commons Lang 3.16.0
[finding](https://github.com/advisories/GHSA-j288-q9x7-2f5v) and HttpClient 4.5.6
[finding](https://github.com/advisories/GHSA-7r82-7xv7-xcpj) were freshly matched
again and remain open. All nine IDs, affected package versions and record hashes
are retained in the compact receipt.

These nine matches cover named delegated graphs only. The broader distribution,
exporter and public-module findings in #127 remain separate and open; nine is
not a complete build dependency finding count. The 612 out-of-scope configuration
rows, unassigned/ambiguous files, shaded code and Native internals remain gaps.
No dependency-risk acceptance or security clearance follows.

## Cleanup and next qualification

Source verification, stored-input replay and exact classpath comparison passed
before cleanup. Existing recovery verified quiescence; existing cleanup removed
only `work/baseline` and `work/candidate`, retaining result/control evidence.
The next focused runtime check is retained project-JDK cache migration. The
version-bound Release/resource/relocated-delivery checks, risk/adoption decision,
device/signed delivery and active interop retirement checks remain separate.
The normal staged and hosted documentation-only gate results are recorded in
the final PR review comment; native tests and iOS delivery were not rerun here.
