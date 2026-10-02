# Tenth slice validation

Status: the manual direct-roundtrip implementation and paired local native rehearsal passed. Slice 10 remains uncommitted. Production bridge/dependency/default/release settings and schedules are unchanged; bridge retirement remains deferred.

## Implementation checks

The profile reuses the baseline-first executor, owned native resources, source guard, existing mobile jobs and recovery/cleanup. It adds a native consumer of a two-file incremental probe and exact authored-input restoration before rebuilt bridge consumers. The report verifier checks stage references and closes only bounded local incremental/rollback capabilities after a complete paired pass.

The full contract suite passed 202 tests across ten suites with zero failures; eight new round-trip contracts cover exact restoration and executable modes, changed source/mode/symlink/bridge/output refusal, probe preimages, preserved native consumers, required stage cells and altered/incomplete framework/restoration evidence. A follow-up identity-order regression also passes: the prepared manifest used for native guards has the same digest as the actual authored tree. All five pinned static analyzers passed, with a 4.909-second warm run. Strict OpenSpec validation passes 15 items. Final documentation, privacy and production-boundary checks are recorded below.

The first focused negative contract expected a narrower diagnostic than the verifier returned when a rollback framework reference was absent. Its expected error category was corrected; the verifier's refusal was retained. No build failure was waived.

## Integration boundary

Slice 9 was committed locally as `9f730ef` after the full pre-commit gate passed. Its exact staged index identity was `0adf16007cc7628e930d2a2acc044b831e63cbfc5ea60b390abc21170eb313d3`, and copied input identity was `224c19812f0c0fad3cbdeaecdb8b7d54467ecd1f4f0f2a68f9372f5aceab8f8f`. Android/shared tests, all 12 Swift cases and both debug builds passed; owned Gradle 9.5.0/9.6.1 daemons were stopped and the temporary validation copy removed. Observed job times were 280.001, 223.290, 27.244 and 61.796 seconds respectively. No push or hosted validation of that commit occurred.

The proposed ADR 0007 records transition gates without replacing accepted ADRs 0003/0006. Device/minimum-floor, lifecycle/generic, release/signing, clean-clone and cold-hosted evidence remain open. Current advisories are not suppressed. The newer fixed dependency tuple is independent and unqualified. This slice does not authorize adoption, default switching, production rollback, physical bridge removal, commits, pushes, publishing or new schedules.

## Native result

Run `52729810dbe3a742624463ab4fa5e5f4` passed from 2026-10-02 09:23:41 through 09:55:27 UTC. It captured a local working snapshot on `9f730efd19fbfa6eb13276a38e7c4eed5b7b5556`, with authored-source identity `bbe397a90e20567fdc4a583d6cb7ab74b3a9a7102e3aec7bcdecf40bfa9e99a8`. Collection and evaluation code were frozen during execution; subsequent edits complete the public documentation. The [public receipt](evidence/2026-10-02-slice-10.json) binds command/reference hashes, source preservation, primary-source retrieval metadata and cleanup. Raw logs, host identities and original contents remain in ignored `.maintenance/`.

| Stage | Executed checks | Swift cases | Result |
| --- | --- | --- | --- |
| Unchanged retained bridge | Toolchain settings, KLIB compilation, framework link, Android tests/debug build, iOS tests/debug build | 12 original cases | Passed |
| Initial direct candidate | Toolchain settings, Android tests/debug build, iOS tests/debug build; bridge unavailable | 12 original cases plus incremental probe | Passed |
| Changed direct candidate | iOS tests/debug build with Kotlin return and Swift expectation changed, caches/products retained | Same 13 cases | Passed; three framework binaries changed |
| Restored retained bridge | Exact original authored bytes/modes restored, experiment additions removed, owned `build/` cleared; iOS tests/debug build rerun | Same 12 original cases | Passed |

The direct tuple is Toolchain 0.12.2 / Kotlin 2.4.10 / Metro 1.1.1, regular Objective-C export and isolated typed projections, without SKIE. Baseline and restored bridge use Kotlin 2.3.20 / Metro 1.1.1 / SKIE 0.10.12 / Compose 1.9.0. The separate bridge-upgrade tuple was not adopted. Candidate standalone KLIB/link cells are explicitly `not_attempted`; its native jobs generated and consumed the direct framework.

Changed binaries were measured at the same relative paths in the Toolchain framework task and both Xcode debug/test products. Native assertions passed before and after mutation, so this result combines changed bytes with an actual Swift consumer. Restoration matches the original source identity exactly, including the executable bridge wrapper. Source preservation is verified for both phases. Direct bridge absence and shared-DI reachability describe the direct stage before restoration; the final candidate copy has the bridge restored.

After execution, recovery reported `quiescent`, cleanup reported `cleaned`, and both owned workspaces/caches were removed while immutable evidence remained. Reporting after cleanup verified the complete receipt chain; its SHA-256 is `49b54d66741db2220f0f98117bc8b32ef92255e4587900db94036da558a5b78a`. Only `incremental_direct_build` and `local_bridge_rollback` close for the local candidate/overall assessment. The unchanged baseline lane retains its unmeasured direct gaps. Adoption authorization remains false.

## Untested assumptions and blockers

This is a prepared Apple Silicon host, iOS 27.0 simulator and the PullRequest test plan. Macro validation was explicitly skipped by the existing job; neither the Full test plan nor macro trust validation is newly proven. iOS 26.0 minimum-floor execution, physical devices, release/archive/export/signing, generic export, cancellation/lifecycle equivalence, true clean-clone onboarding and cold hosted direct CI remain untested. One implementation-invalidation probe does not establish exhaustive incremental behavior or performance.

Architecture approval of the typed facade, complete direct dependency/plugin and release-interval/advisory review, and a named transition decision remain blockers. Slice 9's moderate build-tooling advisory findings remain visible; the newer fixed tuple is independent and unqualified. The proposed ADR is conditional, and existing accepted ADRs/defaults remain in force. No native failure was relabeled or bypassed in this run.

## Final repository checks

Strict OpenSpec validation, local Markdown targets, public receipt privacy/reference verification and `git diff --check` pass. Production source, bridge/catalog pins, wrapper, mobile support policy and hosted workflows have no changes against `9f730ef`. This validates the local implementation and documents a deferred transition; it is not hosted integration or a release claim.
