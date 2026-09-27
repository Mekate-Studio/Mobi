# Sixth slice: Kotlin Toolchain rehearsal

Later decision (2026-09-27): the validated ARM target migration and Toolchain
0.12.2 were approved for local adoption. The separate
[support-policy validation](support-policy-validation.md) records the new explicit
OS minimums. This report retains the original wrapper-only comparison and failures.

Status: implemented locally on 2026-09-27; uncommitted for review.
Base commit: `7e9e8f83c035c88b71fa0feaafd9f334657b3f84`.
OpenSpec change: `kotlin-toolchain-rehearsal`. See the
[command guide](kotlin-rehearsal.md) and
[source-bound receipt](evidence/2026-09-27-slice-6.json).

## Verified implementation

The existing maintenance front door now prepares reviewed consumer wrappers and
runs independent Kotlin `inputs` and `mobile` profiles. The common executor adds
a small resource-handler interface and typed refusal for authored input drift.
Kotlin owns its native lifecycle implementation. The independent Elixir fixtures
continue to run without Kotlin or native tooling; its production profile remains
dormant. No workflow, schedule, dependency pin, native target, Swift adapter or
release default changed.

The source-bound baseline precedes candidate allocation. Candidate edits replace
only the two wrappers; strict source snapshots remain separate from generated
build copies. Each phase has private HOME, bootstrap/dependency/Gradle/Native
caches, temporary output and Android SDK copy. The existing four native jobs run
with the Gradle bridge selected, an owned simulator and explicit validation flags.
Results retain raw diagnostics, effective settings, printed resolved graphs,
artifact hashes, missing capabilities and immutable original outcomes.

Native recovery records intent before creation. Real Toolchain delegated Gradle
daemons omitted the requested JVM tag because Tooling API overrides the JVM
options. The adapter now verifies their exact classpath under the nonce-bound
private Gradle distribution, hashes its daemon artifact, and rechecks live
uid/PID/start/group identity before signaling. Unknown ownership refuses cleanup.
An owned simulator is identified by unique name, runtime and device identity;
Xcode test clones require its exact nonce-bearing base name and runtime;
unconfirmed creation blocks deletion. Coordinator loss uses the same handler.
This protocol is not an OS sandbox against malicious same-user processes.

## Measured checks

Host: Apple Silicon, macOS 27.0 build `26A428`. The public command and integrated
contracts use pinned Ruby 4.0.6; the focused suite also passed under system Ruby
2.6.10. Xcode and native environment details are recorded in the receipt.

| Check | Result |
| --- | --- |
| Existing `quality-contracts` job | 130 passed: 35 static-tool, 27 pre-commit, 23 inventory, 27 executor and 18 Kotlin rehearsal contracts |
| Kotlin contracts under system Ruby | 18 passed, zero failures |
| Existing static gate | All five analyzers passed; 5.334 seconds total |
| Ruby syntax, strict OpenSpec and whitespace | Passed |
| Input profile | Both versions passed; final phases 42.916 s / 29.898 s |
| Mobile profile | All four baseline jobs passed; candidate Android test command failed target resolution (see below) |
| Recovery / explicit disposable-workspace cleanup | Ten completed runs quiescent and cleaned; original results and logs retained |

The focused contracts cover reviewed wrapper bytes and age, line-ending and UTF-8
normalization, settings/graph format drift, missing scopes, unresolved nodes,
conservative failure classification, authored-source mutation, detached JVMs,
TERM-resistant children, coordinator loss, unrelated registry PIDs, exact private
classpath proof, simulator mismatch and unconfirmed creation. Simulator failure
paths use deterministic fixtures; the real probe supplies normal native-resource
evidence. The follow-up CoreSimulator probe verifies real booted-clone shutdown
and deletion after both completion and timeout. There is no claim that every
failure was injected into Xcode itself.

### Effective input comparison

The final-code input capture resolves all seven declared modules. Values below
are measured CLI output, not an inference from the upstream defaults:

| Surface | Baseline 0.11.1 | Candidate 0.12.2 |
| --- | --- | --- |
| Effective Kotlin setting | 2.3.21 | 2.4.10 |
| Effective Compose setting | 1.10.3 | 1.11.1 |
| Compile JDK / JVM release setting | 21 | 25 |
| Android app min / compile / target SDK | 23 / 36 / 36 | 23 / 36 / 36 |
| Explicit build-tools setting in CLI output | Absent | 37.0.0 |
| Metro compiler declaration | 1.1.1 | 1.1.1 |
| Printed graph roots | 104 | 102 |
| Toolchain `ios-app` platforms | Arm64, simulator Arm64, x64 | Arm64, simulator Arm64 |
| Shared library explicit iOS platforms | Arm64, simulator Arm64, x64 | Arm64, simulator Arm64, x64 |

The bootstrap runtime is separate from the compile-JDK setting: both wrappers
reported CLI runtime `25.32.21`; native helpers selected host JBR 21.0.11.

The two lost roots are the app's x64 main/test compile roots. Grouped app roots
also lose x64. This does not remove any Xcode or bridge target: those files were
held constant and the bridge remains selected. It is material evidence for the
separate direct-path architecture assessment.

Declared and selected dependencies also differ within a phase. For example,
baseline Android diagnostics report Compose runtime 1.10.3 selected as 1.11.1 and
lifecycle runtime Compose 2.9.4 selected as 2.11.0-beta01. The retained graph keeps
requests, selected coordinates, edges and repeated-branch references. Neither a
declaration nor an upstream default is presented as complete resolution proof.
Compiler settings and downloaded artifact hashes remain distinct from proof of
every compiler/Native invocation.

### Native outcome

The baseline passed Android/shared tests (259.941 s), Android debug build
(47.231 s), iOS PullRequest tests (296.022 s) and iOS debug build (62.373 s).
The iOS log records twelve passing native test cases. The retained Gradle bridge
uses its unchanged Kotlin 2.3.20 / Compose 1.9.0 / SKIE 0.10.12 stack.

Candidate input capture passed, then `android-test` exited 1 after 210.595 s.
Toolchain reported that `shared-ui-home` could not resolve its dependencies:
Compose foundation 1.11.1 and Material3 1.11.0-alpha07 do not support its declared
`iosX64` platform. Gradle 9.5.0 reported a successful delegated build, but the
Toolchain command failed overall. Later candidate Android packaging and iOS jobs
were not attempted. The baseline used delegated Gradle 8.14.3; bridge Gradle
9.6.1 is a separate stack. Both phases' owned simulators were removed.

The original executor result is **inconclusive**, because the first conservative
classifier did not recognize this dependency-target diagnostic. It is preserved
byte for byte. The final classifier recognizes that exact diagnostic, including
when a CLI continues compiling another platform. Replaying all retained baseline
and candidate logs produces a separate **incompatible diagnostic assessment**:
baseline passes and the candidate's unsupported-target error fails. This is a
source-bound reassessment, not a replacement result or a new full native run.

The two changes after that native run are the diagnostic classification and
recovery of Xcode test clones. Final contract tests cover both; a real
CoreSimulator probe exercises normal completion and a timeout with an owned base
and booted clone. A final input profile binds the final implementation. The full
four-job native comparison has not been repeated after these two fixes. Exact
before/after implementation hashes and the separate probes are in the receipt.

### Failures found while developing the adapter

The earlier bootstrap/lifecycle probes remain evidence of adapter defects, not
candidate regressions:

- Upstream Windows wrapper CRLF versus repository LF initially refused the
  baseline. Verify official bytes, then normalize only the owned copy.
- Binary versus UTF-8 wrapper strings caused a plan comparison refusal; the
  clean C locale then exposed an encoding assumption. Explicit UTF-8 fixed both.
- Unicode simulator output failed JSON parsing under the clean locale before
  device creation. Read `simctl` output as UTF-8.
- A real Tooling API daemon lacked the requested tag. The run stopped rather
  than guessing ownership; recovery removed its verified simulator. The private
  classpath proof is now covered by fixtures and actual daemon observations.

All original outcomes and logs are retained. A later successful recovery never
rewrites an earlier executor failure as success.

## Untested assumptions and limits

- Slice 6 has local Apple Silicon evidence only. Its hosted, Intel macOS and Linux
  behavior is unverified. Slice 5's exact commit passed all seven hosted jobs in
  [run 36257552549](https://github.com/Mekate-Studio/Mobi/actions/runs/36257552549);
  that receipt does not certify these later edits.
- Printed Toolchain Maven graphs are not complete bridge target graphs. The
  parser checks declared modules and main/test compile/runtime presence, while
  full target completeness, repeated-branch expansion and actual compiler/Native
  provenance remain assessment gaps.
- Only reviewed versions 0.11.1 and 0.12.2 are parsed. A future version needs a
  reviewed manifest entry and output-format evidence. SDK/tool installations are
  host prerequisites; cache isolation does not create a fully hermetic machine.

## Blockers to adoption and bridge retirement

The Toolchain-only 0.12.2 candidate fails dependency resolution for the preserved
shared-library `iosX64` target. Later candidate packaging and iOS checks remain
unexecuted. Do not drop that target or claim complete Metro/compiler compatibility
from the partial successful Android compilations. A coordinated retained-bridge
assessment must resolve this blocker explicitly.

Fresh authenticated provider/advisory evidence, full migration-interval review,
complete target/compiler graphs, signed archive/export packaging and cold hosted
onboarding are still required before adoption. `checks_passed` does not close
these gaps. There is no known blocker to reviewing this rehearsal adapter itself.

Bridge retirement has its own open matrix: no direct Toolchain iOS experiment ran
with the bridge unavailable. Native targets/tests, sealed-state adapters, plugins,
cancellation, architectures and release products still require parity evidence.

## Next small slice

Review this adapter and its evidence before integration. Slice 7 should consume
its source-bound records in the existing compatibility matrix, beginning with one
explicit retained-bridge candidate set and native graph/artifact checks. Keep
that work separate from a bounded direct-path experiment. Acceptance requires
baseline-first outcomes, preserved native targets/tests and Swift adapters,
precise missing-evidence states, recovery of only verified resources and a
reproducible public command. No automatic upgrades or new schedules are needed.
