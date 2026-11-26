## Why

The release watch discovers leads but delegates assessment to manual investigation. Mobi now requires automated assessment before further new-release reviews, and a complete local adoption packet before approval and one adoption PR.

## What Changes

- Add a bounded local assessment pipeline over the existing watch, executor, graph and advisory machinery.
- Bind official release/source/documentation evidence, actual app applicability, workaround leads, qualification and security gaps into one report.
- Preserve incomplete, blocked and baseline-inconclusive results; never infer safety or retirement from discovery or passing builds.
- Reuse the weekly caller without duplicate schedules. Keep raw evidence ignored/artifact-only.
- Separate automation implementation from local dependency assessment, exact-packet approval, adoption PR and merge.

## Capabilities

### New Capabilities

- `automated-release-assessment`: source-bound local assessments with bounded providers, qualification and explicit human adoption gates.

### Modified Capabilities

None.

## Impact

Repo-owned maintenance scripts, contract suites, dependency playbook/backlog and the existing weekly compatibility caller. No dependency adoption, risk acceptance, generated-output edits or required private service.
