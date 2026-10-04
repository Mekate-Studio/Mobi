# Toolchain 0.13.0 SwiftPM capability assessment

Reviewed on 2026-10-03. Status: documented upstream, not rehearsed in Mobi. Production remains Toolchain 0.12.2 with the Gradle bridge. The seven-day candidate age threshold for 0.13.0 is 2026-10-08T06:36:56Z; earlier assessment requires explicit experimental mode.

## Verified upstream scope

The [0.13.0 release](https://github.com/JetBrains/kotlin-toolchain/releases/tag/v0.13.0) announces initial SwiftPM support. Its [versioned dependency guide](https://github.com/JetBrains/kotlin-toolchain/blob/v0.13.0/docs/src/user-guide/dependencies.md#swiftpm-dependencies) describes importing Objective-C-visible APIs from SwiftPM dependencies into Apple Kotlin modules through Clang/native interop. Remote declarations select repositories, versions and products. Swift-only APIs can be exposed through a local Objective-C-visible wrapper. Published Kotlin libraries carry SwiftPM dependency metadata for graph traversal; absolute local-package paths restrict publication to the local Maven repository.

This direction of interop can help future native-dependency integration. It does not establish that Mobi's Kotlin framework can be distributed through SwiftPM, or that its TCA dependencies, Swift macros, Xcode app/test targets or sealed-state adapters are equivalent under a direct Toolchain build. No such capability is credited from the announcement.

## Workflow tracking

`maintenance-compatibility.json` records this as `documented_not_rehearsed`, with captured source identities and independent capability gaps. `assess-compatibility` emits the observation alongside the existing direct-path assessment; existing compatibility-watch snapshots and summaries retain it as well. It does not enable a direct export path or a schedule.

Discovery checks later upstream releases and versioned implementation/docs. Assessment maps an actual blocker to the supported import direction before proposing a fixture. Rehearsal uses an owned checkout, exact package revisions, ARM device/simulator builds and recorded package resolution, compilation/linking and runtime evidence. Review considers API visibility, transitive metadata, clean-clone reproducibility and publication restrictions. Adoption requires explicit authorization and a reviewed application patch.

For bridge retirement, retain all gates in [bridge-retirement-path.md](bridge-retirement-path.md): Kotlin-to-Swift framework/export consumption, native tests and state adapters, compiler plugins, lifecycle/generics, incremental edits and rollback, Xcode target ownership, device/release packaging and clean-clone onboarding. SwiftPM package import cannot close these gates by itself.

## Untested assumptions and blockers

Mobi currently owns SwiftPM dependencies in its Xcode/Swift integration. Whether relocating any package import benefits this architecture is untested. Pure Swift APIs or macro expansion may need capabilities outside the documented import scope. Remote-package onboarding and dependency metadata publication remain unexecuted. The upstream remediation build-input rehearsal does not exercise SwiftPM.
