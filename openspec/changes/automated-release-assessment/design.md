## Context

See proposal.md. The existing watch has bounded first-page discovery, source identity, an isolated native executor, history comparison and one weekly workflow. Graph, advisory and native resource handlers already exist. They must not be bypassed or represented as broader evidence than they provide.

## Goals / Non-Goals

**Goals:** a single local pipeline and packet covering official interval acquisition, app impact, qualification and security, with explicit recommendation and approval boundaries.

**Non-Goals:** automatic dependency adoption, policy exceptions, merges, signing, workaround retirement or unrestricted generic semantic interpretation.

## Decisions

- Reuse the executor's baseline-first ordering, source/patch bindings, native resource ownership and recovery. Do not build a second cleanup protocol.
- Collect official evidence through an allowlisted, size/time/request-bounded HTTP client with isolated content-addressed receipts and freshness checks. Provider limits become incomplete results, never empty catalogs.
- Use deterministic actual-source mapping plus registry replacement/check obligations. Text matches identify impact leads, not semantic equivalence or retirement proof. Unhandled upstream surface changes remain explicit review limitations.
- Run qualification only for a bounded selected candidate set, serially. Assess all observed stable/prerelease leads; age-blocked, unsupported and budget-deferred candidates remain visible. Keep source evidence and qualification separate from age/risk adoption decisions.
- Keep raw evidence in ignored stores. One compact packet binds source, policy, patch, official sources, graph/security outputs and qualification. Human approval applies only to that exact packet; assessment creates no PR.

## Risks / Trade-offs

- Broad upstream changes exceed deterministic understanding → retain explicit semantic-review gaps; no unsupported adoption recommendation.
- Native qualification is expensive → candidate cap, global lock, deadline, existing executor timeouts and ownership cleanup.
- Providers truncate history or fail → retain partial receipts and incomplete coverage.
- Existing graph coverage omits bundled/delegated ownership → expose those gaps and keep the adoption gate closed rather than infer clearance.

## Migration Plan

Implement and contract-test the local command, run an end-to-end assessment, then reuse the weekly caller. Record actual coverage before treating the prerequisite as operational. Preserve the former watch's history and evidence scope. Full local assessment precedes approval and one adoption PR; this automation implementation is its own change.
