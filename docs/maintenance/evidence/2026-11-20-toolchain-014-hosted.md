# Toolchain 0.14.0 hosted cache-free qualification — 2026-11-20

This review exercises the existing Mobile CI jobs without their declared
dependency-cache restores. The selected source remains Toolchain **0.13.0**.
The [November 18 exception](2026-11-18-toolchain-014-qualification.md) permits
early qualification of 0.14.0 only; adoption and dependency-risk decisions
remain separate.

## Scope and reproducibility

The optional `cold_cache` dispatch input forces full validation. Before setup,
each build/test/quality job checks that `build`, `.kotlin-cache`,
`.kotlin-user-home`, `.gradle-user-home`, `.quality` and
`ios-app/Dependencies/.build` are absent. Existing files cause refusal and are
preserved. Cache actions and Bundler caching are skipped. Kotlin/Native and
SwiftPM use paths under the fresh job workspace; Xcode receives its supported
`-disablePackageRepositoryCache` and `-packageCachePath` options.

The runner image's SDKs, installed tools and system caches remain available.
This is a bounded dependency-cache check, not a pristine OS, device test or
signed-delivery qualification. See the
[manual command and cache boundary](../../reference/ci-validation.md).

The baseline uses source `5142687465a93fef1f5c687368d186a411f59571`.
The separate [qualification ref](https://github.com/Mekate-Studio/Mobi/commit/681987d9c91ef75488078fc7d74304e332adf7af) adds only
workflow steps that obtain the reviewed published wrappers through the existing
`Maintenance::KotlinWrappers` verifier, then apply their LF-normalized bytes
inside the four native jobs. That ref is qualification configuration and is
excluded from the implementation PR. Quality and policy checks validate the
selected 0.13.0 source in both runs; they do **not** qualify repository-wide
0.14.0 adoption.

## Contract finding

An initial local whole-source 0.14.0 switch exposed declaration fixtures that
copied the caller's new wrapper while retaining their historical assessment.
Those synthetic fixtures now obtain their tuple from their own assessment and
use deliberately nonfunctional wrapper sentinels. Regression controls cover a
caller on a different version. Native jobs execute the actual reviewed wrappers.

Two live-root checks continued to reject the unadopted version after the fixture
repair. Their production refusal remains unchanged. A smoke control applies the
exact native-job overlay and verifies that the production compatibility
assessment still refuses it. No adoption guard was relaxed to obtain a green
comparison.

## Results

The compact [receipt](2026-11-20-toolchain-014-hosted.json) binds the exact refs,
runs, job results, observed tool versions and existing Swift-export artifact.
Both hosted comparisons passed all seven jobs.

| Check | 0.13.0 baseline | 0.14.0 native candidate |
| --- | --- | --- |
| Cache-free workflow | [44804680213](https://github.com/Mekate-Studio/Mobi/actions/runs/44804680213), passed | [44807242881](https://github.com/Mekate-Studio/Mobi/actions/runs/44807242881), passed |
| Android debug / Android and shared host tests | Passed | Passed |
| iOS debug / PullRequest plan | Passed | Passed |
| Empty-root receipts / skipped cache actions | 30 / 5 | 30 / 5 |
| Quality / policy source | 0.13.0, passed | 0.13.0, passed |
| Visible passing native function names | 48 | Same 48 |
| Complete switches / omission controls | 6 passed / 6 rejected | 6 passed / 6 rejected |
| Packaged Kotlin runtimes / Swift-export mode | 1 / enabled | 1 / enabled |
| Strict runtime / coroutine support | Both blocked | Both blocked |

Both native phases used Xcode 26.6 (`17F113`), iPhoneSimulator26.5 SDK and
setup-java's Temurin 25.0.5+8.0. Hosted image revisions differed across jobs;
the receipt records them individually. The local staged gate additionally
observed Toolchain fetching JDK 25.0.5.1+2. Existing major-version selections
still float: these are observations, not new patch pins or security clearance.
This is not a performance comparison.

The two Swift-export reports have the same SHA-256. Actor-boundary controls
remain enforced, both strict-support probes remain blocked, and the coroutine
inheritance diagnostic is still reported. No workaround qualifies for removal
from these results.

The existing formatter prints the 48 nonparameterized function names, but not
the 32 parameterized functions present in the same source and test plan. The
receipt therefore compares the visible name set and the plan outcome; it does
not claim a full hosted parameterized-execution count from this stdout.

The preliminary [baseline run](https://github.com/Mekate-Studio/Mobi/actions/runs/44800306723)
passed all seven jobs before the fixture correction; the corrected-source run
supersedes it for the paired comparison. An initial locale-sensitive text read
in the temporary qualification command was corrected to a byte read and its
local hook restarted before publication; the interrupted attempt is not a pass.

## Remaining decisions

This scope does not close dependency/advisory ownership gaps, warning debt,
minimum-OS or physical-device coverage, production signing or broader delivery.
IOS-10's producer and the existing support/actor workarounds still require their
tracked replacement controls. Qualification success does not authorize adoption,
security acceptance or workaround removal.
