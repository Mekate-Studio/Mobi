## Context

See proposal.md. The compatibility executor already owns paired workspaces, caches, process recovery and evidence bindings. The direct facade transformation preserves native targets and tests. The Toolchain pretty graph parser describes Maven roots; downloaded files are fingerprints, not an authoritative mapping of every compiler or runtime artifact.

## Goals / Non-Goals

**Goals:** Add reusable manual resolution and exact-input provider evidence, with explicit gaps and refusal contracts.

**Non-Goals:** Repeat native builds in a graph-only profile; claim complete compiler/plugin resolution from cache names; adopt dependencies or retire the bridge.

## Decisions

- Add `direct-resolution` to the existing adapter. Both phases collect settings and graphs; only the candidate applies the existing facade transformation. Skip simulator creation and native jobs. Retain owned process observation because resolution can start JVMs.
- Validate platform coverage against each phase's captured module declarations; replay parsed graphs from the retained dependencies log. Preserve graph and fingerprint digests and counts separately. Do not infer artifact attribution from cache paths.
- Extract the existing Toolchain Maven query builder for reuse. Normalize only supported packaging suffixes and exclude constraint nodes.
- Add a manual advisory command using the public OSV API, with no credentials. Query batches, fetch full finding records and retain requests, raw response bodies, status, timestamps and hashes. Unsupported pagination or failed/malformed responses yield incomplete evidence. Recompute summaries when reading receipts.
- Keep provider coverage and full dependency-surface coverage separate. Even a complete exact-input lookup cannot close the overall advisory gate while compiler/plugin and delegated graphs remain missing.

## Risks / Trade-offs

- Pretty output is version-bound → reject unknown format and compare against raw output.
- Maven graphs omit build-tool internals → retain explicit limitations and do not infer clearance for Kotlin Gradle Plugin.
- Provider/network failures → preserve partial receipts and fail incomplete; rerun manually.
- Graph-only success can be confused with native parity → required reports include unexecuted native cells and missing capabilities.

## Migration Plan

Run contracts and static checks, freeze implementation inputs, execute the current tuple in isolation, collect exact advisory evidence, verify recovery/cleanup and publish a public-safe receipt. The production builder and dependency declarations remain unchanged. Existing profiles retain their checks.
