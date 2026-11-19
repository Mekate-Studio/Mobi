# Toolchain 0.14.0 dependency assessment — 2026-11-18

**Decision: dependency evidence collected with open findings and coverage gaps;
0.14.0 remains unqualified for adoption.** The app remains on 0.13.0. This follows
[PR #115's functional qualification](2026-11-18-toolchain-014-qualification.md)
using base `4e408bbadb801cb00ea9e348f7f0e77abeffb9b6` and its approved,
release-specific age exception. No advisory risk or default switch is accepted.

The distribution improves some dependencies, but its launcher and delegated
Android integration retain different versions. A source catalog update does not
establish which artifact was delivered to either owner.

## Measured ownership and changes

| Owner / package | 0.13.0 | 0.14.0 | Actual consequence |
| --- | --- | --- | --- |
| Launcher Bouncy Castle | 1.84 | 1.86 | The queried 1.84 matches disappear for these launcher files |
| Launcher Commons Compress | 1.28.0 | 1.28.0 | Already updated in both archives; the source catalog's 1.27.1 → 1.28.0 declaration is not an artifact change here |
| Launcher Netty handler | 4.2.9.Final | Same bytes/version | Its advisory matches remain, despite newer Netty files elsewhere in each archive |
| Launcher Jackson core | 2.21.1 | 2.13.5, with annotations/databind 2.13.5 | Candidate adds older Jackson files and corresponding advisory matches; this is not an across-the-board dependency improvement |
| Android integration Bouncy Castle | 1.79 | Same bytes/version | Two Critical matches remain in the measured integration classpath and named delegated graph |
| Android integration Kotlin Gradle Plugin | 2.2.10 | Same bytes/version | Existing build-cache deserialization finding remains; the newer compiler selection does not update this file |
| Launcher / Android integration OpenTelemetry API | 1.60.1 | 1.66.0 | Baggage finding disappears for these files; tracestate finding remains |
| Standalone Swift exporter OpenTelemetry API | 1.41.0 | Unchanged | Both existing Moderate findings remain in the public module graph |
| Delegated Gradle / AGP | 9.5.0 / 9.3.1 | 9.8.0 / 9.3.1 | Both real Android Debug captures pass; no Android plugin upgrade is inferred |

These are whole-file identities matched against reviewed Maven references, not
filenames interpreted as package identity. `lib/*` is the published launcher's
classpath. Presence there establishes a classpath surface, not a loaded class,
reachable vulnerable call or a vulnerability in the shipped mobile app. Likewise,
Android build dependencies are not automatically mobile runtime dependencies.

## Capture and attribution

Run `d6a65abb2931e530df44b62b9c28de72` passed both phases using the existing
executor, source guards, resource lifecycle, delegated observer and strict graph
validator. Only the candidate's reviewed wrapper pair changed. Each phase freshly
captured all nine modules, 104 public dependency roots, settings, dependencies
and an Android Debug build. The normalized public query sets remain identical
at 359 package/version pairs. Kotlin/exporter 2.5.0-RC, Metro, Swift packages and
platform floors stayed fixed.

Both archives were downloaded, streamed and SHA-256 verified independently:

| Archive | Bytes | SHA-256 |
| --- | --- | --- |
| 0.13.0 | 416655389 | `fa82b9872dcfa04d26c8f800f33d597c99fbffd747a0e9bbce3a9e4424b3a588` |
| 0.14.0 | 420236123 | `69112cebc1fdb14c92a213244182d0834896e71b3d9411b8e8c18540da2884a6` |

Each phase yielded two delegated captures: 1,828 configuration rows comprising
136 resolved, 612 explicitly outside Android Debug main scope, and 1,080
non-resolvable rows. They contain 83 named Maven package/version pairs per phase.
The **215 observed settings-classpath files exactly match** the archive's Android
integration index by SHA-256 and length, with no unmatched observed/indexed files.
For each version, 192 files match Maven references and 23 have registered upstream
source-module plus embedded Kotlin metadata correspondence. The candidate's
metadata names gain the `org.jetbrains.amper_` prefix; this was measured rather
than accepting the historical names unchanged. Source correspondence is not a
reproducible source-to-binary attestation or an invented Maven coordinate.

The complete distribution is broader than this integration index:

| Archive surface, counting entries rather than unique dependencies | 0.13.0 | 0.14.0 |
| --- | --- | --- |
| All JAR entries / unique SHA-256 + length identities | 619 / 485 | 632 / 497 |
| Launcher entries | 355 | 375 |
| Launcher: Maven reference / source correspondence / unassigned / ambiguous | 265 / 22 / 67 / 1 | 268 / 22 / 84 / 1 |
| Other extra entries: Maven reference / unassigned | 24 / 25 | 18 / 24 |

References combine fresh independently downloaded Maven artifacts, fresh named
resolved artifacts, and the historical 0.13.0 references in the
[remediation](2026-10-03-upstream-remediation.json) and
[attribution](2026-10-03-bundled-attribution.json) receipts. Historical references
are reused only on exact whole-file SHA-256 and length matches, not as fresh
resolution, selected-variant or advisory evidence. Public catalogs, publisher
metadata, embedded properties and archive labels supplied lookup hypotheses;
none alone grants identity. Uniqueness is relative to the reviewed references.
`mordant-jvm` 3.1.0 and 3.1.1 publish identical matched bytes: both possible
versions were queried and the entry remains ambiguous. Unassigned files remain
visible; no clean result is inferred for them, shaded code or native internals.

## Fresh advisory results

Official OSV responses were retrieved **2026-11-18T22:20:41Z–22:21:14Z** using the
existing bounded provider transport and packet-binding checks. All **804** union
queries have corresponding responses across nine batches, no pagination, and
all **75** distinct matched records were fetched in full. There are **86**
package/version/advisory pairs in the joint inventory. Owner counts overlap and
must not be summed; query counts and finding counts measure different things.

| Measured owner | 0.13.0 query count / matched pairs | 0.14.0 query count / matched pairs |
| --- | --- | --- |
| Launcher, uniquely attributed among reviewed references | 265 / 56 | 268 / 64 |
| Android integration distribution classpath | 192 / 23 | 192 / 19 |
| Named delegated graph | 83 / 9 | 83 / 9 |
| Public module graph, including exporter tooling | 359 / 2 | 359 / 2 |
| Other extra attributed files | 24 / 0 | 18 / 0 |
| Ambiguous launcher byte versions, queried conservatively | 2 / 0 | 2 / 0 |

Counts are package advisory matches, not exploitability or aggregate risk scores.
The launcher has 54 → 62 distinct advisory IDs; the candidate still has one
Critical match according to the captured OSV severity field. The integration
classpath retains two Critical matches. The source assessment's 71 declaration
queries and prior module-only result did not cover these complete owner sets.

Review priorities are explicit:

- Android integration and the named delegated graph retain Bouncy Castle 1.79's
  [GOST counter reuse](https://github.com/advisories/GHSA-574f-3g2m-x479) and
  [Name Constraints bypass](https://github.com/advisories/GHSA-9pwp-9qqc-pr26),
  both Critical in the captured records. These require their named cryptographic
  operations; their presence is not proof Mobi invokes them. Launcher 1.86 does
  not repair the separate 1.79 files.
- Both launcher inventories retain Netty handler 4.2.9.Final and
  [GHSA-c4c3-7fpv-j4q5](https://github.com/netty/netty/security/advisories/GHSA-c4c3-7fpv-j4q5).
  The record describes SNI routing/mTLS bypass under specific server policies;
  actual Mobi tool call paths have not been traced. OSV labels it Critical while
  the maintainer page labels it High; the recorded counts use OSV consistently.
  The separate extra 4.2.17.Final file does not establish launcher remediation.
- Kotlin Gradle Plugin 2.2.10 retains the Moderate
  [build-cache deserialization finding](https://github.com/advisories/GHSA-r937-wjx7-w2jp).
  Compiler/exporter 2.5.0-RC is a different owner. No cache trust mitigation or
  vulnerable-path exclusion was established by these captures.
- OpenTelemetry API 1.66.0 retains the Moderate
  [tracestate finding](https://github.com/open-telemetry/opentelemetry-java/security/advisories/GHSA-ccrj-gw8r-854m).
  The exporter's separate 1.41.0 still matches it and
  [the baggage finding](https://github.com/advisories/GHSA-rcgg-9c38-7xpx).
- Candidate Jackson 2.13.5, retained LZ4, JDOM, jose4j, Guava and the remaining
  Netty findings stay in the package-level triage queue. The full local assessment
  retains every measured package/version/ID and record digest, including High
  findings; a successful build does not dismiss them.

## Existing observer limitation and next decision

Effective AGP project options report **Jetifier disabled** on both versions.
The unchanged transform observer reports `observed` for Gradle 9.5.0 but
`incomplete / unsupported_gradle_api` for 9.8.0. Its zero event counters on the
candidate are not evidence of no transformations. No private API allowlist was
expanded and no transform-based mitigation is claimed. Re-evaluate a supported
observation API on Gradle/Toolchain updates; any fallback adapter needs its own
bounded design review, version guard and replacement/removal condition.

This PR adds evidence and documentation only. One-off ignored orchestration
reused existing collectors; it adds no maintained build project, dependency
override, runner or general private-metadata adapter. The historical high-level
0.13.0 bundled-attribution guard stays unchanged. Existing IOS-10, IOS-08,
AND-03 and warning dispositions remain. Initial orchestration encoding/source-copy
refusals occurred before Gradle execution; their diagnostics were retained and
owned work cleaned before the successful run. Completed build workspaces were
verified quiescent and cleaned through the existing ownership protocol.

Before adoption, review the measured advisory changes and remaining owner-specific
findings together with the attribution and transform visibility gaps. A separate
bounded increment can qualify unsigned Release, cold/relocated delivery and
controlled manifest/resource invalidation; passing those checks would still not
accept dependency risk, sign/publish an app or retire an interop workaround.

## Review evidence

The [compact receipt](2026-11-18-toolchain-014-dependencies.json) retains the
source/run and archive identities, owner counts, provider bindings, cleanup and
remaining gaps. Its selected artifact identities support the key change and
ownership claims above; they are a deliberate subset of the complete inventory.

The full file/query/finding inventories, raw graphs, command logs, archive
metadata/source bodies and provider packets remain in ignored local assessment
storage. Their hashes remain in the receipt. These generated captures are not
app or workflow inputs and are not committed as bulk review tables. A clean clone
contains the assessment and selected evidence, not the full raw captures or a
maintained one-command replay runner. The streamed archives and owned build
workspaces were removed after evidence retention. A later refresh must bind new
provider records and actual artifacts.
