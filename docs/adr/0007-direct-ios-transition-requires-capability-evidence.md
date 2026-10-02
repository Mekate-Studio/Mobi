# ADR 0007: Direct iOS transition requires measured capability evidence

- Status: Proposed; no default switch or bridge retirement approved
- Date: 2026-10-02

## Context

ADRs 0003 and 0006 remain accepted. Xcode owns the native application, tests and Swift packages; the retained Gradle bridge supplies Kotlin frameworks and SKIE sealed-state projections. Kotlin Toolchain 0.12.2 is the current workspace tool. The passing slice-7 typed-facade experiment established bounded simulator compatibility with its hand-maintained bridge unavailable, but left incremental, rollback, release, lifecycle and onboarding evidence open.

The typed facade preserves feature-local sealed Kotlin truth, Kotlin exhaustive visitors, typed payloads/reasons and native Swift enum adapters. It adds an explicit projection surface at the shared DI boundary. This is an architectural tradeoff requiring review: compiling a generated facade does not establish that it is the preferred public API or that future sealed-case changes are handled correctly across all consumers.

## Proposed decision

Evaluate a direct transition through independent, source-bound capabilities. A manual local round trip may establish changed Kotlin behavior reaching Swift with warm caches and restoration to exact original bridge inputs with direct products cleared. It cannot authorize production changes. Keep production dependency maintenance separate from interop/build ownership.

Before considering a named direct-default patch, require:

- Architecture/API review of the facade or a supported equivalent, preserving typed state and explicit factories; no loose string tags or weakened domain state.
- Native app/test targets, schemes, both test plans, packages/macros, shared DI/compiler plugins and optional Compose/UIKit resources retained and executed.
- Android/shared regressions, simulator tests, required ARM device framework/app compilation and execution policy, and the declared minimum-OS policy assessed.
- Characterized baseline and candidate cancellation/failure/lifecycle semantics and a bounded generic export fixture, without inventing a generic production state requirement.
- Clean-clone onboarding and cold supported hosted CI with the hand-maintained bridge unavailable, plus incremental invalidation evidence.
- Release configuration, archive layout/resources/minimums and packaging appropriate to the claim; signed/export evidence before a distributable release claim.
- Fresh release-interval, resolved dependency/plugin and advisory review for the exact direct tuple. Passing native jobs do not suppress build-tooling findings.
- A reviewed reversible content/default patch, explicit maintainer approval and integration evidence. Existing bridge inputs must remain recoverable from an exact reviewed revision.

Only after an approved default switch and subsequent complete parity evidence should a separate physical bridge-removal change be considered. Do not combine this with a dependency upgrade or silently change architecture/OS support. Missing capabilities remain blocking even when other cells pass.

## Recovery and rollback

During assessment, use executor-owned copies, private caches, resource ownership and explicit recovery/cleanup. Validate authored preimages before restoration. Clear generated framework/Xcode products so a restored bridge cannot reuse direct products. A failed restoration is non-passing evidence; it does not authorize overwriting caller work.

A future production rollback must verify current identities, restore the exact reviewed content/default change and rerun native consumers. An environment variable alone is not a proven rollback when manifest, Xcode phase and interop API contents also differ. After approved physical removal, restore the bridge from its reviewed prior revision and validate it. No such production operation is authorized by this ADR.

## Consequences

The public onboarding and release defaults continue to use the retained bridge. Local incremental/rollback receipts can reduce specific evidence gaps while retirement remains deferred. Every run keeps its original source identity, failures and limits. Repo-owned manual scripts remain usable without private infrastructure, an AI service or a new schedule. The independent Elixir/Phoenix profile stays dormant.

## Sources

The [versioned Toolchain iOS guide](https://github.com/JetBrains/kotlin-toolchain/blob/v0.12.2/docs/src/user-guide/product-types/ios-app.md) and [project-management source](https://github.com/JetBrains/kotlin-toolchain/blob/v0.12.2/sources/amper-cli/src/org/jetbrains/amper/tasks/ios/ManageXCodeProjectTask.kt) describe a managed application integration phase and required scheme; actual preservation needs measurement. Current [Swift export guidance](https://kotlinlang.org/docs/native-swift-export.html) remains Alpha and documents a Gradle embedding task. [SKIE installation](https://skie.touchlab.co/Installation) documents its Gradle plugin. Those sources do not prove an equivalent standalone Toolchain path; the dated slice-10 receipt binds retrieved contents separately.
