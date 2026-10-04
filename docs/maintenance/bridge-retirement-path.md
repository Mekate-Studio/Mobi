# Path to retiring the hand-maintained iOS Gradle bridge

Date: 2026-10-04. Toolchain 0.13.0 is adopted locally under the
[bounded risk/age decision](toolchain-adoption-risk-review.md). The retained bridge is locally validated;
bridge retirement remains deferred. Xcode continues owning the native app/test
targets, Swift packages and native presentation. Accepted ADRs 0003 and 0006
remain in force; [ADR 0007](../adr/0007-direct-ios-transition-requires-capability-evidence.md)
is a proposed transition decision.

## Relationship to dependency maintenance

This is an independent capability track within the same
`discover → assess → rehearse → review → adopt → integrate` workflow.
It reuses the repository-owned executor, isolated copies/caches, source and
command hashes, baseline-first checks, explicit failures, recovery and cleanup.
Manual `direct-facade`, `direct-roundtrip`, graph-only `direct-resolution` and
bounded `direct-build-inputs` profiles exist, with a source-bound `review-advisories` command. No private
infrastructure or mandatory AI access is required.

A dependency upgrade can improve the retained bridge without qualifying a
direct path. Conversely, a direct candidate must have its own exact release,
resolution, plugin, advisory and support-policy assessment. The existing
scheduled watch discovers bounded dependency leads and measures bridge
compile/link; it does not automatically discover or qualify every standalone
interop alternative, close the retirement matrix, switch defaults or delete
the bridge. Passing checks never grants adoption authorization.

## What has already been measured

The earlier direct typed-facade experiment used Toolchain 0.12.2 / Kotlin 2.4.10
and Metro 1.1.1. With `gradle-bridge/` removed from its isolated build copy, it
preserved native targets/tests and exercised shared DI and all four mobile jobs.
The [round trip](tenth-slice-validation.md) also proved one changed Kotlin value
reached Swift with warm caches, changed framework bytes, and exact restoration
of the original bridge source/modes followed by rebuilt native consumers.
Those are bounded local measurements, not complete retirement evidence.

The [adopted retained-bridge tuple](bridge-adoption-validation.md) uses Metro
1.4.5, bridge Kotlin 2.4.20 and SKIE 0.10.15. Its passing bridge jobs do not prove
the direct tuple. Direct profiles inherit the caller's reviewed baseline pins;
a new run now uses Metro 1.4.5. Old receipts remain evidence only for 1.1.1. The
[current-tuple assessment](direct-current-assessment.md) now passes the bounded
simulator/incremental/restoration profile; the
[direct resolution assessment](direct-resolution-assessment.md) separately
verifies module/target graphs and 305 named Maven advisory queries. The
[selected build-input assessment](direct-build-input-assessment.md) now proves
bounded compiler paths/hashes and delegated Android debug/build-tool inputs.
The [compiler attribution follow-up](compiler-plugin-assessment.md) now joins
both selected plugin files to resolver components. The [advisory review](direct-advisory-triage.md)
records owners, affected conditions and remediation constraints for 17 matches;
none is waived. General artifact attribution and wider retirement gates remain open.

## Remaining path

| Stage | Required evidence and decision |
| --- | --- |
| 1. Refresh the exact direct tuple | The fresh Toolchain 0.13.0 + Kotlin 2.4.20 + Metro 1.4.5 round trip, selected build-input pair and compiler-plugin attribution passed. A fresh 549-query review retains 17 known findings. The [current assessment](direct-adopted-toolchain-assessment.md) records exact artifact joins and remaining coverage gaps. |
| 2. Review interop and behavior | Decide whether the typed facade is an acceptable public architecture or a supported upstream equivalent is preferable. Preserve sealed Kotlin truth, exhaustive Swift state adapters, typed payloads, DI/compiler plugins and Compose resources. Characterize cancellation, failure and lifecycle behavior; use a bounded generic-export fixture. No SKIE compile or Swift-export announcement substitutes for those checks. |
| 3. Prove supported native and release surfaces | Execute app/test targets, both test plans and required macro handling; cover ARM device builds and the declared minimum-OS window. Validate release configuration, archive layout/resources/minimums and export/signing appropriate to the claim. A simulator debug build is not distributable packaging evidence. |
| 4. Prove onboarding and hosted operation | Exercise the public clean-clone instructions and cold supported hosted jobs with the bridge unavailable. Preserve Xcode ownership, Swift package resolution, Android regressions, incremental evidence, failure reporting and cleanup. A fresh copy on a prepared host is insufficient onboarding proof. |
| 5. Review a reversible direct-default patch | Close the applicable capability matrix, present architecture/API and support implications, exact changes and rollback, then obtain explicit maintainer approval. Integrate a small direct-default change while retaining the recoverable bridge and validate the integrated path. Default switching is separate from physical deletion. |
| 6. Remove the bridge separately | After complete parity and successful approved integration, review a distinct removal patch covering obsolete bridge files, callers, bootstrap, documentation and packaging. Retain the exact prior revision needed to restore the bridge, prove restoration and rerun consumers. Obtain explicit approval before deletion. |

## Current-tuple round-trip acceptance

Use the existing profiles on an isolated source snapshot of the adopted tuple;
no new schedule or production transition is needed:

```sh
./scripts/dev/dependency_updates.sh prepare-kotlin
./scripts/dev/dependency_updates.sh rehearse-compatibility direct-roundtrip --store direct-current
# For the returned run ID, use this same store for recover, cleanup and report.
```

Acceptance: the current bridge baseline passes; the direct stages contain no
hand-maintained bridge or stale framework products; original native tests and
targets survive; shared DI/plugins compile; the changed Kotlin probe reaches
Swift; original source bytes/modes and bridge consumers are restored; evidence
chains verify; recovery and cleanup complete. The reviewed exact direct graph
and advisories remain separate evidence requirements, because the round-trip
profile does not provide the full bridge-review graph collector for a direct
candidate. Device/release/lifecycle/generic/onboarding/hosted cells remain open
until independently executed.

Missing sources/capabilities are `incomplete`; provider/setup uncertainty is
`inconclusive`; a causal candidate failure after a passing baseline is
`incompatible`; source drift refuses the result. Recovery or cleanup failure
cannot become an adoption-ready pass. Report verified facts, assumptions and
blockers separately before proposing the next small implementation.

The bounded [selected build-input proof](direct-build-input-assessment.md) is now
measured. Its [attribution follow-up](compiler-plugin-assessment.md) closes the measured
plugin-file coordinate gap, and [bounded advisory triage](direct-advisory-triage.md)
records the discovered build-tool owners and conditions. The next dependency
work is an owner-supported remediation rehearsal with actual delegated graphs
and fresh advisory comparison. It does not advance to a default-switch proposal. Native behavior,
release, onboarding and hosted proof remain independent later gates.

The historical [Toolchain 0.13.0 adoption-gate assessment](toolchain-adoption-assessment.md) measured retained-bridge native/runtime, unsigned release/archive and selected plugins. The later [approved local adoption](toolchain-adoption-risk-review.md) applies matching pins and records the scoped exception. Its fresh `adoption-direct` run `96942bc52fc76b115913cf5011cc6bf4` passes the current direct round trip with the bridge unavailable during direct stages, then restores exact source/modes and rebuilds consumers. This closes the local simulator/incremental/rollback cells for 0.13.0; device, lifecycle, generic, release, onboarding and hosted cells remain open. No default switch or physical deletion is approved by these checks.
