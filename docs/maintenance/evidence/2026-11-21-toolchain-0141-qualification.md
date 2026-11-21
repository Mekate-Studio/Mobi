# Toolchain 0.14.1 qualification — 2026-11-21

**Status: local and cache-free hosted native checks passed; not adopted.**
The [compact receipt](2026-11-21-toolchain-0141-qualification.json) binds the
source revisions, admission state, runtime observations, native reports and
raw-log hashes. Raw archives and logs stay in ignored evidence storage.

## Approved release-age exception

On November 21 the maintainer explicitly answered “yes” to the request for a
**0.14.1-only early-qualification waiver** for CLI/JDK and native checks.
This follows the merged [JRE assessment](2026-11-21-toolchain-0141-jre.md),
PR #123 at `15d42d515f5d3de92d1b396c3263c686ff8be695`.

The decision binds Toolchain **0.14.1**, publication **2026-11-19T17:46:59Z**,
and distribution SHA-256
`39fb5f7e0bd5148a02f5519e88d78752fb04e719ddb086258ff57e94d83c0fcb`.
Normal eligibility remains **2026-11-26T17:46:59Z**. Experimental runs retain
their actual `age_blocked` state and `adoption_authorized: false`.

The app stays on 0.13.0. This decision covers isolated qualification only;
adoption, dependency-risk acceptance, signed delivery and workaround removal
remain separate. Kotlin/exporter 2.5.0-RC, Metro 1.5.0, native packages, platform
floors and feature behavior stay fixed during comparison.

## Reviewable preparation

The reviewed candidate pins add 0.14.1 without changing the baseline or policy.
IOS-10's existing producer gains one exact allowed version; task records must
still match the selected wrapper exactly and use one compiler. The existing
contract now tests 0.14.1 and rejection of neighboring 0.14.0 records. Unknown
versions and mixed compilers continue to refuse. No adapter or runner is added.

This costs one producer allowlist entry and an extension of its existing
contract. No feature boundary, native state or maintained workflow changes.
On a separately approved adoption, review narrowing the accepted versions once
old recovery resources are closed. Full-revision rollback preserves the old
implementation. Removing the whole producer still requires the supported
replacement and real delivery evidence tracked by
[IOS-10](../interop-workarounds.md); a passing qualification does not retire it.

## Actual runtime observations

Seven real commands ran against the reviewed 0.14.1 wrappers in a private copy
of the app source, with owned bootstrap, shared, project and home directories.
Each exited successfully. These supplement the previous fake-Java selection
fixtures with actual JVM execution; the fixtures retain their narrower scope.

| Control | Measured result |
| --- | --- |
| Fresh managed CLI, `--version` | 0.14.1; Azul `25.0.5.1+2-LTS`, arm64 |
| Fresh default JDK, `tool jdk jcmd -- -h` | Provisions Temurin `25.0.5.1+2`; separate from the CLI runtime |
| Same commands with retained caches | Both pass without new distribution/JRE/JDK downloads |
| Inspect the selected JDK's own VM properties | CLI Azul and provisioned Temurin both report `25.0.5.1+2-LTS` |
| Explicit older `KOTLIN_CLI_JAVA_HOME`, `--version` | Uses the supplied Temurin `25.0.5+8-LTS` |
| Explicit older matching-major `JAVA_HOME`, JDK tool | CLI stays on Azul `25.0.5.1+2-LTS`; selected JDK is Temurin `25.0.5+8-LTS` |

The older JDK was downloaded to an owned diagnostic directory and checked
against its published SHA-256; no installed JDK or user cache was changed.
The probes disabled telemetry for their own process and printed VM properties
for attribution. Neither setting changes the app or its normal native gate.

The updated managed defaults do not upgrade explicit runtime overrides.
Same-version warm reuse was measured; an older developer project's cached
provisioning record carried across the update remains a separate check. These
arm64 observations do not exercise the vendor advisory's affected x64 CPU path
or establish security clearance. The
[vendor sources and architecture limits](2026-11-21-toolchain-0141-jre.md#cve-scope-and-three-runtime-choices)
still apply.

## Native comparison

Both versions passed the existing normal commit gate sequentially. The 0.13.0
baseline is preparation commit `1c573e341acfe889208df9fc6203ca42616e5ceb`.
The candidate uses that code plus the reviewed, LF-normalized 0.14.1 wrapper
pair and a qualification-only workflow step; no app source changes.

| Existing check | 0.13.0 baseline | 0.14.1 candidate |
| --- | --- | --- |
| Android/shared tests | 94 passed | 94 passed |
| iOS PullRequest plan | 80 functions / 174 passed executions | Same |
| Android and iOS Debug builds | Both passed | Both passed |
| Actual native project records | Seven, version 0.13.0 | Seven, version 0.14.1 |
| Kotlin/exporter | 2.5.0-RC | 2.5.0-RC |
| Complete switches / deliberate omissions | Six pass / six reject | Same |
| Kotlin runtime images | One | One |
| Owned Gradle stop and snapshot cleanup | Passed; Gradle 9.5.0 | Passed; Gradle 9.8.0 |

Both actual reports retain the same actor-isolation controls, one coroutine
inheritance diagnostic, and **blocked** KotlinRuntimeSupport and
KotlinCoroutineSupport strict probes. They do not establish full strict support
or authorize removal of the active isolation/build mechanisms.
The local candidate's actual JDK-provisioning task and extracted release metadata
identify Temurin `25.0.5.1+2-LTS`; its managed CLI uses Azul at the same Java
runtime version. These owners were measured separately.

All four hosted native logs instead show `setup-java@v5` resolving **25.0.5+8.0**
from the runner's tool cache and supplying it through `JAVA_HOME`. The managed
CLI still downloads Zulu **25.38.201**. Cache-free validation empties six
repository-owned roots; it does not replace preinstalled host tools or an
explicit JDK selection. These arm64 results do not qualify the advisory's x64
path or prove that every compilation JDK is patched. Review CI/developer JDK
freshness separately rather than attributing it to the wrapper update.

The cache-free hosted [qualification run](https://github.com/Mekate-Studio/Mobi/actions/runs/44908920034)
passed all seven jobs at `f897d227507866b877b85553460561a8ef5a0f9b`, on ref
`qualification/native-0141-20261121`. All five validation jobs verified six
absent repository cache/output roots before setup (30 receipts), and all five
cache restores were skipped. Android/shared tests passed 94 cases. The iOS
plan and both native Debug builds passed. The exported-API report matches the
local report except for the SDK path; it retains one runtime image, all six
omission rejections and both strict-support blocks. Hosted formatted stdout
lists 48 named non-parameterized functions; the local 174 execution count is
not inferred from that formatter.

The temporary workflow
selects adopted 0.13.0 only in the quality job, preserving live-root adoption
contracts; all four native jobs keep the candidate wrappers. That exact quality
selection also passed all 21 contract suites and static checks locally before
the owned wrapper overlay was restored. No policy guard was relaxed. The
one-off workflow is outside this PR and is not a maintained integration. The initial
0.13.0 [draft PR run](https://github.com/Mekate-Studio/Mobi/actions/runs/44907867795)
passed quality and Android checks before its remaining iOS jobs were deliberately
cancelled to free hosted runners for qualification. It is not a successful full
run. The final PR head must pass its own required checks with the adopted wrappers.

## Remaining decisions

This increment does not repeat 0.14.0's version-bound unsigned Release,
resource-invalidation or relocated-delivery observations for 0.14.1. Older
provisioning-cache reuse, other native architectures and device/signed delivery
also remain unqualified here. The unchanged Jackson/FUS artifacts, retained
dependency findings, unassigned artifacts and Gradle transform-observer gap
remain open under the earlier assessments. The
[warning follow-ups](../compiler-warning-follow-ups.md) and
[interop retirement checks](../interop-workarounds.md) stay active; changed
default warning output is not remediation. No risk acceptance, workaround
removal or adoption follows from these checks.
