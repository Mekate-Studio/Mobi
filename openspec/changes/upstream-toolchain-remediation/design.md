## Context

See proposal.md. Toolchain 0.12.2 delegates Android to Gradle/AGP; the prior build-input profile and advisory review measured 17 matches. Toolchain 0.13.0 is released but still age-blocked and announces changed Kotlin/Compose defaults, required Android metadata and initial SwiftPM import support.

## Goals / Non-Goals

Goals: execute and compare a reviewed upstream candidate; track SwiftPM with its actual directional scope and independent acceptance gates.
Non-goals: transitive force-version overrides, automatic adoption, production wrapper edits, SwiftPM migration, native bridge deletion or treating compiler success as remediation.

## Decisions

Reuse the common executor, private SDK/cache/JVM ownership and build-input collector. Add a retained-bridge `upstream-build-inputs` profile using independently pinned wrappers. Explicit experimental mode records publication, eligibility and a release-age gap; normal rehearsal keeps the seven-day rule. Validate new parser/telemetry shapes against versioned output rather than trusting a banner.

Begin with wrapper changes only in the candidate. If release-required build metadata prevents execution, retain that failure and rehearse the smallest reviewed metadata patch in a fresh pair. The first wrapper-only attempt revealed Compose 1.12.1 AAR minimum compile SDK 37 against Mobi compile SDK 36. The explicit `--compile-sdk 37` candidate changes only the application compile SDK; minimum SDK 36 and target SDK 36 remain declared. Installed SDK 37.0 is used in the private SDK copy. The patch proved Android assembly; 0.13.0 then stopped at a new Xcode first-launch readiness requirement. A read-only preflight prevents repeating cold pairs until the host is ready. Host setup requires separate authorization and is never performed by the adapter. The user authorized the host first-launch setup after the second attempt; installation succeeded and the read-only check passed before a fresh pair. No caller module declaration is changed. Use actual selected delegated graphs, not upstream catalog versions, for fresh advisory comparison. Keep compiler file fingerprints distinct from plugin coordinate attribution.

Track SwiftPM import/Clang Objective-C API support as a hypothesis. Its contribution to existing native packages/macros, Xcode ownership, Kotlin-to-Swift consumers and packaging requires separate tests. Re-evaluate it when a blocker falls in that scope; do not automatically change package ownership.

The passing pair exposed a second compatibility change: 0.13.0 delegated settings use 215 bundled files instead of named Maven components. A smaller provider lookup cannot establish remediation. Match verified candidate file SHA-256 and byte length against verified baseline artifacts; require a unique component reference and keep candidate Maven resolution/variant claims separate. Bind both retained producer sets and the derivation implementation hash. The measured 183 unique references expand the fresh lookup to 538 inputs and 16 findings; 32 files remain unassigned and the absent KAPT finding is not a proven fix. Preserve the initial named-only receipt, report `attribution_incomplete`, and require attribution and risk review before adoption.

## Risks / Trade-offs

Output/schema drift → strict versioned parsers and retained producer failures.
Candidate compile/metadata incompatibility → source-bound failure, supported minimal isolated patch, fresh baseline/candidate pair.
Unchanged upstream transitives → explicit unresolved advisory states and owner-supported follow-up.
Long native/compiler probes → existing timeouts, process/JVM recovery and disposable cleanup.

## Migration Plan

Pin primary release/wrappers, add the manual profile and refusal contracts, run bounded current-versus-upstream evidence, refresh advisories, recover/clean, publish results and decision implications. Application adoption remains a later explicit approval step.
