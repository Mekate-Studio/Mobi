# Eighth slice validation

Slice 8 consolidates the existing compatibility watch around the common isolated
evaluator. Production dependencies, iOS bridge/default, release paths, support
policy and the existing schedule remain unchanged. Bridge retirement is deferred.

Status: locally validated on 2026-09-30; commit/push and hosted execution are
recorded separately below when completed. See the
[watch guide](compatibility-watch.md) for behavior and limits.

## Verified facts

- The old entry point forwards to a reviewed baseline/candidate evaluator rather
  than mutating the caller catalog or selecting arbitrary latest SKIE versions.
- Common snapshots and semantic comparison are independent of the Kotlin adapter.
- The workflow retains its existing triggers, uses read-only repository/Actions
  permissions and uploads only the dedicated public report directory.
- The final local legacy-entry-point watch `768ee1b8429e35b175cc28f51c0edfde`
  recorded `observation_recorded` / `checks_passed` and exit 0. Baseline took
  211.582 seconds; candidate took 197.529 seconds. Both verified effective
  Toolchain settings, KLIB compilation and framework linking, with source
  preservation and quiescent recovery/cleanup of both owned workspaces.
- All four release providers were observed. Kotlin 2.4.20 was eligible for review;
  Metro 1.4.5 and SKIE 0.10.15 remained age-blocked. No newer Toolchain release
  was observed within the bounded response. The reviewed candidate stayed fixed.
- The passing retry reported `scope_changed`, because its resource-observation
  implementation changed. It did not claim a comparable live improvement or
  unchanged result. Quiet repeat, improvement/regression, infrastructure changes,
  provider recovery/failure and invalid history are covered by deterministic fixtures.
- All **180 contracts** passed, including 14 watch contracts and 24 Kotlin
  rehearsal/resource contracts. The five existing static analyzers passed in
  6.674 seconds. Temporary actionlint 1.7.12 passed the changed workflow; its
  downloaded archive matched the upstream SHA-256. Strict OpenSpec validation
  passed all 13 items. No Go application or permanent tool dependency was added.
- Dedicated public outputs were checked for host paths, process/resource identity
  fields and credential patterns. None were present. Raw native logs remain local.

The [two-run public receipt](evidence/2026-09-30-slice-8.json) retains source/config
identities, provider URLs/timestamps/hashes, verified native results, check-log
hashes and separate cleanup outcomes. It preserves each execution's source
identity; later documentation is not attributed to the frozen native snapshot.

## Untested assumptions and remaining limits

Hosted watch history/restore and cold-runner execution require an actual run after
integration. Mobile CI is a separate gate. Compile/link evidence does not establish
native app/test or direct-path retirement coverage. Release discovery is a bounded
page, not full interval/advisory/graph review. Linux and Elixir execution are not
added by this slice. The earlier historical store ownership blocker is unchanged.

## Retained first live outcome

The 2026-09-29 legacy-entry-point run `2acc6fa009ac0543473200d8fbdbebff`
recorded `refused`, with source preserved and disposable workspace cleaned.
Its baseline KLIB compile passed; the framework log reported `BUILD SUCCESSFUL`,
but the post-command ownership observation found a registry PID whose command
was only `(java)`. That lacked valid ownership proof, so the candidate was not
attempted. The watch correctly exited 1 rather than calling the run compatible.

The diagnostic is consistent with argv disappearing during process termination;
the precise operating-system transition was not captured. Resource observation
now performs up to six read-only identity checks over 250 ms. It accepts only
process absence or the existing live ownership proof; persistent unowned or
reused PIDs still refuse cleanup. No unverified PID is signaled. Separate fixtures
exercise transient disappearance and replacement by an unrelated live identity.
The original failed receipt is retained rather than overwritten by a retry.

Initial live discovery also exposed two integration issues: the pinned Ruby has
no OpenSSL extension, and Metro RC tags can have GitHub's prerelease flag false.
The watch uses certificate-verified system curl and excludes semantic prerelease
tags explicitly. All four public provider responses were observed in the first
full watch; no dependency was adopted.
