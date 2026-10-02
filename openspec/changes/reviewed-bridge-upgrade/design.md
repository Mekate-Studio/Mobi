## Context

Slice 7 validates the reviewed tuple through native jobs; slice 8 watches only compile/link. Neither captures the complete Gradle resolution graph. Toolchain 0.12.2 still supplies its own Kotlin/Compose defaults, independently of the bridge compiler. The reviewed tuple upgrades the bridge and explicit Metro module dependencies.

## Goals / Non-Goals

**Goals:** Obtain reproducible paired graph evidence and a concrete manual adoption decision, with artifact and policy identities and retained failures.

**Non-Goals:** Automatic dependency selection/adoption, direct-path qualification, bridge removal, a new executor, new schedules or Elixir activation.

## Decisions

- Add a manual profile to the existing executor instead of running ad hoc builds against the main checkout. Native jobs, process/resource ownership, time limits and cleanup remain shared.
- Query Toolchain's versioned dependency introspection and every resolvable Gradle project/buildscript configuration. An init script uses public resolution APIs to retain configuration attributes, selected components, dependency edges, variants and artifact hashes. Unresolvable configurations are explicitly inventoried; failed resolution never becomes an empty passing graph.
- Materialize Kotlin's existing SwiftPM lock-file metadata project output before hashing it. Resolution alone does not execute that producer. Directory-valued Native distributions receive tree fingerprints; missing outputs and unknown identities still fail. The paired verified report closes only the bridge graph scope and emits normalized Maven queries with constraint labels excluded and provider status `not_queried`.
- Keep acquisition and human semantic review distinct. Capture primary upstream release history across each exact interval and relevant source/guidance, then map changes to Mobi consumers. Query advisories against the resolved package/version set; report unmapped/compiler/OS coverage rather than claiming a universal security clearance.
- Produce the patch through the existing adapter and bind its path/content identities to the rehearsal. Include a separately reviewed Renovate ceiling update only if the exact new tuple supports the policy. No generic mutating adoption command is needed for one small integration.
- Refresh the stable-major OS assessment independently. Architecture or OS changes need a named decision; this tuple retains the adopted ARM targets and Android 16/iOS 26 declarations.

## Risks / Trade-offs

- Full configuration resolution may reveal latent missing artifacts or fail on network access: retain partial graphs and mark the assessment incomplete/inconclusive; establish the baseline before attempting the candidate.
- Toolchain graphs and downloaded-cache hashes are not a universal repository-origin or compiler provenance proof: identify those gaps explicitly in the review packet.
- Advisory feeds have ecosystem/coverage limits: bind queries/results and age to exact resolved inputs and leave unsupported dependencies incomplete.
- The October 2 review found moderate advisories in Kotlin Gradle plugin 2.3.20/2.4.10 and OpenTelemetry API 1.41.0. Inspection narrows likely applicability to unused KAPT/Swift-export tooling but does not establish security remediation. Recommend assessing Kotlin 2.4.20 with a reviewed Metro and SKIE 0.10.15 after its seven-day age threshold; no newer tuple inherits the measured result.
- Evidence becomes stale or source changes before adoption: rerun affected checks and reject drift rather than applying an obsolete patch.

## Migration Plan

Implement and contract-test the manual profile, capture sources and paired native/graph evidence, recover/clean owned resources, then produce the review packet. Apply only after the maintainer approves the exact scope; final staged and hosted checks remain distinct integration gates. Rollback is the reverse reviewed patch after verifying file identities.
