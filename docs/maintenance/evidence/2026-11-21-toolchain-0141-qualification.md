# Toolchain 0.14.1 qualification — 2026-11-21

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

Qualification results are added after the actual checks complete. The prior
static cache fixtures remain their own evidence; they did not execute a JRE.
