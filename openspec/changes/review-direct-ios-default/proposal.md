## Why

The adopted Toolchain tuple now has passing bridge-unavailable input, interop, local operational and hosted operational evidence. The next decision needs a concrete public API and reversible content/default patch; those measurements do not select the facade or change production defaults automatically.

## What Changes

- Review an explicit typed Kotlin visitor facade at `shared-di`, with native Swift projections and exhaustive state/reason switches. Use a Mobi-specific projection name rather than impersonating SKIE's generated `onEnum` helper.
- Preserve current Kotlin/Swift cancellation and failure fallbacks during migration; record where production behavior is inspected rather than executed by a dedicated fixture.
- Assemble and validate an unapplied patch against published adoption revision `349e07e`, including DI reachability, the managed Xcode integration phase, native consumers, every builder default/diagnostic and public guidance.
- **BREAKING, proposed only:** direct-content builds reject a Gradle selector. Rollback restores the complete reviewed content patch before selecting Gradle; it is not an environment-only switch.
- **BREAKING, proposed only:** credentialed iOS archive/export/upload entry points remain held until separate signing/delivery evidence and risk authorization exist. Unsigned compiler/archive assessments remain available.
- Retain the bridge directory byte-for-byte and prepare exact reverse application with generated-product cleanup and consumer revalidation.

## Capabilities

### New Capabilities

- `direct-ios-default-review`: A source-bound facade/cancellation/caller review and reversible draft with explicit adoption and missing-capability gates.

### Modified Capabilities

None. Accepted architecture decisions and production defaults remain current during this review.

## Impact

The draft affects the iOS module graph, shared DI projection, native adapters/tests, Xcode phases, repository CI/pre-commit/Fastlane callers, GitHub iOS defaults and public reference guidance. It changes no dependency version, feature-state algebra, app identity, OS floor, schedule or Android build ownership. The existing risk acceptance excludes a default switch and credentialed delivery; approval and exact scope/source-binding review remain prerequisites to adoption. Physical bridge deletion is a later change.
