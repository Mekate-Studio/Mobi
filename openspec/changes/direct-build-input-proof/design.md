## Context

See proposal.md. Toolchain 0.12.2 exposes `kotlin-compilation` and `konanc` OTLP spans with real compiler arguments. Its Android runner creates per-task Gradle projects and applies its integration settings plugin. Module graphs alone omit these build inputs.

## Goals / Non-Goals

**Goals:** Reuse paired isolation and exact-input provider review; prove bounded selected plugin paths and delegated settings/project graphs.

**Non-Goals:** Repeat Swift app tests, release packaging or lifecycle probes; infer coordinate identity from cache names; change build defaults or adopt dependencies.

## Decisions

- Add `direct-build-inputs` alongside the graph-only profile. Collect module graphs, Android host tests/debug build, and ARM device/simulator KLIB builds for all shared modules. Native compiler execution does not claim device app execution.
- Retain raw OTLP telemetry before cleanup, normalize owned paths and record hashes for selected `-Xplugin` artifacts. Verify required module/platform main compilation scope. Native test compilation remains unmeasured unless explicitly executed.
- Install a Gradle observer only in the phase's private Gradle home. Collect settings/project buildscript and reviewed Android debug main/build-tool configurations in the delegated task graph; retain a complete configuration inventory. Emit after completion. Gradle 9.5 prohibits new unlocked resolution at buildFinished; unrelated unit/instrumentation/release configurations remain explicitly not_collected. File-injected dependencies retain opaque identity and hashes, never invented Maven coordinates.
- Reuse exact Maven query normalization and OSV collection. Add selected delegated Maven inputs; keep compiler-plugin transitive attribution unsupported until an authoritative mapping can be established.
- Keep existing profiles and their evidence semantics unchanged. Reports replay retained producers and refuse missing/unsafe records.

## Risks / Trade-offs

- Internal telemetry format may change → pin the reviewed Toolchain version and refuse unknown or incomplete records.
- Resolving unused delegated configurations can expose extra dependencies → label inventory versus executed task scope explicitly.
- Compiler jars can lack Maven metadata → report selected artifact proof separately from coordinate/advisory completeness.
- Cold dependency/network failures → retain partial evidence; recover owned processes and retry as a distinct run.

## Migration Plan

Implement contracts, run repository checks, freeze source and run a paired current-tuple assessment. Collect fresh advisory evidence, verify recovery/cleanup and publish public-safe results. No production transition is part of this change.
