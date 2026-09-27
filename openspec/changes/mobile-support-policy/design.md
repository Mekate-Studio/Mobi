## Context

See proposal.md. The approved ARM candidate passed the baseline-first mobile
workflow. OS floors are separate: Android currently declares API 23, the Swift
package declares iOS 16, and Xcode app/test targets inherit 27 from the SDK.
An iOS 26.5 simulator is installed alongside iOS 27.0.

## Goals / Non-Goals

**Goals:** explicit support boundaries, reusable policy selection, source-bound
assessment and a tested candidate before changing app OS minimums.

**Non-Goals:** automatic upgrades, generalized architecture refactoring, raising
Android compile/target SDK as a side effect, changing bridge compiler pins, or
claiming physical-device/release evidence from local simulator tests.

## Decisions

1. Keep a small language-independent support-policy evaluator plus a Kotlin/mobile
   adapter for repository declarations. A reviewed release catalog records stable
   major families, publication dates, API mappings and primary URLs. Choose the
   predecessor by release order, not arithmetic or SDK defaults. Exclude previews,
   reject duplicate/ambiguous history and stale/future evidence.
2. Configure a stable-major lag per platform, default one for Mobi. Pin the resolved
   floor in source. Assessment is manual and read-only; a new OS release reports
   drift and support impact, never silently edits a build or pre-commit gate.
3. Inventory all app/test Xcode configurations, the Swift package and Android app
   minimum separately. Record compile/target SDK independently. Candidate patches
   are exact and source-bound; malformed or unsupported declarations refuse.
4. Keep the approved wrapper/ARM adoption separate from the new minimum candidate.
   Advance the reviewed baseline to 0.12.2, retain historical receipts, and expose
   an OS-only rehearsal using that baseline rather than pretending it is an update.
   Run the current baseline on its current simulator and the candidate on its
   minimum stable-major simulator; name and bind that environment difference.
5. Integrate assessment in dependency discovery and expose a lightweight manual
   command. Compatibility-impacting architecture, API, support-policy and default
   changes require a decision record with preserved/lost capabilities, alternatives,
   rollback and evidence gaps. No generic script can prove arbitrary architecture
   migrations safe; such migrations need explicit adapter/probe work.
6. An optional simple run-store name creates a separate owned store for this host.
   Historical stores are never adopted, renamed or deleted to bypass ownership.

## Risks / Trade-offs

- Reviewed catalogs age or omit releases → bounded freshness and primary-source
  revalidation; no automatic claims of global release completeness.
- Raising Android minimum excludes API 23–35 devices → explicit user policy and
  impact report; no automatic future adoption.
- Lowering the inherited iOS 27 floor exposes older runtime behavior → test on
  installed iOS 26.5, record exact runtime, do not claim every 26.x patch was tested.
- Cold hosted, Android device/runtime and signed packaging are separate → retain
  those missing capabilities after local success.

## Migration Plan

Adopt the approved eight-file ARM patch. Add and validate policy/assessment and
rehearsal support, then run the OS candidate. Apply its exact edits only after
passing checks, refresh onboarding and the adopted receipt, and leave changes
uncommitted. Roll back OS declarations independently from wrappers/architecture.
