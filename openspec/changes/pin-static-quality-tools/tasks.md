## 1. Reviewed identities

- [x] 1.1 Lock primary release artifacts, source checksums, runtime versions and existing rule profiles; document selection evidence.

## 2. Installation and offline enforcement

- [x] 2.1 Implement isolated explicit setup, verification receipts, atomic completion and failure/repair handling.
- [x] 2.2 Route existing commands through the verified private runtime and fail before analysis on tool or rule drift.
- [x] 2.3 Integrate the existing quality CI job without changing native/release jobs.

## 3. Verification and handoff

- [x] 3.1 Adapt static-gate contracts and add negative bootstrap/version/checksum/runtime/recovery tests.
- [x] 3.2 Rehearse a fresh installation, offline reuse, the complete gate and representative real violations.
- [x] 3.3 Record measured evidence, update public onboarding and maintenance status, and validate this OpenSpec change.
