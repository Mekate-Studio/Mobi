# Direct round trip against the adopted tuple

Date: 2026-10-02. Outcome: **the bounded local round trip passed**; bridge
retirement remains deferred. No production dependencies, interop API, builder
default, target/OS policy, release setting or schedule changed. This assessment
has not been committed or pushed.

## Verified facts

Run `c09c749aa7f7f039d4a8b8fd263f7144` executed from 2026-10-02T18:43:49Z to 2026-10-02T19:16:59Z.
Caller HEAD: `ba8270fabed862ae52a09e918e9803390d0fd8cb`. Frozen working-snapshot identity:
`54c3131eb2fa24df8924543e31c619e457cda1cb018f6fb64a64cf9cd2b34a5c`. The only pre-run caller change was the follow-up
OpenSpec checklist. All frozen caller inputs were preserved; the post-run
receipt was separately identified as a new output before documentation updates.

The bridge baseline uses Kotlin 2.4.20 / Metro 1.4.5 / SKIE 0.10.15 / Compose
1.9.0. The direct candidate uses Toolchain 0.12.2 / Kotlin 2.4.10 / Metro 1.4.5
and the isolated typed facade through regular Objective-C export. Normal age
admission passed with real timestamps and unchanged policy.

| Stage | Measured result |
| --- | --- |
| Retained bridge baseline | Library compilation/linking and all four mobile jobs passed; 38 Android tests and 12 original Swift cases. |
| Initial direct path | Bridge absent in the owned build copy; shared DI reachable; native targets/tests preserved; all four mobile jobs passed, with 38 Android tests and 13 Swift cases including the probe. |
| Incremental direct path | Kotlin return and Swift expectation changed with caches/products retained; all 13 Swift cases and the debug build passed; three framework binaries changed. |
| Restored bridge | Original source bytes/modes restored, additions removed and owned build products cleared; all 12 original Swift cases and the rebuilt debug app passed. |

The [public receipt](evidence/2026-10-02-direct-current-roundtrip.json) binds the
exact source, tuple, commands, logs and references to the verified report.
Bridge absence describes direct stages before restoration; the final owned
copy intentionally restored its bridge. Candidate standalone KLIB/link cells
were not attempted separately; native jobs generated and consumed frameworks.
The probe proves one bounded invalidation case, not exhaustive incremental behavior.

Recovery reported `quiescent`; cleanup reported `cleaned`, removing owned
workspaces/caches and retaining immutable evidence under ignored `.maintenance/`.
An early reporting request was refused while cleanup held its lease; that
refusal was retained. The final report after cleanup verified all receipt chains.

Separately, all seven hosted Mobile CI jobs passed for retained-bridge commit
`ba8270f`, including the Pull request gate. This is retained-bridge integration
evidence, not hosted direct-path evidence.

## Fresh sources and advisory limits

Six primary sources were retrieved and hashed: the Toolchain release, versioned
iOS guide and Xcode manager, versioned Metro compatibility table, Swift-export
guidance and SKIE installation. Metro lists both Kotlin 2.4.10 and 2.4.20 as tested.
Mobi's executed jobs establish the bounded result independently of that table.

[Swift export](https://kotlinlang.org/docs/native-swift-export.html) still documents
Alpha integration through Gradle's `embedSwiftExportForXcode` task;
[SKIE installation](https://skie.touchlab.co/Installation) documents its Gradle
plugin. Neither reviewed guide establishes the required standalone Toolchain
pipeline. This experiment does not prove either standalone integration.

A fresh four-coordinate OSV lookup covered declared Metro runtime/compiler and
Toolchain compiler leads. It returned the known moderate Kotlin Gradle-plugin
advisory for 2.4.10; actual selection of that coordinate in the direct build is
unverified. This is a review lead, not proven direct exposure or security clearance.
The profile does not capture the complete resolved direct target/plugin graph,
so complete direct advisory review remains blocked. The earlier bridge review
retains its own graph/query binding and OpenTelemetry finding; its security
assessment is not transferred to this direct candidate.

## Untested assumptions

Simulator debug/PullRequest results do not establish device/minimum-floor
execution, Full-plan/macro handling, release/archive/export/signing, generic
interop, cancellation/failure/lifecycle equivalence, true clean-clone onboarding
or cold hosted direct CI. The typed-facade API still needs architecture review.
No equivalence is claimed for these unmeasured surfaces.

## Remaining blockers and next small step

Only the current-tuple simulator, bounded incremental and exact local-restoration
questions close. Full direct graph/plugin/advisory review, API/behavior decisions
and the native/operational surfaces above still block retirement, followed by
explicit default-switch and separate removal approval.

That module/target collector and named Maven lookup are now implemented and
[assessed](direct-resolution-assessment.md); compiler/plugin/build-tool scope and
exact artifact attribution remain open. The acceptance below describes the
original proposed next step, rather than complete graph proof.

The next small implementation was to capture direct resolution evidence using
the existing Toolchain graph parser and executor. Acceptance: cover every
module/test/target scope; retain selected versions, edges and artifact identities;
refuse unresolved/unsupported scope; bind fresh advisory queries to the exact
direct graph; preserve provider failure states and existing profile/ownership/
cleanup behavior. No new executor or production transition is needed. See the
[retirement path](bridge-retirement-path.md) for subsequent independent gates.
