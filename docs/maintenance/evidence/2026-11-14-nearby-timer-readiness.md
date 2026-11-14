# Nearby timer test readiness — 2026-11-14

Base: `070774be95bf16b10c6bb632e45ef9e63b56d1a3`, after PR #107.
The five existing timer tests now scope host creation, clock advancement and
cleanup with the already pinned `withMainSerialExecutor` API. Their previous
scope covered each clock advance only. The fixture also checks that an active,
visible rendered state has a scheduled clock sleep using the pinned public
`TestClock.checkSuspension()` API. All existing timing, cancellation, background,
reentry and admitted-request assertions and one-minute limits remain.

## Reason and cost

Concurrency Extras 1.3.2's [implementation and documented scope](https://github.com/pointfreeco/swift-concurrency-extras/blob/5a3825302b1a0d744183200915a47b508c828e6f/Sources/ConcurrencyExtras/MainSerialExecutor.swift)
covers tasks spawned within the operation. Keeping timer creation outside the
scope does not express that ownership. Five lexical test scopes replace the
per-advance scope; most Swift diff lines are indentation. No new clock, task
registry, startup callback, dependency or production API is introduced.

The trade-off remains **IOS-13**: the library temporarily changes a process-wide
executor hook. It is not compiler-checked per-test isolation. Its setting is
held across the complete scenario, including cleanup, and the existing serialized
parent remains necessary. No parallel-test qualification or workaround retirement
is claimed.

Clocks 1.0.6's [public checker and advance implementation](https://github.com/pointfreeco/swift-clocks/blob/cc46202b53476d64e824e0b6612da09d84ffde8e/Sources/Clocks/TestClock.swift)
both yield internally. `checkSuspension()` throws `SuspensionError` when a sleep
is scheduled; the fixture deliberately expects that outcome for active visible
states. This is an observable readiness assertion, **not** a new awaitable
registration barrier or proof of deterministic SwiftUI task startup.

## Evidence and limits

Local tools: Xcode 27.2 / Swift 6.4.2, iPhone Air simulator / iOS 26.5.

- The unchanged full iOS baseline passes 79 test functions, with no failures or
  skips. Adding the readiness assertion before changing executor scope also
  passes the full suite.
- A diagnostic-only private Clocks checkout removed the checker's internal
  yield, leaving clock advancement unchanged. All five timer scenarios still
  pass. The historical zero-tick failure was **not reproduced**; this experiment
  does not establish its cause. The original checkout bytes and clean Git state
  were restored before normal candidate qualification.
- Candidate focused qualification passes all five scenarios with unmodified
  dependencies. Five test iterations pass 25 executions with no failures or
  skips, using no retry-on-failure setting. The result does not establish five
  independent app launches or long-run reliability.
- The missing-timer negative control and final normal staged/hosted gates are
  recorded in the PR, with exact source and outcomes. Final gates use unmodified
  package sources; no diagnostic dependency patch is delivered.

The [historical CI failure](https://github.com/Mekate-Studio/Mobi/actions/runs/42888555623/job/130083362028)
and unchanged passing rerun remain evidence of an unresolved reliability issue.
This change improves scope and failure observability; it does not call that flake
fixed or attribute it to Kotlin/exporter code. Signed/device and OS scene delivery
are outside this test-fixture slice.

## Reassessment

On Clocks, Concurrency Extras, TCA, Swift or Xcode updates, requalify all five
scenarios and the full native suite with their original limits. Remove the
executor scopes only after supported per-test scheduling qualifies the actual
tests, including cold local/hosted runs and the existing cancellation controls.
Review the readiness assertion separately if the clock API gains an awaitable
registration boundary. Keep the original failure open until evidence supports
attribution and closure; no retries, sleeps or scheduler-count overrides close it.
