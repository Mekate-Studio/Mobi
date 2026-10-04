# ADR 0008: Explicit iOS projections and direct development builds

Status: Accepted for development, repository tests and unsigned builds

Date: 2026-10-04

## Context

The adopted source at `349e07e` still uses the Gradle bridge and SKIE. Paired,
bridge-unavailable interop and operational assessments support preparing a
direct-content candidate. Those assessments do not approve the production API,
default switch, credentialed delivery or bridge deletion.

## Decision

Shared feature modules keep their sealed states, concrete payloads and typed
failure reasons. `shared-di` exposes six visitor protocols and exhaustive Kotlin
dispatch over 27 cases beside its explicit factories. Native Swift adapters
produce six Swift projection enums through `mobiProjection(of:)`; native
consumers switch exhaustively. A new Kotlin case requires corresponding visitor,
Swift enum/adapter and native consumer coverage. Keep Circuit and TCA types in
their platform shells. Keep the facade in the measured common source location
for this first transition.

Preserve async behavior during the build migration. Kotlin services rethrow
cancellation. Home's Swift catch-all produces `Unexpected`; Nearby Map's
catch-all returns its input state. A controlled Kotlin continuation remains
pending after Swift task cancellation until explicit completion. The Home and
controlled-continuation observations were executed in paired fixtures; Nearby's
fallback and the absence of reducer cancellation IDs are source review facts.
Propagation, stale-response protection and deallocation need separate changes
and evidence. Neither builder promises automatic cancellation propagation.

The adopted content uses the Toolchain-managed Xcode integration phase with a
separate repo-owned selector preflight. All development, test and unsigned
callers default to Kotlin and reject Gradle/unknown overrides. Xcode retains its
native app/test targets, Swift packages and TCA ownership. Existing GitHub
variable overrides remain explicit and must be reviewed before rollout.

Credentialed iOS archive/export/TestFlight entry points refuse before signing
or API-key handling. Activating them requires separate signed/export evidence
and risk authorization. Raw unsigned archive assessment remains available.
The maintainer approved this breaking scope decision on 2026-10-04; credentialed delivery remains held.

Keep every bridge and catalog byte for rollback. Returning to Gradle requires
restoring the entire reviewed content patch, cleaning only owned generated
products and revalidating restored consumers. An environment variable alone
cannot undo the projection and integration changes.

## Consequences and approval

Hand-maintained visitors make the export boundary explicit and compiler checked,
but add work when feature states grow. Regular Kotlin export enum spellings are
adapted explicitly in Swift. Earlier generic/identity fixtures support only
their measured cases; they are not a universal lifetime guarantee.

The maintainer approved the reviewed concrete patch, explicit API,
cancellation preservation and unsigned development scope on 2026-10-04. Applied
source/risk bindings retain the existing expiry. Collect hosted
integration at the final approved revision. Physical/exact-floor execution,
broader Compose/resource/onboarding coverage and signed delivery remain distinct
gates. Physical bridge deletion needs its own later decision.

This decision supersedes the iOS Gradle/SKIE build and projection portions of
ADRs 0003 and 0006. Native package ownership and shared sealed-state design remain
accepted. Bridge files remain rollback inputs; physical deletion is a later gate.

## Evidence

- [Interop behavior assessment](../maintenance/direct-interop-behavior-assessment.md)
- [Operational assessment](../maintenance/direct-release-onboarding-assessment.md)
- [Default proposal review](../maintenance/direct-default-proposal-review.md)

- [Applied integration](../maintenance/direct-default-integration.md)
