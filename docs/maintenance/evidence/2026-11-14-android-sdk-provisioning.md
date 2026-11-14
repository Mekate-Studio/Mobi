# Android SDK provisioning: WARN-09 — 2026-11-14

The two main Android smoke jobs now set the existing setup action's documented
`packages` input to an empty string. The action keeps its command-line bootstrap
and license flow; Toolchain provisions the SDK packages required by the actual
Android tests and Debug build. The final executable patch adds **four YAML lines**.
The image SDK selection, application code, dependency pins, SDK floors and
Toolchain's delegated Android Gradle bootstrap stay unchanged.

Base: `7c1aaacfb889d9a654415311cbf9d03b3081725c`, merged PR #105. This removes the
action's redundant default `platform-tools` installation call. It does not remove
the remaining `sdkmanager --licenses` deprecation or Toolchain's repair of an image
SDK whose `latest/package.xml` is missing. WARN-09 remains **partially open**.
No private-root override, metadata patcher, directory deletion rule, custom SDK
installer or SDK cache is added. Other workflows retain their existing setup.

## Package ownership and supported configuration

[setup-android 4.0.4](https://github.com/android-actions/setup-android/blob/be39fa834029ff78f1a44aa3bb0819b8fc2bd8fd/action.yml)
is the reviewed `v4` implementation. Its [documented package input](https://github.com/android-actions/setup-android/blob/be39fa834029ff78f1a44aa3bb0819b8fc2bd8fd/README.md#additional-packages)
defaults to `platform-tools`; an empty string skips additional package installs.
Bootstrap command-line tools and the default license-acceptance step still run.
The action exports its normal SDK environment and adds tool locations to PATH.

The action source invokes `sdkmanager` once for licensing and once per requested
package. Disabling the default package removes one invocation; the remaining
license call still emits the upstream deprecation. This change does not update
platform tools merely because a CI job starts. Toolchain remains responsible for
its requested SDK packages. Build/test scope is qualified here; device/emulator,
nightly, dependency-review and release jobs require their own task/dependency checks
before this configuration is applied to them.

Toolchain 0.13.0's [SDK provider](https://github.com/JetBrains/kotlin-toolchain/blob/v0.13.0/sources/android-integration/amper-android-sdk-provisioning/src/org/jetbrains/amper/android/sdk/provisioning/AndroidSdkProvider.kt)
provisions the platform, build tools, platform tools and command-line tools needed
by these paths. Its [noninteractive license handler](https://github.com/JetBrains/kotlin-toolchain/blob/v0.13.0/sources/amper-cli/src/org/jetbrains/amper/android/AndroidTerminalLicenseHandler.kt)
refuses unaccepted licenses. Keeping the existing setup action preserves the CI
operator's existing license flow; Toolchain-only empty-host setup is not assumed.
Local smoke commands still do not grant license acceptance.

## Actual tests and the smaller final choice

The [retained hosted baseline](https://github.com/Mekate-Studio/Mobi/actions/runs/43487667862/job/132100422563)
passed 94 tests on image `20261102.0473.1`, with two SDK-manager deprecations and
one missing-metadata warning followed by a Toolchain tools-repair download. A
private control reproduced that metadata precondition and passed all 94 tests.
It used host tools 23 rather than the image's tools 16; only the private copy's
XML was removed. It is not byte-for-byte reproduction of the image SDK.

Two alternatives were evaluated before selecting the four-line patch:

- Requesting `cmdline-tools;latest` in the damaged SDK returned zero but installed
  `latest-2`, leaving Toolchain's required exact `latest/package.xml` path absent.
  That result was rejected; successful process exit alone was insufficient.
- A registered job-private SDK passed the local suite/builds and hosted Android
  jobs in [CI #698](https://github.com/Mekate-Studio/Mobi/actions/runs/43582000313).
  On the same image it removed the metadata warning, but added platform/build-tools
  downloads and increased SDK-manager deprecations from two to three. Setup steps
  took 14/15 seconds versus 11 seconds in the retained baseline; these step times
  are not a controlled total-job performance comparison. That private-root/package
  configuration is **not adopted** by the final patch.

The final bootstrap-only configuration was then exercised with a private SDK
containing only bootstrap tools and existing license receipts. No platform, build
tools, platform tools or `latest` package was preinstalled. Toolchain supplied
all four required package groups. The actual suite passed **94 tests**, followed
by a successful Debug build and warm rebuild. The registered package set and
raw receipt identities are in the [compact receipt](2026-11-14-android-sdk-provisioning.json).

A fresh SDK directory needs ordinary initial package downloads. An occupied image
SDK with missing metadata still needs Toolchain repair; this change preserves
that existing behavior and warning. The final hosted image-root/license-flow
checks, complete staged gate and actual warning counts are recorded in the PR.
The earlier private-root run is comparison evidence, not final-head qualification.

## Native Android CLI and qualification limits

Google documents [`android sdk`](https://developer.android.com/tools/agents/android-cli/commands/sdk)
as the successor to deprecated `sdkmanager`. Android CLI **1.1.16919734** was
inspected with its supported private `ANDROID_USER_HOME`; the launcher downloads
its client before displaying help. It is not adopted or pinned here. Replacing
the action's remaining license call needs a separately qualified CLI/version and
license path. No warning filter or suppression is introduced.

Local SDK rehearsals copied existing host license receipts and used closed input;
they accepted no new license and do not prove empty-host license acceptance. The
hosted action retains the existing operator-authorized input/default. Seeded
download caches, reused app outputs and differing SDK states preclude performance
or total-bandwidth claims. Package pins and the delegated Gradle machinery are
unchanged; metadata repair and other workflow surfaces remain open. Signed/device
acceptance and complete tooling security coverage are separate scopes.

## Update checks and recovery

On setup-action, Android CLI/SDK tools, runner-image and Toolchain updates:

- Recheck actual package ownership and defaults. Keep an explicit empty input
  while additional action installs duplicate Toolchain's requirements; remove or
  adjust it only when supported setup behavior and actual tasks justify doing so.
- Requalify the remaining license call when a maintained path uses native Android
  CLI or Toolchain gains an appropriate noninteractive operator-approved flow.
  Preserve license policy and actual cold/warm tests/Debug builds.
- Inspect the image metadata and Toolchain's exact-path behavior. Close the
  metadata warning only after the real image path works without repair; a private
  SDK or a hand-written XML file does not establish that closure.
- Qualify additional workflow/task surfaces independently. Do not infer device,
  emulator or signed-delivery SDK requirements from these two smoke jobs.

These are manual review checks, not automatic discovery or a new interop
workaround. Recovery removes the two empty `packages` inputs to restore the
action's previous defaults. [WARN-09](../compiler-warning-follow-ups.md#warn-09-sdk-package-ownership)
continues to track the remaining components.
