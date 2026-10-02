# Ninth slice: reviewed bridge upgrade

Status: local review checks passed; adoption deferred. The maintainer has not approved this named tuple or policy patch. This review names Toolchain 0.12.2, bridge Kotlin 2.4.10, Metro 1.4.4 and SKIE 0.10.14, holding bridge Compose 1.9.0. Toolchain-managed defaults are Kotlin 2.4.10 and Compose 1.11.1 in the measured UI settings, independently of bridge Compose 1.9.0. This is a retained-bridge upgrade, with ARM device/simulator declarations, native Xcode targets/tests and sealed-state adapters preserved.

The subsequent [revised adoption assessment](bridge-adoption-review.md) evaluates
Kotlin 2.4.20 / Metro 1.4.5 / SKIE 0.10.15 with separate receipts and proposals.
The older tuple and findings below remain historical evidence and are not
relabeled as validation of the newer candidate.

[Validation and retained failures](ninth-slice-validation.md), [source-bound receipt](evidence/2026-10-02-slice-9.json), [queried packages and advisory matches](evidence/2026-10-02-slice-9-maven-queries.json), [six-file dependency proposal](proposals/slice-9-dependencies.patch) and [separate bounded Renovate proposal](proposals/slice-9-renovate.patch) are review artifacts. Neither patch has been applied.

## Decision boundary

The fresh Maven advisory assessment changes the recommendation. Kotlin 2.4.10 remains in the affected range for GHSA-r937-wjx7-w2jp; passing builds cannot be presented as a security fix. The upstream fixing commit addresses KAPT incremental-cache deserialization. Mobi configures Metro compiler injection and has no KAPT declarations, which narrows likely applicability but is not exploit or reachability proof. OpenTelemetry's baggage advisory is present on the bridge Swift-export tooling configuration; Mobi does not execute Swift export in the selected native jobs. Both findings remain visible and require an explicit residual-risk decision.

The next fixed bridge compiler to assess is Kotlin 2.4.20, coupled with SKIE 0.10.15 and an exact reviewed Metro version (1.4.5 is already age-eligible, but unqualified). SKIE's seven-day age threshold is 2026-10-02 17:59:28 UTC, so the early-morning review cannot nominate it for normal adoption. This review neither overrides that rule nor qualifies the newer tuple. Toolchain 0.13.0 is a separate age-blocked track. A fixed bridge compiler would not establish that Toolchain's own Android compiler/delegated Gradle tooling is fixed.

## Primary interval assessment

The source receipt binds paginated upstream release histories, tagged changelogs, compatibility guidance and advisory queries to retrieval dates and SHA-256. The Kotlin history contains 305 releases across four pages; Metro and SKIE histories contain 81 and 42 releases. Prereleases outside the exact stable intervals are not silently adopted. Stable release publication metadata governs age; mutable documentation banners do not replace it. All stable releases strictly after the baseline and through the candidate were inspected.

| Interval / source | Mobi consumer and assessment |
| --- | --- |
| Kotlin 2.3.21 | Compiler/Native fixes affect shared behavior and framework production. Existing shared tests plus native consumers are the checks; individual upstream bug fixes are not exhaustively reproduced. |
| Kotlin 2.4.0 | Language 1.9/K1 removal, stricter types/inline/opt-in rules and annotation target changes require recompilation of shared code and Metro-generated factories. Mobi has no K1 or explicit legacy language setting. Kotlin's migration guide also removes outgoing framework configurations and deprecated Native/Compose Gradle APIs. The current bridge embeds framework products through its tasks rather than consuming those removed outgoing configurations; compiler/link/Xcode checks must confirm that usage. |
| Kotlin 2.4.10 | Compose stability inference and Native symbol fixes affect shared UI and KLIBs. Native Swift consumers and Compose-enabled Android tests/builds are required. Bridge Compose remains 1.9.0; no separate Compose library upgrade is proposed. |
| Metro 1.2.0–1.2.1 | Constant provider inlining, Native scoped initialization and KLIB binding fixes affect shared DI. Metro's later IR generation is gated by newer compiler versions. The factory and native consumer tests cover Mobi's usage; they do not stress-test every concurrent initialization path. |
| Metro 1.3.0–1.3.2 | Structured diagnostics, KLIB/mirror metadata, generic graph/assisted injection and incremental fixes affect compiler generation. Existing graph factories and builds are consumers. Hilt, tracing and unsupported future compiler features are not enabled in Mobi. |
| Metro 1.4.0–1.4.1 | Provider/Lazy changes, Native hidden-class fixes and member-injection ordering warrant factory/native checks. Suspend providers and Circuit serializers are optional additions that Mobi does not enable. No feature adoption is bundled with the pin change. |
| Metro 1.4.2–1.4.4 | Type-alias, contribution, annotation-default, cycle and compiler-selection fixes affect graph generation. watchOS target changes have no Mobi consumer. The versioned compatibility table includes Kotlin 2.3.20 and 2.4.10, but only actual compile/link/native evidence establishes this repository's compatibility. |
| SKIE 0.10.13–0.10.14 | Added Kotlin 2.4.0/2.4.10 support matters for sealed-state Swift adapters. Configuration-cache fixes and Swift documentation changes do not replace native tests. Flow/coroutine interop stays disabled. |

Primary links: [Kotlin tagged changelog](https://github.com/JetBrains/kotlin/blob/v2.4.10/ChangeLog.md), [Kotlin 2.4 migration guide](https://kotlinlang.org/docs/compatibility-guide-24.html), [Metro tagged changelog](https://github.com/ZacSweers/metro/blob/1.4.4/CHANGELOG.md), [Metro compiler compatibility](https://github.com/ZacSweers/metro/blob/1.4.4/docs/compatibility.md), [SKIE 0.10.13](https://skie.touchlab.co/changelog/0.10.13), [SKIE 0.10.14](https://skie.touchlab.co/changelog/0.10.14).

## Measured resolution and validation

The baseline and candidate each passed all nine cells: effective Toolchain, Toolchain graphs, bridge graphs, KLIB compile, framework link and the four existing Android/iOS test/debug-build jobs. Each phase ran all 12 Swift tests. The baseline has 92 Toolchain graphs and 185 bridge configurations (72 resolved, 113 non-resolvable); the candidate has 92 and 185 (74 resolved, 111 non-resolvable). All resolvable configurations completed, including device/simulator compile and test dependency scopes and plugin classpaths. Device framework compilation was not executed.

The bridge comparison has five added, five removed and 49 changed configurations. Framework outgoing configurations disappear as described by the migration guide; the checked-in framework build/embed tasks still pass. New ABI validation and SwiftPM metadata configurations are inventoried. Selected Maven node pairs have 76 additions and 66 removals, including changed versions; 257 baseline and 264 candidate Maven artifact identities were captured. No same-package/version/filename artifact changed bytes. Variant/configuration changes remain visible independently of byte changes.

The final advisory scan queried 559 unique Maven package/version pairs across both phases (485 baseline and 492 candidate). Packaging suffixes are explicitly normalized; constraint-only labels are excluded from query generation. The query set exactly matches the verified report. No high/critical advisory was returned for this mapped scope; two moderate IDs match three package/version pairs. This is not universal vulnerability clearance.

| Finding | Actual graph scope and decision evidence |
| --- | --- |
| [GHSA-r937-wjx7-w2jp](https://github.com/advisories/GHSA-r937-wjx7-w2jp) | Bridge buildscript Kotlin Gradle plugin 2.3.20 and candidate 2.4.10. [The upstream fix](https://github.com/JetBrains/kotlin/commit/bf51df6) restricts KAPT cache deserialization. No KAPT declaration or configuration is present in Mobi; likely lower applicability is an inspection inference, not a security fix or exploit proof. Stable 2.4.20 lies beyond the reported affected range. |
| [GHSA-rcgg-9c38-7xpx](https://github.com/open-telemetry/opentelemetry-java/security/advisories/GHSA-rcgg-9c38-7xpx) | OpenTelemetry API 1.41.0 is pulled by `swift-export-embeddable` in `swiftExportClasspathResolvable`, in both bridge graphs. It is not in the captured app dependency graphs and the selected bridge jobs do not run Swift export. The publisher fixes the baggage issue in 1.62.0. No transitive override or suppression is proposed; runtime reachability is unproven. |

## Support and architecture

The current primary stable-major history still yields iOS 26.0 and Android API 36 under the configurable lag-one policy. Current declarations match, with Android compile/target SDK 36. No OS floor or architecture change is proposed. ARM target resolution does not prove physical-device execution. The bounded manually reviewed history is explicit; it is not a universal automatic OS feed.

## Review and rollback

The six-file dependency patch is generated by the existing compatibility adapter. A separate proposed Renovate change may lift only the reviewed ceilings to <=1.4.4 and <=2.4.10; a passing compile never authorizes opening an unlimited range. Approval must name the dependency tuple, residual advisory findings and any policy edit. The repository policy blocks high/critical severity and requires unknown-severity triage; it does not silently dismiss moderate findings. The recommendation here is to defer adoption of this older compiler and assess the fixed coupled tuple after its age gate, without assuming that its build tooling or transitive OpenTelemetry dependency is fixed. The candidate config and related narrative must then be rebased around the adopted baseline so future rehearsals cannot silently test an obsolete preimage.

Before adoption, refresh advisory/source data if older than 24 hours, verify exact file preimages and policy identities, and reject drift. Apply only authorized contents; validate the resulting native consumers and pre-commit selection. Commit/push and hosted integration are separate permissions. Rollback reverses the reviewed content changes only after checking current file identities; it keeps the bridge selected.

## Untested assumptions and remaining gates

No exploit/reachability proof, device framework compilation/execution, signed archive/export, release packaging, cold hosted run of this tuple, direct-path cancellation/generic parity or incremental direct build is claimed. Graph hashes identify measured artifacts, not universal origin or compiler provenance. Maven advisory queries do not cover shaded code, the Native distribution internals, Swift packages, Ruby/npm maintenance tools or Toolchain delegated Android plugin internals. Those scopes remain in the inventory ledger and require their own assessment when changed. The test runtime is iOS 27.0; execution at the declared iOS 26.0 floor is not established by this run.

Bridge retirement remains deferred under ADRs 0003/0006 and the compatibility matrix. The dormant Elixir/Phoenix adapter remains independent and inactive; it has no new prerequisites in the mobile path.
