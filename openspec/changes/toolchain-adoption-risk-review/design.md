## Context

See proposal.md and docs/maintenance/toolchain-security-decision.md. The maintainer selected adoption followed by bridge retirement on 2026-10-04. This establishes direction despite inherited risk, but does not specify an early-age waiver, expiry or acceptance of unmeasured operational gates. Existing discovery/evidence commands deliberately never grant adoption permission.

## Goals / Non-Goals

**Goals:** prepare exact reversible adoption content; distinguish explicit accepted risk from remediation; keep normal freshness/age and platform coverage visible; prioritize direct assessment after integration.

**Non-Goals:** automatic upgrades, broad severity suppression, forced upstream transitive replacement, silent platform support loss, implicit signing/publishing or physical bridge deletion.

## Decisions

1. Use a separate manual decision overlay. Keep maintenance-policy.json and its existing evaluator unchanged until the exact exception proposal is approved. After approval, implement a bounded overlay that consumes a complete policy report and exact artifact/patch bindings. It cannot rewrite finding severities or incomplete states. The alternative of removing High/Critical from blocking_severities would affect unrelated/future updates and is rejected.
2. Propose acceptance only for the ten known High/Critical advisory IDs and exact inherited artifact identities. All seventeen findings remain visible. Recommend at most thirty days from the actual decision, with expiry/drift refusal and revalidation; the maintainer must approve the duration and operations before activation. Propose public source builds/tests and isolated assessment only, with credentialed delivery excluded.
3. Preserve seven-day maturity by default. Adoption on 2026-10-04 requires a separately explicit one-release age waiver; no changed global minimum and no false age_eligible result. The draft can be rehearsed while this choice is pending.
4. Assemble wrappers, SDK 37 compile declaration, matching wrapper/compatibility/plugin mappings and onboarding as one candidate. Keep historical version pins/mappings available. Review original bytes/modes and reject drift before application or rollback.
5. Keep SDK/license setup explicit in repo-owned commands and public docs; no host license copying as empty-host evidence. Cold hosted evidence cannot be claimed before an exact reviewed revision is available for an authorized push/run.
6. After integrated adoption, use existing direct-roundtrip and direct-build-input profiles against 0.13.0 in owned copies. Interop API changes need review and bridge-unavailable/native/operational proof. Gradle remains current iOS builder until a separate approved default change.

## Risks / Trade-offs

- Known Critical/High inputs and unmeasured consumer reachability → explicitly accept residual risk only if approved; isolation narrows execution context without proving absence of exposure.
- New compiler/Compose and SDK provisioning → preserve historical local receipts, execute changed integration checks and fresh complete queries; do not rerun unchanged functional pairs without a new concern.
- Shared dirty checkout → use allowlisted byte/mode-bound candidate patches; preserve unrelated source and index.
- Unavailable exact-floor/physical/signed/hosted proof → retain open cells; obtain explicit scope dispositions before declaring adoption integrated or releasable.
- Bridge retirement may still use delegated Gradle for Android → measure selected inputs again; deleting the hand-maintained iOS bridge does not promise removal of AGP/JDOM/BC from Toolchain.

## Migration Plan

Prepare and verify the draft content and rollback. Review exact risk/age decisions. Implement the approved overlay with refusal contracts; refresh complete evidence and resolve adoption gate dispositions. Apply only the approved allowlist, validate locally, then separately authorize commit/push/hosted checks. Assess the direct path against that integrated tuple. Restore exact adoption preimages on failure and rerun affected consumers. No production change is made by the proposal.
