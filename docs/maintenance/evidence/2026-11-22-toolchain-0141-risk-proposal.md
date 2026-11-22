# Proposed 0.14.1 residual-risk disposition

**Pending maintainer decision. This document grants no approval.** Adoption PR
[#134](https://github.com/Mekate-Studio/Mobi/pull/134) remains draft. The old
0.13.0 decision is expired; the 0.14.1 qualification waiver cannot authorize
public-source adoption or its dependency risk.

The proposed benefit is the qualified CLI JRE security update and corrected
Android Debug manifest/resource invalidation. The proposed concession is bounded
use with the measured findings and unmeasured surfaces below still present.
No dependency remediation, exploitability determination or workaround retirement
is claimed.

## Proposed scope for a separate decision

Request approval only for this exact 0.14.1 packet and source, for public-source
development builds, repository tests and isolated compatibility assessments.
Cap the window at 30 days from an actual approval, subject to unchanged packet,
source, finding/severity, artifact and coverage bindings and fresh providers.
Source edits or provider refreshes invalidate the exact packet and require a
new review; this is not an unattended per-build permission. No start, expiry,
approval reference or qualification signoff is recorded in advance.

Before **November 26 at 17:46:59 UTC**, a separate early-age exception must
explicitly cover this scoped manual-risk use of 0.14.1 (published November 19 at
17:46:59 UTC). The earlier qualification-only exception is insufficient.

Use repo-owned source-isolated validation with synthetic debug signing; provide
no credentialed release/signing material. Those checks isolate sources and
private caches, not the entire host. Preserve the actual selected JVM: an
explicit older JVM override takes precedence over the managed-runtime update.
Credentialed archive/export/TestFlight, physical bridge deletion and IOS-10
retirement remain outside this proposed grant. Adoption and merge remain
separate decisions.

## Fresh provider review over retained measurements

The refreshed lookup verifies **851 queries**, retaining **75 comparison IDs**.
**74 IDs match candidate queries:** 33 High, three Critical, 37 Moderate and one
Low. The baseline-only High remains in the comparison; counts are not a claim
that all queried code is loaded, reachable or exploitable. Artifact/input
measurements are retained November 21 captures, not new resolution or a new
independent download of every artifact.

- Distribution responses: `2026-11-22T16:06:32Z` through `2026-11-22T16:07:05Z`.
- Delegated responses: `2026-11-22T16:07:06Z` through `2026-11-22T16:07:09Z`.
- Official release response: `2026-11-22T16:07:09Z`.

Every candidate High/Critical ID maps to recorded whole-file bytes. The table
shows the 18 affected coordinate/file identities, not the complete inventory.
SHA-256 and byte size bind each exact recorded file; neither establishes that
its attribution claim is correct. Advisory links point to the provider records.
Critical IDs are marked **Critical**; all other listed IDs are High. The full
74-ID/severity set and detailed artifacts remain in the ignored proposal packet.

| Recorded Maven coordinate | File SHA-256 / bytes | Blocking advisory IDs |
| --- | --- | --- |
| `com.fasterxml.jackson.core:jackson-core:2.13.5` | `48f36a025311d0464ad8dda4512a20c79e279a9550f63f3179d731d94482474b` / 375,186 | [GHSA-7hhh-6rmp-j9qf](https://api.osv.dev/v1/vulns/GHSA-7hhh-6rmp-j9qf), [GHSA-h46c-h94j-95f3](https://api.osv.dev/v1/vulns/GHSA-h46c-h94j-95f3), [GHSA-r7wm-3cxj-wff9](https://api.osv.dev/v1/vulns/GHSA-r7wm-3cxj-wff9) |
| `com.fasterxml.jackson.core:jackson-databind:2.13.5` | `5fedb24b2356491815d18267f65da9a21dd67413345ad7795f221afa25c78984` / 1,537,543 | [GHSA-cxp5-3px4-pw24](https://api.osv.dev/v1/vulns/GHSA-cxp5-3px4-pw24), [GHSA-j3rv-43j4-c7qm](https://api.osv.dev/v1/vulns/GHSA-j3rv-43j4-c7qm), [GHSA-rmj7-2vxq-3g9f](https://api.osv.dev/v1/vulns/GHSA-rmj7-2vxq-3g9f), [GHSA-wv8q-qhhj-9h54](https://api.osv.dev/v1/vulns/GHSA-wv8q-qhhj-9h54) |
| `com.google.guava:guava:33.4.0-jre` | `b918c98a7e44dbe94ebd9fe3e40cddaadb5a93e6a78eb6008b42df237241e538` / 3,080,298 | [GHSA-xxph-c9ww-hj94](https://api.osv.dev/v1/vulns/GHSA-xxph-c9ww-hj94) |
| `com.google.guava:guava:33.5.0-jre` | `1e301f0c52ac248b0b14fdc3d12283c77252d4d6f48521d572e7d8c4c2cc4ac7` / 3,017,283 | [GHSA-xxph-c9ww-hj94](https://api.osv.dev/v1/vulns/GHSA-xxph-c9ww-hj94) |
| `com.google.guava:guava:33.6.0-jre` | `dc573e1fca4fd5454f4a5fd3d7da2df03002876a4175bafc14a95980dd7713b3` / 3,064,793 | [GHSA-xxph-c9ww-hj94](https://api.osv.dev/v1/vulns/GHSA-xxph-c9ww-hj94) |
| `commons-beanutils:commons-beanutils:1.9.4` | `7d938c81789028045c08c065e94be75fc280527620d5bd62b519d5838532368a` / 246,918 | [GHSA-wxr5-93ph-8wr9](https://api.osv.dev/v1/vulns/GHSA-wxr5-93ph-8wr9) |
| `io.netty:netty-codec-compression:4.2.9.Final` | `4523a65fe95bf474afdcfaf7e2c214b088d2376dacc43737be2acf968520be7e` / 182,887 | [GHSA-558v-64gr-wgg4](https://api.osv.dev/v1/vulns/GHSA-558v-64gr-wgg4), [GHSA-mj4r-2hfc-f8p6](https://api.osv.dev/v1/vulns/GHSA-mj4r-2hfc-f8p6) |
| `io.netty:netty-codec-http2:4.2.9.Final` | `11dd20dee783f75036a51462588b3f1f42ee7588be6cecc8a9f59f4c2f3acfe4` / 501,134 | [GHSA-93wv-jw9v-4972](https://api.osv.dev/v1/vulns/GHSA-93wv-jw9v-4972), [GHSA-f6hv-jmp6-3vwv](https://api.osv.dev/v1/vulns/GHSA-f6hv-jmp6-3vwv), [GHSA-w9fj-cfpg-grvv](https://api.osv.dev/v1/vulns/GHSA-w9fj-cfpg-grvv) |
| `io.netty:netty-codec-http:4.2.9.Final` | `a76ccb5d32c973d3a463710c9bf83354995354d1c39e1e4bc6155c628b71a20a` / 684,000 | [GHSA-57rv-r2g8-2cj3](https://api.osv.dev/v1/vulns/GHSA-57rv-r2g8-2cj3), [GHSA-6jqx-86gh-f27w](https://api.osv.dev/v1/vulns/GHSA-6jqx-86gh-f27w), [GHSA-f6hv-jmp6-3vwv](https://api.osv.dev/v1/vulns/GHSA-f6hv-jmp6-3vwv), [GHSA-jppx-w49h-x2qq](https://api.osv.dev/v1/vulns/GHSA-jppx-w49h-x2qq), [GHSA-mvh2-crg5-v77c](https://api.osv.dev/v1/vulns/GHSA-mvh2-crg5-v77c), [GHSA-pwqr-wmgm-9rr8](https://api.osv.dev/v1/vulns/GHSA-pwqr-wmgm-9rr8) |
| `io.netty:netty-handler:4.2.9.Final` | `e16126c711c1c8217342882cc0d9086007852cb0f99a351cfebe7725e8c7e100` / 582,132 | [GHSA-3qp7-7mw8-wx86](https://api.osv.dev/v1/vulns/GHSA-3qp7-7mw8-wx86), [GHSA-c4c3-7fpv-j4q5](https://api.osv.dev/v1/vulns/GHSA-c4c3-7fpv-j4q5) **Critical**, [GHSA-c653-97m9-rcg9](https://api.osv.dev/v1/vulns/GHSA-c653-97m9-rcg9), [GHSA-x4gw-5cx5-pgmh](https://api.osv.dev/v1/vulns/GHSA-x4gw-5cx5-pgmh) |
| `io.netty:netty-transport-classes-epoll:4.2.9.Final` | `b38f1f0eda4a0431388e8ca1adbba4ddfa44ce4660e35ed5ee28aa306dbd0006` / 156,974 | [GHSA-rwm7-x88c-3g2p](https://api.osv.dev/v1/vulns/GHSA-rwm7-x88c-3g2p) |
| `org.bitbucket.b_c:jose4j:0.9.5` | `808fb3166f3e67dad9811c331029ab1681242fd52b735bc3f33f281167fcc72e` / 298,683 | [GHSA-3677-xxcr-wjqv](https://api.osv.dev/v1/vulns/GHSA-3677-xxcr-wjqv) |
| `org.bouncycastle:bcprov-jdk18on:1.79` | `0d81ecc3124536b539bce9aa3fe9621b7f84c9cee371b635a5b31c78b79ab1da` / 8,575,537 | [GHSA-574f-3g2m-x479](https://api.osv.dev/v1/vulns/GHSA-574f-3g2m-x479) **Critical**, [GHSA-9pwp-9qqc-pr26](https://api.osv.dev/v1/vulns/GHSA-9pwp-9qqc-pr26) **Critical**, [GHSA-p93r-85wp-75v3](https://api.osv.dev/v1/vulns/GHSA-p93r-85wp-75v3), [GHSA-qp49-qgx5-5m26](https://api.osv.dev/v1/vulns/GHSA-qp49-qgx5-5m26) |
| `org.eclipse.jetty:jetty-http:9.4.58.v20250814` | `8f49b8583fc8dbbfe3a0ba80a04c97df64ebabca2981b56ee403c989aba9d4da` / 253,267 | [GHSA-355h-qmc2-wpwf](https://api.osv.dev/v1/vulns/GHSA-355h-qmc2-wpwf) |
| `org.eclipse.jetty:jetty-security:9.4.58.v20250814` | `301548ebf008551a3a4312b04df0ea0468acc2780f863b83cc9cf0d668e62252` / 119,718 | [GHSA-2fvj-hgj9-j2gr](https://api.osv.dev/v1/vulns/GHSA-2fvj-hgj9-j2gr) |
| `org.jdom:jdom2:2.0.6` | `1345f11ba606d15603d6740551a8c21947c0215640770ec67271fe78bea97cf5` / 304,924 | [GHSA-2363-cqg2-863c](https://api.osv.dev/v1/vulns/GHSA-2363-cqg2-863c) |
| `org.jsoup:jsoup:1.22.1` | `cfd3298d8720cddfb0545109ccc6ea0ef39eff7e9c40a10ad95c93a65f01c916` / 508,348 | [GHSA-65r4-943x-97jj](https://api.osv.dev/v1/vulns/GHSA-65r4-943x-97jj) |
| `org.lz4:lz4-java:1.8.0` | `d74a3334fb35195009b338a951f918203d6bbca3d1d359033dc33edd1cadc9ef` / 682,804 | [GHSA-cmp6-m4wj-q63q](https://api.osv.dev/v1/vulns/GHSA-cmp6-m4wj-q63q), [GHSA-mcr4-qmvw-px4g](https://api.osv.dev/v1/vulns/GHSA-mcr4-qmvw-px4g), [GHSA-vqf4-7m7x-wgfc](https://api.osv.dev/v1/vulns/GHSA-vqf4-7m7x-wgfc) |

## Coverage and validation that remain separate

The proposed decision must explicitly acknowledge unassigned/ambiguous files,
shaded/native attribution gaps, configurations outside observed Android Debug
main, the unsupported Gradle 9.8 transform observer, and physical-device, exact
OS-floor and signed-delivery gaps. Zero transform counters are not proof of no
transforms. Bounded risk acceptance does not close these gaps or permit IOS-10
retirement.

[PR #135](https://github.com/Mekate-Studio/Mobi/pull/135) supplied the reviewed
packet verifier. Rebased #134 must pass current local/hosted validation before
requesting this decision. Earlier normal/cache-free 0.14.1 results retain their
original source heads; they are not relabeled as new rebased-head runs.

The final packet binds the reviewed diff and full source plus qualification
receipts, including the exact updated adoption CI run. Final source/packet
digests belong in the PR and ignored decision proposal, outside the source they
bind. The verifier is run without a decision and must remain blocked until
explicit maintainer approval and qualification-receipt signoff. Provider
freshness must still pass the unchanged 24-hour limits at that decision.
