## Context

Slice 7 has passing isolated bridge and typed-facade comparisons. Only the reviewed bridge compile/link profile belongs in the existing weekly watch. A new release or changed source is a review lead, not proof of compatibility or adoption permission.

## Goals / Non-Goals

**Goals:** Reuse the evaluator; quiet unchanged notifications; explicit provider, native and history gaps; meaningful matrix changes; retained public-safe artifacts and owned cleanup.

**Non-goals:** Direct-path retirement qualification, automatic candidate selection or upgrades, adoption, AI review, new schedules, private infrastructure, issue/email/PR publication or Elixir activation.

## Decisions

- Keep comparison and snapshot validation in a common library; isolate Kotlin release providers and matrix projection in its adapter.
- Public release discovery is a bounded page of stable GitHub releases for four named upstream projects. Record raw response hashes, retrieval time and normalized releases, including age-blocked versions. A timeout, rate limit or malformed response is incomplete provider evidence, never no updates. Full release interval/advisory coverage remains outside this watch.
- Run only the reviewed `bridge-compile` tuple. Reuse `CompatibilityRehearsal`, `Executor`, `CompatibilityReport` and `Recovery`; never edit the caller catalog or reinterpret compile/link as mobile or retirement proof.
- Compare semantic observations, excluding run IDs, timestamps, durations and artifact hashes. Candidate/policy changes reset comparability; same-scope capability transitions distinguish improvements/regressions. Missing or invalid history cannot produce an unchanged verdict.
- Preserve local file input/output for reuse. In Actions, discover the most recent completed run of this workflow on the same branch, then download its named snapshot artifact with read-only permissions. Missing/expired/malformed history remains visible. Artifacts avoid relying on a seven-day dependency cache for weekly continuity.
- Report status separately from notification. A completed watch may record expected incompatibility or an incomplete provider assessment without pretending compatibility passed. Only meaningful changes create workflow annotations; every run has a summary and structured status. These annotations do not promise email delivery. Integrity failures and unsafe cleanup remain operational failures.
- Preserve the existing cron and manual trigger. Disable cancellation of an active same-ref rehearsal; serialize rather than abandon owned native resources.
- The watch cleans disposable workspaces after quiescent recovery and retains local run evidence. Hosted uploads include public summaries, source identities and normalized discovery evidence; private host/process paths and raw native logs are excluded.

## Risks / Trade-offs

- Artifact expiry or failed download loses continuity: emit a visible history gap and establish a new observation, never a silent unchanged result.
- Public APIs can throttle unauthenticated requests: bound reads/timeouts and expose each provider's status. Discovery does not need private credentials.
- Cold hosted compilation can fail despite local success: retain the evaluator's baseline/infrastructure classification. Hosted acceptance remains unverified until this workflow executes after integration.
- Watch success is easy to confuse with compatibility success: label both operation and assessment state, retain the native result and missing capabilities, and always keep adoption false.

## Migration Plan

Add contracts and the manual watch command, connect the old entry point and existing workflow, run an isolated local end-to-end probe, then review and integrate separately from slice 7. No production rollback is needed; reverting the caller integration restores the previous manual invocation while the evaluator remains available.
