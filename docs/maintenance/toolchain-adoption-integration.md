# Toolchain adoption commit-series integration

Current follow-up: the maintainer approved the direct development/test/unsigned
default on 2026-10-04. [Applied integration](direct-default-integration.md) records
current validation separately. Retained-bridge/default exclusions below describe
the historical decisions; credentialed delivery and physical deletion stay held.

Date: 2026-10-04. The maintainer authorized committing the reviewed local adoption, publishing a pull request for hosted checks, and continuing the independent bridge assessment.

| Revision | Scope and measured validation |
| --- | --- |
| `8965bf752eb0b31d80e4d9bd1524812ab6ac0fa7` | Maintenance collectors, attribution, advisory and owned-recovery prerequisites. The standalone tree passed 260 contracts in 16 suites and the normal pre-commit static gate plus Android/iOS tests and debug builds. |
| `171e893` | Toolchain 0.13.0, compile SDK 37, bounded manual risk/age overlay and linked security evidence. The standalone tree passed 272 contracts in 17 suites and the normal pre-commit static gate plus Android/iOS tests and debug builds. |

The commits were assembled in an isolated worktree so the hook could validate each complete staged tree while the caller's 568 original source files and modes remained unchanged. Historical patch receipts retain their exact pinned bytes; Git attributes prevent line-ending conversion of those evidence files. A stale architecture link was corrected to the existing `SharedHomeViewControllerFactory.kt`.

The third documentation cohort records independent bridge evidence and the remaining OpenSpec work. Its normal documentation gate and strict OpenSpec validation are separate from the two native gates above. [PR #35](https://github.com/Mekate-Studio/Mobi/pull/35) passed all seven checks in [Mobile CI run 37193455667](https://github.com/Mekate-Studio/Mobi/actions/runs/37193455667) for head `349e07e0929033e8feb71269e9555420d3285e35`. The tested merge revision `5cfd3ab3328610167f57a2cca7b5624df82fe142` has the same tree as that head. The [hosted receipt](evidence/2026-10-04-toolchain-adoption-hosted.json) verifies 38 Android tests, all twelve original Swift cases and 272 contracts in seventeen suites. Both iOS jobs reported CI cache misses; Android and quality caches were restored. These observations do not establish empty-host/license onboarding.

The [risk decision](toolchain-adoption-risk-review.md) retains all seventeen findings, the unchanged generic policy, the exact exception scope and the original **2026-11-03T05:48:38Z** expiry. The normal seven-day release threshold remains **2026-10-08T06:36:56Z**. This commit operation does not extend either decision.

The [fresh direct assessment](direct-adopted-toolchain-assessment.md) and [retirement path](bridge-retirement-path.md) retain the bridge-unavailable measurements separately. The [bounded interop pair](direct-interop-behavior-assessment.md) passed its named local typed state/generic and real cancellation, failure and continuation claims. The [operational assessment](direct-release-onboarding-assessment.md) then passed local and hosted Nightly, unsigned simulator Release and ARM64 archive/product pairs, including owned cleanup, artifact digests and replay. These follow-up review records remain uncommitted drafts; the manual hosted assessment code is published separately. Production still uses the Gradle bridge. Architecture/API review and a reversible default proposal are next. Device/exact-floor runtime, empty-host/license onboarding, complete dependency/resource coverage and signed delivery remain open; a direct-default transition and later physical bridge deletion require their own reviewed decisions.
