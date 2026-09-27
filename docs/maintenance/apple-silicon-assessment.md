# Apple Silicon target and Toolchain assessment

Status: the original local input/mobile comparisons passed. On 2026-09-27 the
maintainer approved and applied the exact eight-file candidate in the working
tree. This document preserves the pre-adoption review; its embedded receipts
correctly retain `adoption_authorized: false`. See the separate
[adoption and support-policy record](support-policy-validation.md) for the
subsequent decision, explicit minimums and validation. No commit/push is implied.
Reviewed 2026-09-27. Disposable mobile-workspace cleanup is blocked by a changed
host identity after continuation; the original successful result is retained.

## Decision being assessed

Prefer upstream-supported iOS targets over holding back Toolchain/Compose to keep
Intel simulators. Assess Toolchain 0.12.2 with `iosArm64` devices and
`iosSimulatorArm64` simulators. Retire `iosX64` from the five shared modules and
the retained Gradle bridge. Preserve Xcode app/test targets, native tests, Swift
sealed-state adapters, Metro/SKIE, clean-clone onboarding and release requirements.

The current checkout remains the baseline. The explicit `apple-silicon` option in
the [rehearsal command](kotlin-rehearsal.md) creates eight candidate-only edits.
The user must approve adoption after reviewing measured outcomes and implications.
No dependency downgrade is proposed to preserve the retired architecture.

## Verified upstream direction

- [Compose 1.11.0 migration notes](https://github.com/JetBrains/compose-multiplatform/releases/tag/v1.11.0)
  remove Apple x86_64 targets and require Kotlin 2.3 for native/web platforms.
- [Toolchain 0.12.0 changes](https://github.com/JetBrains/kotlin-toolchain/releases/tag/v0.12.0)
  remove `iosX64` from `ios/app`, default to Kotlin 2.4.10, Compose 1.11.1 and
  compilation JDK 25. Explicit library targets still need migration.
- [Apple's Xcode 27 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes)
  specify Apple Silicon hosts. [macOS 27 compatibility](https://support.apple.com/en-us/127255)
  lists Apple Silicon Macs. These are development-host constraints, distinct from
  the app's minimum iOS version.
- [Apple's Xcode requirements](https://developer.apple.com/xcode/system-requirements)
  distinguish SDK, deployment and simulator/device support. An iOS 27 SDK does
  not imply an iOS 27 minimum deployment target.
- [Kotlin Native target support](https://kotlinlang.org/docs/native-target-support.html)
  still lists `iosX64` as Tier 3. The incompatibility is attributable to this
  Compose/Toolchain product combination, not a claim that every compiler removed it.
- [GitHub runner specifications](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
  list `macos-26` as ARM64 and `macos-26-intel` separately. Mobi already uses
  `macos-26`; no runner-label migration is needed for this candidate.

## Adoption implications

| Surface | Candidate / implication |
| --- | --- |
| Toolchain wrappers | 0.11.1 to reviewed 0.12.2; effective compiler, JDK and dependency defaults change together |
| Shared libraries | Five module lists lose `iosX64`; Android, `iosArm64`, `iosSimulatorArm64` remain |
| Gradle bridge | Remove `iosX64()` and its duplicate source mapping; both ARM mappings and common tests remain |
| Native contributors | Full local iOS builds/tests require an Apple Silicon Mac; Intel iOS simulators leave Mobi's support policy |
| iPhone/iPad users | No device architecture is removed; Swift package declares iOS 16, while the app inherits iOS 27.0 with this Xcode installation |
| Xcode | Existing app/test project and scheme remain; no Xcode/SDK upgrade is silently included |
| CI | Existing ARM64 label remains; candidate still requires cold hosted integration evidence |
| Plugins / Swift | Existing bridge pins and sealed-state adapters remain; native regression checks must pass |
| Android / common tooling | No blanket removal of x86_64 artifacts, Linux/Windows support or Android emulator architectures |
| Packaging | Debug build evidence is scoped; unsigned device/Release and signed release claims require their own evidence |
| Bridge retirement | Separate direct-path experiment with the bridge unavailable remains required |

The historical wrapper-only run failed resolving Compose foundation 1.11.1 and
Material3 1.11.0-alpha07 against the declared `iosX64` target. Its original result
and later diagnostic reassessment remain in [slice 6 validation](sixth-slice-validation.md).
That result rejects the old target combination; it does not justify preserving it.

## Measured candidate evidence

The [reviewable eight-file patch](evidence/2026-09-27-apple-silicon.patch) is the
exact candidate used in the mobile run. The
[public evidence receipt](evidence/2026-09-27-apple-silicon.json) retains source,
patch, implementation, logs, graph and artifact identities. The original run
results remain unchanged in the local maintenance store.

| Check | Baseline 0.11.1 / current targets | Candidate 0.12.2 / ARM targets |
| --- | --- | --- |
| Standalone input comparison | Passed; 104 graph roots | Passed; 92 graph roots, no `iosX64` |
| Mobile input capture | Passed | Passed; both ARM targets retain main/test compile/runtime coverage |
| Android/shared tests | Passed, 248.667 s | Passed, 282.971 s |
| Android debug packaging | Passed, 43.934 s | Passed, 40.130 s |
| Xcode `PullRequest` tests | Passed, 298.864 s | Passed, 295.153 s |
| iOS debug build | Passed, 59.523 s | Passed, 60.309 s |
| Complete mobile phase | Passed, 716.864 s | Passed, 740.881 s |

Input run: `f4768c1a5ebacd0f3005fe64d3a61e41`. Mobile run:
`f294bb428d3be94fbb1357781c2176b5`. Both report `checks_passed` with
`adoption_authorized: false`. Each native test plan passed 12 Swift test cases
on an owned iOS 27.0 simulator. The candidate clears the earlier Compose target
failure without downgrading its selected foundation 1.11.1 or Material3
1.11.0-alpha07. The native jobs still select the Gradle bridge.

Validation also passed all 133 repository contracts, all 21 focused contracts on
system Ruby, the five pinned static analyzers (6.224 s on the refreshed run), Ruby
syntax and strict OpenSpec validation. The source, eight-file patch, implementation
and recorded history identities were verified before updating this report. This
report, public receipt/patch and task-status updates are post-capture documentation;
they do not claim a native rerun of a later source snapshot.

There are two distinct deployment declarations: the Swift package explicitly
declares iOS 16, but the Xcode app/test configurations have no explicit
`IPHONEOS_DEPLOYMENT_TARGET`. Both measured phases export `27.0` on Xcode 27.
Thus this rehearsal does **not** establish app support for iOS 16. The initial
package-floor assumption is corrected here; choosing and explicitly declaring a
stable app minimum remains a separate adoption-policy decision.

## Untested assumptions and remaining gates

- App deployment settings remain implicit; no minimum-OS support claim should
  be inferred from the Swift package's iOS 16 declaration. Runtime behavior on
  earlier OS versions and physical devices was not tested.
- The inspected local host is ARM64, macOS 27.0 (`26A428`), Xcode 27.0 (`27A266a`).
  Its exact installed SDK/runtime defines local execution evidence; upstream
  documentation alone is not proof of compatibility on other hosts or versions.
- Cold hosted onboarding, complete bridge dependency graph, current advisory
  assessment and release packaging need independent evidence before broader claims.
- Windows wrapper execution, Linux execution and Kotlin/Native common tests
  beyond the existing Xcode Swift test plan are not covered by these mobile jobs.

## Blockers and resource status

The originating executor recorded both mobile phases as `stopped` after its
ownership-aware resource handler completed. The successful result and all log,
evidence, patch and history hashes were verified after continuation. The input
run's two disposable workspaces were removed, with evidence retained.

The mobile run's disposable copies remain: recovery now returns
`Run store host or owner mismatch`. Inspection confirms that the hostname-derived
host identity differs while UID and canonical store path match. This is not an
automatic approval rejection or a new compiler failure. The guard prevents acting
on old process/device identities from another host. No marker was rewritten and
no unverified process/device/workspace was removed. Complete cleanup on the
originating host with the documented recovery/cleanup commands, or design and
validate an explicit store-transfer procedure separately. New rehearsals against
this particular retained store also remain blocked until its ownership is resolved.

## Review and recovery

Recommendation: adopt the upstream-compatible target direction and Toolchain
0.12.2 through a separately approved integration. The local comparison supports
that decision; it is not complete release or bridge-retirement certification.

Adoption would apply the eight-file patch, document Apple Silicon iOS development
in README/local-development/platform direction, advance the maintenance manifest's
baseline to 0.12.2 and retire this one-time target migration as an active candidate.
Historical receipts and fixture coverage remain. Run the normal pre-commit and
cold integration gates on that final source. Decide the explicit app minimum OS
instead of silently equating it with the package floor. Bridge removal, publishing
and commit/push are outside this adoption decision.

Before adoption, recovery discards only the owned workspace after verifying
quiescence; journals and results remain. After a separately approved adoption,
rollback must restore both wrappers and all six target-declaration files together,
then rerun the retained-bridge baseline. Reintroducing Intel with new Compose alone
would restore the known incompatible combination.
