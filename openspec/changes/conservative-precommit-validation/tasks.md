## 1. Conservative selection

- [x] 1.1 Fix manifest precedence and exact-path/rename handling with regression fixtures.
- [x] 1.2 Share validated graph-based host-test discovery and reject uncovered targets.

## 2. Validation execution

- [x] 2.1 Separate validation preparation from version/release/global-install mutation.
- [x] 2.2 Add staged plan and owned-snapshot orchestration with drift, failure and cleanup guards.

## 3. Evidence and handoff

- [x] 3.1 Exercise selection, discovery, prep and orchestration failure paths in disposable fixtures.
- [x] 3.2 Run static and useful native probes; record hosted slice 2 status separately.
- [x] 3.3 Update public documentation/evidence and strictly validate the change.
- [x] 3.4 Stop validation-owned Gradle daemons before cleanup, handle transient shutdown metadata, verify bounded failures and rerun the real gate.

The original iOS baseline failure was traced to three Swift dependencies. Their
reviewed updates were approved and adopted locally on 2026-09-23 after passing
isolated native tests. The full local staged gate subsequently passed after
fixing scoped Gradle shutdown and cleanup; these tasks do not establish hosted
slice 3 validation. See
`docs/maintenance/third-slice-validation.md`.
