# Toolchain adoption commit-series integration

Date: 2026-10-04. The maintainer authorized committing the reviewed local adoption, publishing a pull request for hosted checks, and continuing the independent bridge assessment.

| Revision | Scope and measured validation |
| --- | --- |
| `8965bf752eb0b31d80e4d9bd1524812ab6ac0fa7` | Maintenance collectors, attribution, advisory and owned-recovery prerequisites. The standalone tree passed 260 contracts in 16 suites and the normal pre-commit static gate plus Android/iOS tests and debug builds. |
| `171e893` | Toolchain 0.13.0, compile SDK 37, bounded manual risk/age overlay and linked security evidence. The standalone tree passed 272 contracts in 17 suites and the normal pre-commit static gate plus Android/iOS tests and debug builds. |

The commits were assembled in an isolated worktree so the hook could validate each complete staged tree while the caller's 568 original source files and modes remained unchanged. Historical patch receipts retain their exact pinned bytes; Git attributes prevent line-ending conversion of those evidence files. A stale architecture link was corrected to the existing `SharedHomeViewControllerFactory.kt`.

The third documentation cohort records independent bridge evidence and the remaining OpenSpec work. Its normal documentation gate and strict OpenSpec validation are separate from the two native gates above. Local completion is not hosted validation. A pull request on the public repository will measure the committed revision; workflow cache reuse must not be described as empty-cache onboarding.

The [risk decision](toolchain-adoption-risk-review.md) retains all seventeen findings, the unchanged generic policy, the exact exception scope and the original **2026-11-03T05:48:38Z** expiry. The normal seven-day release threshold remains **2026-10-08T06:36:56Z**. This commit operation does not extend either decision.

The [fresh direct assessment](direct-adopted-toolchain-assessment.md) and [retirement path](bridge-retirement-path.md) retain the bridge-unavailable measurements separately. Next is a bounded fixture assessment of typed state/generic exports and real cancellation, failure and continuation-lifetime behavior in both paths. Production still uses the Gradle bridge. Device/exact-floor runtime, empty-host/license onboarding, complete dependency-surface coverage and signed delivery remain open; a direct-default transition and later physical bridge deletion require their own reviewed decisions.
