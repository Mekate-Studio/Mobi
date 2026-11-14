# Android SDK provisioning: WARN-09 — 2026-11-14

The main Android test and Debug-build jobs now provision a job-owned SDK through
the existing `android-actions/setup-android@v4` action. Its documented `packages`
input requests `platform-tools cmdline-tools;latest`. The installed package manager
writes the metadata Toolchain requires. Application code, dependency pins, SDK
floors and delegated Android Gradle bootstrap are unchanged.

Base: `7c1aaacfb889d9a654415311cbf9d03b3081725c`, merged PR #105. The executable
change is two action configurations in `mobile-ci.yml`: an SDK root under
`runner.temp`, the two standard SDK environment variables, and the package list.
No repository SDK installer, metadata writer, compatibility wrapper or new cache
is introduced. Other workflows retain their existing setup and need separate
qualification; WARN-09 is **partially addressed**, not closed.

## Decision requiring review: job ownership versus image reuse

A job-owned directory avoids modifying or depending on the hosted image's
incomplete `cmdline-tools/latest` directory. The action exports that SDK root for
the following repository command through its existing environment handling.
The runner owns cleanup. Local development continues to select the operator's SDK.

The cost is extra cold provisioning: these two jobs stop reusing the image's
preinstalled platforms/build tools. Packages can be reused within the job, but
this change adds no cross-job SDK cache. It does not promise fewer total SDK
downloads or a faster job. Hosted setup time and actual downloads belong in the
review PR alongside the successful checks. This is a scoped accommodation for
the selected action/runner/Toolchain package-layout contract; its simplification
conditions are recorded below.

The public repo still delegates Android build/bootstrap to Toolchain. No package
metadata is fabricated, no installed runner directory is removed, and no private
Toolchain state is modified. The standard package operation owns installation.

## Source review and rejected smaller configuration

[setup-android 4.0.4](https://github.com/android-actions/setup-android/blob/v4.0.4/action.yml)
is the current `v4` implementation. Its
[documented package input](https://github.com/android-actions/setup-android/blob/v4.0.4/README.md#additional-packages)
defaults to `platform-tools`; its installer extracts numbered command-line tools
but does not register a `latest` package itself. Its source still invokes
`sdkmanager` for license acceptance and package installation.

Toolchain 0.13.0's [provider](https://github.com/JetBrains/kotlin-toolchain/blob/v0.13.0/sources/android-integration/amper-android-sdk-provisioning/src/org/jetbrains/amper/android/sdk/provisioning/AndroidSdkProvider.kt)
looks for the exact `cmdline-tools/latest` path and reads its `package.xml`.
A missing file triggers a warning and remote repair. A valid package registered
elsewhere does not satisfy this exact-path request.

The earlier [hosted Android test job](https://github.com/Mekate-Studio/Mobi/actions/runs/43487667862/job/132100422563)
passed 94 tests while emitting two SDK-manager deprecation warnings and a
missing-`package.xml` warning followed by a command-line-tools download.
A private missing-metadata control reproduced the latter and passed all 94 tests.
It used the installed host's tools 23 rather than the image's older tools 16;
this reproduces the metadata failure precondition, not every image byte.
Only the private copy's XML was removed.

Requesting the package in that already occupied SDK was insufficient:
`sdkmanager` exited zero but installed a registered package into `latest-2`.
The required `latest/package.xml` was still absent. This result was rejected;
exit zero alone did not qualify the candidate. A clean SDK creates the correctly
registered `cmdline-tools;latest` package at the expected path, without a repair
script or a directory-removal rule.

## Native Android CLI and license handling

Google documents [`android sdk`](https://developer.android.com/tools/agents/android-cli/commands/sdk)
as the successor to deprecated `sdkmanager`. Android CLI **1.1.16919734** was
inspected using its supported private `ANDROID_USER_HOME`; its SDK install help
matches the published package-management commands. That launcher downloads its
client before displaying help. It is **not adopted or pinned by this change**.
Replacing the action's SDK-manager calls would require a separately qualified
CLI installation/version and license flow. The action's deprecation warnings
remain visible; no filtering or suppression is added.

The action's existing license-acceptance input/default is unchanged. Its CI
operator still authorizes that behavior. Local rehearsals used copied existing
host license receipts and closed standard input; they accepted no new license.
They are not empty-host license evidence. The job-owned hosted SDK must start
empty and exercise the actual action's normal license/setup flow before hosted
qualification is claimed. Repository smoke commands continue not to grant license
acceptance for local users.

## Local qualification and limits

The candidate started with only bootstrap command-line tools and existing license
receipts. The standard package operation installed platform tools and the latest
command-line tools. Toolchain then supplied its required platform/build tools.
The registered package set is recorded in the [compact receipt](2026-11-14-android-sdk-provisioning.json).
The baseline and candidate API 37 platform JARs have identical SHA-256 identities.

| Run | Result | Missing-metadata warning / Toolchain tools repair download |
| --- | --- | --- |
| Unchanged app, private SDK missing `latest/package.xml` | 94 Android/shared tests pass | Present / one download |
| Candidate, registered job-owned SDK | 94 tests pass | Absent / none |
| Candidate Debug build | Pass | Absent / none |
| Second build in the same SDK | Pass | Absent / none |
| Repeat package operation | Pass; expected path remains registered | No alternate-directory warning |

These runs reuse privately seeded dependency/bootstrap caches and candidate app
outputs. Different SDK seeds and diagnostic scope prevent a controlled performance
comparison. Existing delegated Gradle versions and download behavior are unchanged.
Normal exact-staged Android/iOS jobs and hosted results are recorded in the PR;
neither this local SDK rehearsal nor the workflow edit alone establishes hosted
license parity or signed-delivery readiness.

## Simplification and remaining work

On setup-action, Android CLI/SDK tools, runner-image or Toolchain updates:

- Recheck the image SDK and action's package-registration behavior. Try the normal
  image root again when it has valid metadata at Toolchain's required path; remove
  the private-root overrides only after cold/warm tests and Debug builds pass
  without metadata repair, alternate install paths or changes to license policy.
- Remove the explicit command-line-tools package input when supported setup
  supplies that registered package itself and the same checks pass. Root isolation
  and package registration can qualify independently.
- Revisit deprecation when a maintained setup path uses the documented Android
  CLI. Review exact versions, input flags, license handling and installation cost;
  preserve delegated Android bootstrap and actual smoke tests.
- Port only qualified behavior to other workflows through their own validation.
  Release credentials/signing, nightly execution and dependency-review jobs are
  outside this first two-job slice.

These are manual update-review checks, not automatic release discovery or removal.
SDK-manager deprecation and unqualified workflow surfaces remain open under
[WARN-09](../compiler-warning-follow-ups.md#warn-09-job-owned-sdk-metadata).
Recovery restores the two original setup-action steps and their image SDK roots.
