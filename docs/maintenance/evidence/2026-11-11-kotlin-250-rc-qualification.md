# Kotlin 2.5.0-RC qualification — 2026-11-11

This candidate moves the actual app from Kotlin 2.5.0-Beta2 to 2.5.0-RC,
including the matching standalone exporter. Metro 1.5.0, Toolchain 0.13.0,
coroutines 1.11.0, app behavior and producer flags remain unchanged. The
[source assessment](2026-11-11-kotlin-250-rc-assessment.md) supplies the official
release, implementation-doc, sample and issue review; this record adds execution
on Mobi. Functional qualification passes; advisory disposition and signed delivery
are not cleared. No interop workaround removal qualifies.

## Scope and age decision

Source baseline: `909c8333eafb93721a02cbf37c8aadeb8fce9c4b`, after PR #101.
The maintainer explicitly waived the time window for this candidate's
qualification on November 11. The exception binds Kotlin **2.5.0-RC** and its
publication **2026-11-11T10:19:34Z**. The unchanged seven-day threshold is
**2026-11-18T10:19:34Z**; it is not relabelled as eligible today.

Nine compiler declarations and three matching exporter coordinates change. The
existing compatibility reader gains validation of a per-release `age_waiver` so
the scheduled assessment can read this explicitly selected young tuple. It
requires an approved qualification-only decision, matching version/publication,
nonempty reason and an existing evidence document. Future publication and a
different young companion still refuse. Reports expose the real age, threshold,
waived release names and `adoption_authorized: false`. This is a qualification
policy exception, not an interop workaround, security acceptance or merge grant.
A new young tuple needs a new bound decision; the global policy is not lowered.

## Paired actual-app results

Separate source worktrees ran the same repo-owned jobs. Local tools were Xcode
27.2, Swift 6.4.2 and JDK 25; native execution used iPhone Air / iOS 26.5.
Downloaded dependencies were seeded into private caches; application outputs were
not copied from the baseline. These are local development/unsigned simulator
results, not clean-clone, device, minimum-runtime or signed-delivery evidence.

| Existing job/check | Beta2 baseline | RC candidate |
| --- | --- | --- |
| `android-test` | 94 passed | 94 passed |
| `ios-test`, PullRequest plan | 79 functions / 173 executions; no failures or skips | Same counts, no failures or skips |
| `android-build-debug` | Passed | Passed |
| `ios-build-debug` | Passed | Passed |
| `ios-build-release`, unsigned simulator | Passed | Passed |
| Generated API / actor / one-runtime compile controls | Passed, including six omission rejections | Identical report |
| Full strict-support producer | Existing support exception retained | Exit 1 at KotlinError/KotlinBase sendability/import diagnostics |

RC plus unchanged Metro 1.5.0 also compiled the actual shared-core Android and
Native targets before the full jobs. That establishes observed Mobi compatibility,
not a Metro vendor support statement: the reviewed table has no RC entry.
Toolchain task records identify the selected compiler for actual Native KLib
outputs; exporter commands use the matching RC Native distribution and artifacts.

The Release archive's `_KotlinRuntimeSupport_linkAnchor` changes from
`private external` to `external [no dead strip]`, matching the upstream retention
change. This improves the generated support artifact without adding app code.
It does **not** establish end-to-end strict Swift 6 support. The full producer
still fails before completion; the subsequent ordinary producer control succeeds
separately. IOS-08 remains, with no suppression, generated-source patch or new
fallback. All nine active mechanisms remain. The actual removed-constructor
regression contract passes, so IOS-15 stays removed.

The existing full contract suite passes, including 28 compatibility and 27 watch
contracts. Waiver controls reject revoked approval, adoption scope, version/time
mismatch, future publication and an unwaived young Metro. The initial full suite
was invalidated by a caller-supplied simulator destination affecting the
no-simulator negative control; the complete rerun with that variable unset passes
without changing assertions. Final staged/hosted gates are recorded in the PR.

Warning debt remains open. Normalized warning messages across the five paired
mobile job logs have the same 16 categories; this is a bounded log comparison,
not a compiler-warning audit. A standalone RC core-Native preflight also reports
missing cache object warnings; the baseline's five app jobs did not include that
extra preflight, so it is not classified as a candidate regression. Nothing is
suppressed. The existing warning follow-up remains necessary.

## Dependency/advisory comparison and limits

Public Toolchain settings and resolved graphs cover nine modules and 104 roots
per tuple. Each yields 357 named Maven package/version queries. The package/version
set changes only 15 Kotlin artifacts from Beta2 to RC; it does not prove complete
edge, artifact, compiler-plugin or bundled-byte equivalence. Four fresh OSV batches
and eight full finding records per tuple return HTTP 200 with matching result
cardinality and no pagination. Both tuples produce the same eight matches:

| Package/version | Finding and severity | Observed graph roots |
| --- | --- | --- |
| `org.bouncycastle:bcprov-jdk18on:1.81` | [GHSA-574f-3g2m-x479](https://osv.dev/vulnerability/GHSA-574f-3g2m-x479), **Critical**; [GHSA-9pwp-9qqc-pr26](https://osv.dev/vulnerability/GHSA-9pwp-9qqc-pr26), **Critical**; [GHSA-c3fc-8qff-9hwx](https://osv.dev/vulnerability/GHSA-c3fc-8qff-9hwx), Moderate; [GHSA-p93r-85wp-75v3](https://osv.dev/vulnerability/GHSA-p93r-85wp-75v3), High; [GHSA-qp49-qgx5-5m26](https://osv.dev/vulnerability/GHSA-qp49-qgx5-5m26), High | Android app **test** compile/runtime |
| `com.google.guava:guava:33.4.8-jre` | [GHSA-xxph-c9ww-hj94](https://osv.dev/vulnerability/GHSA-xxph-c9ww-hj94), High | Android app **test** compile/runtime |
| `io.opentelemetry:opentelemetry-api:1.41.0` | [GHSA-ccrj-gw8r-854m](https://osv.dev/vulnerability/GHSA-ccrj-gw8r-854m), Moderate; [GHSA-rcgg-9c38-7xpx](https://osv.dev/vulnerability/GHSA-rcgg-9c38-7xpx), Moderate | Standalone exporter JVM main/test compile |

These matches require explicit triage of affected operations and build/test
exposure. Root occurrence is not proof of exploitability, packaged app exposure,
or safety. No finding is waived or hidden because it predates RC, and no transitive
version is forced. The qualification age waiver does not accept these risks.
Historical toolchain risk receipts are not rebound to this new producer/graph.

Missing coverage remains explicit: shaded/bundled code, Native distribution
internals, complete compiler-plugin attribution, delegated Android plugin graph,
and Swift/Ruby/npm advisories. The [paired summary](2026-11-11-kotlin-250-rc-qualification.json)
records counts, finding matches, compiler output identities and raw evidence
hashes; it is not a complete advisory clearance or a reusable adoption receipt.

The baseline used the Maven Central Google mirror. That mirror initially returned
404 for the new RC stdlib POM/checksum before compilation; the candidate used
canonical Maven Central with ordinary verification enabled. This transport
difference and warm dependency seeding preclude controlled build-time or
byte-equivalence claims. A baseline setup interruption was discarded before the
successful complete rerun. Partial attempts are not passes.

## Review and recovery

The actual-app PR carries the candidate changes and author comments at the age
exception and compiler pins. Review functional evidence, unresolved advisory
triage and hosted results separately; successful tests do not grant adoption or
signed-delivery authority. Keep draft Android UI-test PR #99 deferred: no extra
runner, hidden metadata reader or Shared Home behavior from it is adopted here.
Recover by restoring the complete pre-update source revision, including all
compiler/exporter pins and compatibility metadata; do not mix runtime artifacts
from the two tuples. Reassess these remaining mechanisms against subsequent
prereleases through the existing update workflow and official sources.
