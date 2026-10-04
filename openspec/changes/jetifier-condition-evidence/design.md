## Context

See proposal.md. The existing private init script observes generated Tooling API builds and stores normalized settings/buildscript/project graphs. Build-input receipts already bind that output and support replay after disposable cleanup. Older successful producer packets must remain readable.

## Goals / Non-Goals

**Goals:** Measure effective AGP ProjectOptions and a bounded Gradle transform observation interval; interpret conditions conservatively; reuse the existing upstream build-input pair and resource ownership.

**Non-Goals:** Replace AGP transitives, harden a third-party parser, suppress findings, prove whole-application reachability, remove the iOS bridge or alter release/schedule policy.

## Decisions

- Add optional condition fields to the existing delegated graph producer. Graph schema and original graph checks remain backward-compatible; an explicit consumer-condition interpreter supplies the stronger new contract.
- Read ProjectOptions from actual Android plugin instances and capture only the Jetifier boolean plus explicit property presence/value. Do not copy arbitrary Gradle properties or credentials. Default documentation alone supplies no effective value.
- Attach a version-bound build-operation listener before resolution/tasks. Capture transform descriptors and bounded input identities when supported. Unknown API, missing identities or overflow remains incomplete. Public task listeners alone miss artifact transforms, so they cannot establish a negative observation.
- Separate effective settings, listener coverage, execution and remediation conclusions. Disabled/nonexecuted builds advance only bounded condition evidence; all advisory and adoption policy gates remain independent.
- Add interpretation to the existing verified compatibility report, using its retained graph reference/hash. Historical producers yield unmeasured conditions rather than failing their earlier graph capability.

## Risks / Trade-offs

- Internal Gradle/AGP APIs can change → bind support to measured versions, retain explicit incomplete reasons and validate a real isolated pair.
- Transform descriptors may omit verifiable inputs → retain execution observations without unsupported complete-input claims.
- Resolution itself triggers transforms → listener starts before graph collection and reports the full bounded generated-build interval.
- Large or sensitive event payloads → bounded event count, whitelist fields, normalize owned roots and fingerprint only owned artifact files.
- A false option is mistaken for risk acceptance → interpreter always retains review-required and adoption false.

## Migration Plan

Implement observer and conservative reader; add refusal/history contracts; run the existing fresh upstream baseline/candidate build-input profile; recover and discard private work; publish source-bound results and owner-release discovery. Rollback is removal of the optional observer/report extension; production inputs remain unchanged.
