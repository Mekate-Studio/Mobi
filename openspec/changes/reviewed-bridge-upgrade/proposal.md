## Why

The reviewed Kotlin/Metro/SKIE candidate has passing narrow compatibility evidence, but adoption still lacks current interval review, resolved target/plugin graph comparison and fresh advisory evidence. Slice 9 must produce a concrete, source-bound decision before production pins change.

## What Changes

- Add a manual `bridge-review` rehearsal profile that extends the existing isolated evaluator with Toolchain dependency graphs and Gradle target/plugin resolution evidence.
- Capture graph nodes, edges, variants, artifact hashes and explicit resolution failures; retain base/candidate differences for review.
- Refresh the exact candidate's primary release interval, migration and support-policy evidence, and assess relevant advisories with visible coverage gaps.
- Produce a public-safe review packet and exact proposed patch; require explicit maintainer authorization before applying dependency or Renovate-policy changes.
- Revalidate adopted contents only after authorization. Keep bridge retirement as a separate decision.

## Capabilities

### New Capabilities

- `reviewed-bridge-upgrade`: source-bound resolution and evidence for a manually reviewed coupled upgrade.

### Modified Capabilities

None.

## Impact

Repository-owned compatibility scripts, targeted contracts and maintenance documentation. The candidate is Kotlin 2.4.10 / Metro 1.4.4 / SKIE 0.10.14 with Toolchain 0.12.2. The existing executor, ownership, cleanup and native jobs remain the execution path. No schedule, release-default switch or automatic adoption is introduced. Elixir remains dormant.

The subsequent adoption milestone assesses Kotlin 2.4.20 / Metro 1.4.5 / SKIE 0.10.15 in a separately configured source copy. The earlier candidate's evidence remains historical. Explicit experimental admission retains the normal seven-day adoption gate and requires fresh age/advisory review before any maintainer decision.
