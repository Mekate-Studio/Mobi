# Path to retiring the hand-maintained iOS Gradle bridge

Date: 2026-10-02. The retained-bridge upgrade is adopted and locally validated;
bridge retirement remains deferred. Xcode continues owning the native app/test
targets, Swift packages and native presentation. Accepted ADRs 0003 and 0006
remain in force; [ADR 0007](../adr/0007-direct-ios-transition-requires-capability-evidence.md)
is a proposed transition decision.

## Relationship to dependency maintenance

This is an independent capability track within the same
`discover → assess → rehearse → review → adopt → integrate` workflow.
It reuses the repository-owned executor, isolated copies/caches, source and
command hashes, baseline-first checks, explicit failures, recovery and cleanup.
Manual `direct-facade` and `direct-roundtrip` profiles already exist. No private
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
a new run now uses Metro 1.4.5. Old receipts remain evidence only for 1.1.1.

## Remaining path

| Stage | Required evidence and decision |
| --- | --- |
| 1. Refresh the exact direct tuple | Reproduce the current retained-bridge baseline, then run the direct facade/round trip on Toolchain 0.12.2 + Kotlin 2.4.10 + Metro 1.4.5 with the hand-maintained bridge unavailable. Capture exact selected dependencies/compiler plugins and fresh primary/advisory/support evidence. Preserve failures instead of inheriting the older pass. |
| 2. Review interop and behavior | Decide whether the typed facade is an acceptable public architecture or a supported upstream equivalent is preferable. Preserve sealed Kotlin truth, exhaustive Swift state adapters, typed payloads, DI/compiler plugins and Compose resources. Characterize cancellation, failure and lifecycle behavior; use a bounded generic-export fixture. No SKIE compile or Swift-export announcement substitutes for those checks. |
| 3. Prove supported native and release surfaces | Execute app/test targets, both test plans and required macro handling; cover ARM device builds and the declared minimum-OS window. Validate release configuration, archive layout/resources/minimums and export/signing appropriate to the claim. A simulator debug build is not distributable packaging evidence. |
| 4. Prove onboarding and hosted operation | Exercise the public clean-clone instructions and cold supported hosted jobs with the bridge unavailable. Preserve Xcode ownership, Swift package resolution, Android regressions, incremental evidence, failure reporting and cleanup. A fresh copy on a prepared host is insufficient onboarding proof. |
| 5. Review a reversible direct-default patch | Close the applicable capability matrix, present architecture/API and support implications, exact changes and rollback, then obtain explicit maintainer approval. Integrate a small direct-default change while retaining the recoverable bridge and validate the integrated path. Default switching is separate from physical deletion. |
| 6. Remove the bridge separately | After complete parity and successful approved integration, review a distinct removal patch covering obsolete bridge files, callers, bootstrap, documentation and packaging. Retain the exact prior revision needed to restore the bridge, prove restoration and rerun consumers. Obtain explicit approval before deletion. |

## First next assessment

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
