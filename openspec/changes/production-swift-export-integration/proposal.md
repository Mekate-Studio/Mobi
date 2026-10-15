## Why

Mobi's direct iOS path requires handwritten Kotlin visitors and Swift projections for shared sealed state. The qualified Swift-export pilot provides integration evidence, but its manually coordinated wire tags, decoders and polling machinery also carry maintenance costs; promoting it unchanged would not resolve the reason for this investigation.

## What Changes

- Prepare one production iOS integration that supersedes the alternate pilot configuration, preserves Native Home, Nearby Map and Shared UI, and consumes one Kotlin delivery and the same Home service.
- Make state evolution a first-class acceptance condition: exercise a new variant, payload change and declaration reorder in an owned source copy, record every required edit, and prove that omitted mappings fail visibly. Reject another handwritten visitor layer or parallel numeric-tag tables as the production contract.
- Compare concrete state-boundary alternatives before selecting one. Treat the current synchronous facade as a safety candidate, not a maintainability decision already made by passing pilot tests.
- Record critical design decisions with alternatives, evidence, costs and proposed choice. Build an explicitly provisional integrated candidate so the maintainer can review actual feature changes and supporting machinery in the draft PR before accepting the design. Obtain explicit disposition before production/default adoption; preserve the option to revise or defer migration.
- Qualify the selected API/isolation, generated-import checks, repository concurrency and measured runtime settings against the actual app with Shared UI enabled.
- Attribute the selected production dependency graph, refresh diagnostics/advisories, verify private JVM temp controls, and remediate findings or obtain a new bounded risk decision.
- After qualification and explicit adoption, **BREAKING**: replace the default iOS composition/build contract and retire obsolete visitor/projection and pilot-only app wiring. Preserve complete content rollback and historical evidence.

## Capabilities

### New Capabilities

- `production-swift-export-app`: Maintainable shared-state transport, reviewed production choices, coherent native/shared UI integration, qualified build delivery and explicit adoption/rollback gates.

### Modified Capabilities

None. Existing Nearby domain and native map rendering requirements remain unchanged. Related pilot and direct-path change records remain historical evidence until their normal archival process.

## Impact

Expected areas are `shared-ios-export`, `shared-ios-export-compose`, iOS composition/adapters/project inputs, the existing projections in `shared-di` and `ios-app/src`, repo-owned maintenance/CI/dev commands, feature guidance and ADRs. Pilot implementation may supply reusable components but is not assumed to be the final design. Dependency changes require their own assessment and decision; no upgrade or vendor-JAR substitution is selected here.

The [decision review](decision-review.md) is the entry point for maintainer review. This proposal creates no production selection, risk acceptance, numeric budget, commit, push or PR merge. Public identity remains `studio.mekate.mobi`; the hand-maintained iOS Gradle bridge stays retired and delegated Android bootstrap remains intact.

Review cadence agreed 2026-10-15: proceed with the typed-state/completion candidate
provisionally, assess composition/build, integrate Home then Nearby and Shared UI,
and prepare a draft PR once a meaningful slice passes the exact commit gates.
Review actual new-state/payload edits and omitted-handling failures there. This
authorizes candidate implementation for evaluation, not final design acceptance,
dependency-risk acceptance, production defaults or merge.
