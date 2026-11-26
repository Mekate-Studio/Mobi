## 1. Assessment contract

- [x] 1.1 Record the full-local-assessment, approval, single-adoption-PR refinement in the backlog and playbook.
- [x] 1.2 Audit existing schedules, source providers, graph/advisory helpers and native executor integration points.

## 2. Implementation

- [x] 2.1 Implement bounded official interval/evidence acquisition with explicit truncation, failure and freshness states.
- [x] 2.2 Implement actual-source/workaround mapping, candidate patch preparation, qualification and graph/security assessment in one local packet.
- [x] 2.3 Enforce recommendation prerequisites, exact source/patch/evidence bindings, serial execution and cleanup.
- [x] 2.4 Reuse the existing weekly caller and compact reporting/artifact policy without duplicate schedules.

## 3. Evidence

- [x] 3.1 Add meaningful contracts for interval gaps, prereleases, drift, provenance, baseline failure and recommendation refusal.
- [x] 3.2 Demonstrate a real end-to-end automated assessment and record its actual coverage and limitations.
- [ ] 3.3 Pass the normal local gate and hosted CI for the automation implementation PR.

## Current evidence and remaining work

The expanded local pipeline has 30 assessment contracts plus four archive-scanner
cases, and uses all 23 pinned suites. The [November 26 proof](../../../docs/maintenance/evidence/2026-11-26-automated-release-assessment.md)
records a real end-to-end run: complete 731-file official interval, both native
phases passed, fresh security requests attempted and owned cleanup completed.
Its incomplete result retains actual source-format, provenance and provider
gaps. A guarded offline replay proves partial observations cannot clear findings.
The normal commit/hosted gates are still pending.

Successful phase workspaces can now be released after quiescence, retaining
evidence and reducing simultaneous disk use. Assessment requires 14 GiB free
before allocating a phase; unrelated checkouts, stashes and caches stay intact.
The original executor default still retains workspaces. The new full pipeline
must report actual authority, format and security-provenance gaps without
claiming prerequisite completion. No investigation/adoption PR has been opened.
