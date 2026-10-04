# Direct iOS incremental and bridge-restoration assessment

This manual slice-10 profile extends the [compatibility runner](compatibility-runner.md). Its original measurement assessed the typed-facade experiment with Toolchain 0.12.2 and Metro 1.1.1. The profile inherits current baseline pins, so a new run now assesses Metro 1.4.5; the [current-tuple assessment](direct-current-assessment.md) now records a passing bounded local round trip. See the [retirement path](bridge-retirement-path.md). It does not adopt the separate Kotlin/Metro/SKIE bridge-upgrade tuple. Production defaults, native targets/tests, OS/architecture policy and release jobs remain unchanged. The [proposed transition ADR](../adr/0007-direct-ios-transition-requires-capability-evidence.md) leaves ADRs 0003/0006 accepted.

## Commands and prerequisites

Use the public setup documented in the root README: Apple Silicon macOS, Xcode and a supported simulator, Android SDK, JDK 21 and the pinned repository Ruby. No private account, AI service or new schedule is required.

```sh
./scripts/dev/dependency_updates.sh prepare-kotlin
./scripts/dev/dependency_updates.sh rehearse-compatibility direct-roundtrip --store direct-roundtrip
./scripts/dev/dependency_updates.sh recover RUN_ID --store direct-roundtrip
./scripts/dev/dependency_updates.sh cleanup RUN_ID --apply --discard --store direct-roundtrip
./scripts/dev/dependency_updates.sh compatibility-report RUN_ID --store direct-roundtrip
```

Use the matching store. A failed/interrupted run retains evidence and resource ownership. Inspect recovery before deleting owned workspaces; uncertain ownership refuses cleanup. `--discard` discards only owned disposable work/caches after quiescence, retaining immutable evidence. Do not edit source or implementation files during a run; drift invalidates the result. Reporting after cleanup avoids its held lease.

## Named stages

The unchanged baseline compiles/links the retained bridge and runs all four existing mobile jobs. The candidate starts from a fresh owned source copy/home/cache on the prepared host. It removes `gradle-bridge/` from its build copy, adds shared DI reachability, installs the managed Xcode integration phase and uses the slice-7 typed projections. Checked-in native tests, targets, scheme and test plans survive.

The candidate adds two isolated probe files: a Kotlin object returning `slice10-before`, and a Swift Testing assertion expecting that value. These files are test fixtures; they do not enter production source or encode domain state as strings. Initial Android/shared tests and native test/debug builds run through existing jobs. Native evidence must include all original cases and the probe.

The incremental stage changes only the Kotlin return and native expectation to `slice10-after`, retaining caches and generated products. It reruns iOS tests and the debug build. A stale Kotlin framework fails the new Swift expectation. Framework identities before/after must exist and change; byte differences alone are insufficient without the native consumer. Source changes and cache policy have separate receipts. This is one bounded implementation-invalidation probe, not exhaustive incremental-build coverage or a performance benchmark.

Before restoration, every expected authored input and its mode/path boundary is checked. Drift, unexpected source, symlinks or early bridge reappearance refuses restoration. The helper restores original bytes/modes, removes facade/probe additions and clears the owned `build/` products. It then runs bridge iOS tests/debug build and records newly produced framework identities. The original source manifest must match exactly. This tests a reversible content transition in the owned copy; an environment-variable toggle alone is not claimed as rollback.

## Reading evidence

`compatibility-report` verifies result/journal/check/log/reference hashes, required stage cells, original/probe native cases, the two-file mutation, framework changes and restored source identity. Only a complete paired pass closes `incremental_direct_build` and `local_bridge_rollback` for the candidate/overall local assessment. The unchanged baseline lane retains its unmeasured direct gaps. Missing or altered evidence cannot become a pass through a nominal executor status.

`bridge_unavailable` and the candidate's shared-DI reachability in this profile describe the direct stage before restoration; the final owned copy intentionally has its baseline bridge restored. Historical direct-facade receipts keep their original scope. The evaluator never sets adoption authorization and never switches the caller's default.

## Measured local result

The [2026-10-02 paired assessment](tenth-slice-validation.md) and [public receipt](evidence/2026-10-02-slice-10.json) record a passing baseline, initial direct native checks, changed-probe native checks, exact bridge restoration and rebuilt bridge consumers. Original Swift cases number 12; both direct stages run those cases plus the probe. Three same-path framework binaries changed. Recovery and cleanup completed. Only bounded local incremental and bridge-restoration gaps close; the next section remains applicable.

## Remaining transition gates

Physical-device and minimum-floor execution, release configuration/archive/export, signed packaging, generic export, cancellation/lifecycle parity, true clean-clone onboarding and cold hosted direct CI remain independent gates. A fresh local snapshot on a prepared host is not a new-machine onboarding result. The typed-facade API still needs architecture review. Current build-tooling advisory findings from [slice 9](ninth-slice-review.md) remain visible and are not cleared by these builds.

The full retirement matrix and a named maintainer decision must precede any default or removal patch. The independent dormant Elixir profile adds no prerequisites to this mobile path. The [slice-10 validation record](tenth-slice-validation.md) separates implementation checks from actual native measurements and outstanding gates.

The [Metro 1.4.5 follow-up](direct-current-assessment.md) records fresh current-tuple evidence; the earlier Metro 1.1.1 receipt remains unchanged.
