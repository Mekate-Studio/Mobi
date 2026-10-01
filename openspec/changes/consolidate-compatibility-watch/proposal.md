## Why

The existing weekly compatibility caller mutates the checkout, uses a compile-only task and treats technical success as a failure notification. Slice 7 supplies an isolated evaluator; the watch should reuse it and preserve meaningful changes without authorizing upgrades.

## What Changes

- Replace the old shell implementation with a wrapper over a repository-owned compatibility watch.
- Fetch bounded public release evidence for Toolchain, Kotlin, Metro and SKIE; retain source hashes, release ages and provider failures without automatically nominating new candidates.
- Rehearse the reviewed bridge compile/link profile through the existing executor, verify its report, and recover/clean only owned resources.
- Compare normalized capability, release and blocker observations with a prior snapshot; unchanged observations produce no annotation.
- Preserve the existing weekly schedule and manual trigger. Use read-only Actions history and retained artifacts for continuity, with explicit missing/corrupt/stale history states.
- Keep direct-path qualification, dependency adoption, Renovate ceilings and production defaults separate.

## Capabilities

### New Capabilities

- `compatibility-watch`: source-bound scheduled observations, conservative deltas and explicit continuity/provider failures.

### Modified Capabilities

None.

## Impact

The existing compatibility workflow and shell entry point, common observation comparison, Kotlin-specific discovery/evaluation, contracts and public documentation. Local execution needs no GitHub account or AI tool. Hosted persistence uses the repository's existing GitHub Actions service with read permissions. No new schedule or outbound issue/email/PR publisher.
