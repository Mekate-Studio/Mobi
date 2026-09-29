## Context

Slice 6 passed the normal staged gate and all seven jobs in Mobile CI run 36348324700 at commit `ff7146e9cad15a26ae3824a2eca192f0ec6b3684`. It supplies an executor, private workspaces, source binding and native resource recovery. The old compatibility task only compiles a KLIB; it does not establish framework linking, Swift generation or native consumer parity.

## Goals / Non-Goals

**Goals:** Make the two evidence tracks repeatable from a public checkout; retain failures and capability gaps as useful results. Exercise real repository jobs and exact candidate transformations.

**Non-Goals:** Dependency adoption, a release-default switch, complete bridge retirement, scheduled automation changes, or an Elixir application.

## Decisions

- Reuse the common executor and independent Kotlin resource handler. Add a Kotlin compatibility adapter rather than a second workspace/process manager. Baseline failure stops candidate execution; separate runs keep the bridge and direct experiments independent.
- Select a dated, reviewed Kotlin 2.4.10 / Metro 1.4.4 / SKIE 0.10.14 candidate. Hold Compose 1.9.0 in the bridge initially to bound the change; any demonstrated need for alignment becomes another explicit candidate. Newer SKIE 0.10.15 and Metro 1.4.5 are recorded with their release-age limits. Candidate selection does not relax Renovate ceilings.
- Separate compile/link and mobile profiles. Compile the Native KLIB and link its debug framework as separate commands. Full validation also executes the four existing mobile jobs. This prevents treating a KLIB-only probe as SKIE or app proof.
- Assess the SKIE and Swift export paths at their first unsupported prerequisite, with primary-source URL, version/retrieval time and digest. Do not invent undocumented Toolchain switches or call a Gradle export sample a standalone Toolchain result.
- Prototype an explicit typed visitor facade only in an owned direct-path copy. Keep Kotlin sealed types authoritative and native adapters/tests present. Add the missing DI dependency and the documented integration phase in that copy; record every transformation. Physically remove its bridge before any direct command. Preserve app/test target identities, schemes, plans and source bytes except declared experiment edits.
- Keep authored source snapshots immutable. A generated copy has an explicit transformation receipt and its own expected manifest; unexpected generated changes still refuse the run. Do not weaken the executor's candidate preimage protocol.
- Each matrix cell identifies its check and evidence kind. Missing device, release, cancellation, generic-export and cold-CI proof remains missing. A successful experiment can only report named checks passed, never adoption authorization or bridge-retirement approval.

## Risks / Trade-offs

- Native jobs are expensive → run narrow checks before full mobile, keep bounded timeouts and owned resources.
- Unsupported upstream integration can halt a path early → retain the exact prerequisite blocker; do not manufacture a green result by deleting tests or weakening state types.
- A facade adds public API surface → keep it as an experiment fixture; architecture review is required before adoption.
- Evidence can become stale or refer to different code → bind source, plan, tools, patch and logs, and reject mismatched or malformed receipts.
- Local simulator success does not cover devices or packaging → expose those cells independently; never infer them.

## Migration Plan

Add manual commands and contracts, execute bounded isolated probes, publish sanitized receipts and document next blockers. Leave production pins and the existing schedule unchanged. Disposable copies use the current recovery/cleanup commands; retain logs after cleanup. Removing the new manual adapter is sufficient rollback because no production default changes.
