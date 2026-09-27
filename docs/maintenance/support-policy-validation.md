# Support-policy adoption and validation — 2026-09-27

Status: locally adopted in the working tree after explicit maintainer approval
and isolated validation. No commit, push, new schedule or publishing action.

## Decisions and implications

The exact [eight-file ARM migration](evidence/2026-09-27-apple-silicon.patch)
is applied: Kotlin Toolchain 0.12.2, five shared modules with ARM iOS targets,
and the bridge's Intel target/source mapping removed. The reviewed baseline is
now 0.12.2; the candidate allowlist is empty. Historical 0.11.1 receipts and test
fixtures remain available. This follows the already passing
[Apple Silicon assessment](apple-silicon-assessment.md).

The separate three-file OS candidate sets:

| Surface | Measured baseline | Adopted candidate |
| --- | --- | --- |
| Android app minimum | API 23 | API 36 / Android 16 |
| Android compile/target SDK | 36 / 36 | 36 / 36 |
| Swift dependency package minimum | iOS 16 | iOS 26.0 |
| Six Xcode project/app/test configurations | Implicit; built apps resolved to 27.0 | Explicit 26.0 |
| Native test runtime | iOS 27.0 / iPhone 18 Pro | iOS 26.5 / iPhone 17 Pro |

Android versions below 16 and Intel iOS simulators are outside the adopted support
policy. The iOS app gains an explicit iOS 26 floor compared with the measured
SDK-inherited 27 baseline; the previous package declaration did not establish
that the app ran on iOS 16. No bridge compiler/plugin pins, Swift adapters,
shared business behavior, native test targets or release credentials/defaults
changed. The bridge remains the native production build path.

## Verified facts

The [public receipt](evidence/2026-09-27-mobile-support.json) binds the measured
source, exact candidate, implementation/runtime/policy, per-command logs and
artifact hashes. The [reviewed OS patch](evidence/2026-09-27-mobile-support.patch)
and adopted file hashes match the candidate bytes. The executor's technical
result keeps `adoption_authorized: false`; the separate maintainer decision is
recorded here rather than rewriting a test receipt into permission.

Both phases used Toolchain 0.12.2 and passed effective-settings/dependency capture,
Android/shared host tests, Android debug packaging, the 12 native Swift test cases
in the PullRequest plan, and iOS debug packaging. Candidate dependency graphs
retain Android, ARM iOS device and ARM simulator coverage without iosX64.
The Android effective min/compile/target SDK settings matched the declarations.
A separate AAPT2 inspection of both built APKs confirmed baseline minSdk 23 and
candidate minSdk 36, with targetSdk 36 in both; the command/tool/APK hashes are
recorded in the receipt.
Both candidate built app products reported `MinimumOSVersion = 26.0`; both
baseline products reported 27.0. The candidate test runtime was actually iOS 26.5.

All 147 contracts passed under the pinned Ruby runtime. The final five static
analyzers passed after adoption, and strict OpenSpec validation passed all 11
items. Focused system-Ruby
contracts also passed (22 Kotlin rehearsal, 13 support-policy). The suites cover
stale/future/untrusted sources, missing/ambiguous history, Apple major-name jumps,
configurable lag, preview exclusion, malformed API mappings, exact source-bound
edits, configuration coverage and named-store path rejection. Simulator tests
cover choosing a compatible device in the required major and refusing an absent
runtime. The existing executor contracts continue to exercise interrupted runs,
owned resources, process identity and cleanup.

The real pinned inventory recorded 866 components and included support drift plus
an explicit manual architecture-review requirement. Primary release response
hashes and dated metadata are checked in. This is a bounded reviewed release
catalog, not proof that an automated feed discovered every upstream release.

## Investigation and recovery

The first OS rehearsal was deliberately interrupted after discovering that Xcode's
first device type (iPhone 18 Pro) is incompatible with the installed iOS 26.5
runtime. Its result remains `inconclusive`, not a compatibility failure or pass.
Its coordinator was matched against the recorded process identity before signaling;
normal owned cleanup completed and the one disposable baseline workspace was
removed while the journal/results remained.

The selector now intersects available device types with the selected runtime's
supported-device list. An actual isolated create/cleanup probe selected iPhone
17 Pro on iOS 26.5 before the fresh full comparison. The successful comparison
started again from the baseline; it did not reuse the interrupted workspaces.
Its two owned simulators/processes were stopped and both disposable workspaces
were removed after evidence capture. Recovery, dry-run cleanup and applied
cleanup are recorded in the receipt.

The earlier Apple Silicon run store still has a historical host-identity mismatch.
It was not relabeled, moved, deleted or adopted by this host. Its prior executor
recorded stopped resources, but current cross-host cleanup remains blocked. The
new explicitly named store is independent and does not weaken that ownership guard.

## Untested assumptions and remaining gates

- iOS 26.5 and 27.0 are the tested patches. iOS 26.0 and every later patch were not
  executed separately; the declared 26.0 floor is not blanket runtime proof.
- Android host tests/debug packaging do not establish Android device/emulator
  behavior on API 36 or 37. Shared Android tests are not Kotlin/Native common tests.
- Cold GitHub-hosted execution and Linux/Windows onboarding for this exact source
  remain unverified. Slice 5's hosted success is historical and is not reused here.
- Physical iOS devices, unsigned device/Release archives and signed distribution
  packaging remain untested by this support rehearsal.
- Complete bridge target graphs, fresh full advisory assessment and direct
  Toolchain parity with the bridge unavailable remain separate gaps. No claim
  of bridge-retirement readiness follows from this migration.

Public documentation, this receipt and task completion updates follow the frozen
measured source. The adopted app/build files were checked against the exact
validated candidate. The normal staged gate and hosted checks remain integration
steps when a commit/push is separately requested.

## Ongoing workflow and rollback

Follow the [support workflow](mobile-support-policy.md): refresh primary release
history, run `assess-support`/inventory, review architecture/API/support impact,
rehearse exact changes, then obtain the required adoption decision. The default
stable-major lag is configurable per platform and remains one for Mobi. Neither
a new OS release nor successful compilation silently changes source.

OS rollback is the reverse of the separate three-file OS patch, subject to current
file hashes; it restores the historical package/app mismatch and therefore needs
an explicit decision. Toolchain/architecture rollback is independently the reverse
of the eight-file ARM patch with its matching 0.11.1 baseline manifest. Reintroducing
Intel alone with the new Compose artifacts recreates the known incompatibility.
Never reset unrelated work or reuse an old receipt after changing source or tools.
