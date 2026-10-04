## Context

See proposal.md. Toolchain 0.12.2 resolves each plugin separately for JVM runtime, filters the embeddable compiler from its classpath, and retains output files rather than a consumer-facing plugin graph. The preceding paired run retains real successful invocations and selected byte fingerprints.

## Goals / Non-Goals

Goals: replayable attribution and exact advisory scope using public infrastructure and the existing executor.
Non-goals: adopting dependencies, waiving advisories, changing native builders, or proving shaded library contents or all compiler/test surfaces.

## Decisions

Use an independent Gradle runtime resolver per configured root. Read explicit custom roots from bound module declarations and the Compose root from effective Kotlin version plus a versioned, captured Toolchain mapping. Pin that mapping to primary upstream bytes. Compare the complete retained resolver artifact set after the upstream compiler exclusion with actual selected file identities. A resolver pass alone cannot prove compiler selection.

Create a separate executor run whose input packet identifies the original run/result/source and both replayed build-input producers. Preserve the old result unchanged. Reuse owned filesystem/process-group recovery, wrapper bootstrap, private caches and JDK input. Retain graph and matching receipts in control storage; reporting replays graph joins after cleanup. Query only fingerprint-matched components; unresolved findings remain gates.

## Risks / Trade-offs

Different resolvers or metadata selection → strict fingerprint/set refusal rather than assuming parity.
Shaded plugin code → explicit gap; component attribution is not embedded dependency attribution.
Old compiler run plus new resolver → both identities and timestamps retained; no fresh compilation or current-source equivalence claim.
Provider staleness → existing 24-hour freshness and explicit refresh; no clean lookup by omission.

## Migration Plan

Add a manual command and refusal contracts, run an owned current-root assessment, publish verified and untested scopes. Recover and explicitly clean disposable work. The integration can be removed without application changes; no default switch is authorized.
