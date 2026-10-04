## Context

See proposal.md. The owned executor already binds source, code, host inputs, candidate patches and resource recovery. The build-input profile does not execute Xcode. Toolchain 0.13.0 needs compile SDK 37; production minimum and target remain 36.

## Goals / Non-Goals

**Goals:** Extend the same isolated upstream pair with native and packaging profiles; preserve historical receipts and use fresh runs.

**Non-Goals:** Dependency adoption, signing credentials, bridge removal, mandatory private infrastructure or new scheduling.

## Decisions

- Reuse the executor and native resource registry, including exact owned simulator/JVM recovery. Separate mobile, Android packaging, iOS release simulator and unsigned device archive pairs to fit existing bounded execution policy. An interrupted combined packaging pair remains inconclusive; successful narrower pairs are new receipts.
- Select minimum-major 26 in both phases and enable macro validation. Record actual runtime; a 26.5 simulator is not evidence for exact 26.0 or a physical device.
- Remove API 37 only from the candidate's private SDK copy to test provisioning. Preserve accepted host license files and explicitly limit the onboarding claim; this is not an empty host or hosted run.
- Package with validation-only Android signing fixtures and an unsigned iOS archive. Never invoke credentialed export/upload jobs.
- Reuse the independent plugin resolver with per-phase version-bound mappings. Preserve old packet replay, bind the separately reviewed candidate mapping/classpath source bytes and include the expanded bundled query set. Exact file joins remain narrower than shaded-code or native test-input attribution.
- Keep advisory conditions and owner remediation explicit; passing functional tests cannot dismiss an advisory or grant a waiver.

## Risks / Trade-offs

[Native tool/network failure] → Preserve logs and report infrastructure-inconclusive; recover owned resources before cleanup.

[Release policy changes] → Bind the seven-day age state per run and refresh before any future approval.

[Incomplete runtime/signing coverage] → Publish missing capabilities separately; do not infer deployment readiness.

## Migration Plan

Add maintenance-only profiles, run isolated pairs, derive public-safe evidence and prepare source-bound reversible candidate edits. Production changes require a later review and authorization. Recovery and cleanup use existing owned-resource commands; retained receipts remain replayable.
