# Direct iOS default proposal review

Current follow-up: the maintainer approved the direct development/test/unsigned
default on 2026-10-04. [Applied integration](direct-default-integration.md) records
current validation separately. Retained-bridge/default exclusions below describe
the historical decisions; credentialed delivery and physical deletion stay held.

This is an unapplied development/test/unsigned default proposal against published
adoption revision `349e07e0929033e8feb71269e9555420d3285e35`. Production remains on
Gradle/SKIE. The proposal preserves bridge/catalog files and dependency versions.
It does not change the current risk decision or grant signing, deletion or
default-switch approval.

## API and async review

[ADR 0008](../adr/0008-explicit-ios-projections-and-direct-development-builds.md)
proposes six typed Kotlin visitor contracts with 27 exhaustive dispatch branches
in shared DI and six native Swift projection enums. `mobiProjection(of:)` makes
the custom API explicit. Consumers retain concrete payloads, typed reasons,
exhaustive switches and explicit feature factories. Circuit/TCA types remain in
their native shells. The facade stays in the measured common source location;
this first migration does not add an unmeasured source-set move.

Kotlin services rethrow cancellation. Home's Swift catch-all produces
`Unexpected`; Nearby Map's catch-all returns its input state. Reducers currently
have no explicit cancellation IDs or stale-response guard. The draft preserves
those clients/reducers byte-for-byte. The paired
[interop assessment](direct-interop-behavior-assessment.md) executed Home's
failure/cancellation fallback and controlled continuation behavior: cancelling
the Swift task leaves the Kotlin continuation pending until explicit completion,
then the fixture clears and completes a second cycle. Nearby's fallback is a
source review fact, not a dedicated executed cancellation fixture. Broad task
propagation, coroutine/lifecycle and deallocation claims remain unmeasured.

## Caller and delivery scope

| Caller | Draft behavior |
| --- | --- |
| Xcode app target | Separate repo-owned preflight before the unchanged Toolchain-managed integration script; native app/test targets and Swift packages remain. |
| CI setup and raw Xcode wrappers | Default/diagnostics select Kotlin and validate overrides before compilation/output setup. |
| Pre-commit | Four selected native jobs use Kotlin in an owned snapshot under explicitly ignored repository storage; source/index/mode and cleanup guards remain. Symlinked or nonignored storage refuses. |
| Fastlane | Kotlin default agrees with shell normalization; environment restoration remains; iOS release lanes hold before signing/API-key calls. |
| Mobile CI, Nightly and release workflows | All six iOS fallback declarations select Kotlin. Repository/environment variable overrides remain explicit and stale Gradle overrides refuse; no remote variable is changed by this review. |
| Credentialed delivery | Repository archive/export/TestFlight entry points refuse before credentials. Xcode's preflight also holds signing-enabled archive and Release device builds. Unsigned assessments explicitly disable signing. |

The scope is an explicit proposed breaking decision: same-tree SKIE delivery
cannot be promised by keeping one caller on Gradle. Credentialed activation
requires separate signed/export evidence and risk authorization. No bypass flag
is introduced. A raw unsigned archive is a capability assessment, not delivery.

## Exact candidate and validation

The [patch](evidence/2026-10-04-direct-default-proposal.patch) and
[receipt](evidence/2026-10-04-direct-default-proposal.json) bind source preimages,
candidate bytes/modes, preserved files and patch identity. Validation is recorded in
the receipt: **287 contracts across 18 suites**, all five static analyzers,
**38 Android tests**, all **12 original Swift cases**, and both debug builds
passed. The native gate used source SHA-256
`0d0d4138dda5ae4de073dd3b3b43e1381342e150c90e328ac95d57121deb2d50`.
Owned snapshot cleanup completed. The final candidate changes only a synthetic
test fixture's ignore profile from that native source; all production/native
bytes and modes are identical. Contracts and static checks executed the final
source. Native jobs were not repeated for that test-only fixture adjustment.

Final candidate source SHA-256:
`80b85721b613ce5c6f8dd8cd1ff96db656e12193d1a2754d0093ba44d0897aab`.
Patch SHA-256:
`651301bf42c6e9949985ce7a9b7d3c4583fbe97efaa2f8d0beac81c6febb85bb`.
The allowlist contains 31 paths; all eleven bridge/catalog paths are preserved.
The receipt retains the sole test-fixture delta and exact native/static/contract
log hashes rather than presenting different source snapshots as one execution.

The [initial draft record](evidence/2026-10-04-direct-default-proposal-initial.json)
and [initial patch](evidence/2026-10-04-direct-default-proposal.initial.patch)
retain the failed native gate separately. Its Android tests passed, but Toolchain
could not resolve the logical `/var` temporary iOS module path against its
physical project root before Swift compilation. The
[canonical-path attempt](evidence/2026-10-04-direct-default-proposal-canonical-attempt.json)
and [its patch](evidence/2026-10-04-direct-default-proposal.canonical-attempt.patch)
passed all eighteen contract suites but repeated the native failure: Xcode
rewrote the physical `/private/var` source path back to `/var`. The final draft
uses explicitly ignored repository-owned snapshot storage, with alias-path,
symlink-storage and nonignored-storage regression contracts. Historical
retained-to-direct transform contracts use an explicit retained integration
fixture; native validation executes the real candidate. The restricted-sandbox
contract attempt could not inspect owned processes and is not compatibility
evidence. No failed attempt is relabeled.

The first repository-storage contract attempt found that the shared synthetic
quality fixture did not declare `.maintenance/` ignored. Its refusal was correct;
the final contract copy adds that ignore entry. The new storage contracts also
prove that symlinked or nonignored storage refuses without touching unrelated
inputs. Fastlane guard contracts execute the actual lane blocks under a minimal
DSL without credentials; they are not signed Fastlane packaging evidence.

The earlier [local/hosted operational pairs](direct-release-onboarding-assessment.md)
and [aggregate hosted receipt](evidence/2026-10-04-hosted-direct-operations.json)
support the design. Hosted run `37203086765` used source `faf6787` and the
experimental helper name; it did not execute this new preflight/default draft.
Exact-revision hosted integration remains required after approval.

## Replay and rollback

The [read-only verifier](evidence/probes/verify_direct_default_patch.rb) checks
patch paths/hash, base revision, every bound preimage/mode, preserved files and
Git apply/reverse applicability. Use a fresh isolated checkout at the base,
separate from the caller's pending review documents:

```sh
/usr/bin/ruby docs/maintenance/evidence/probes/verify_direct_default_patch.rb \
  .maintenance/default-proposal/rollback \
  docs/maintenance/evidence/2026-10-04-direct-default-proposal.json \
  docs/maintenance/evidence/2026-10-04-direct-default-proposal.patch before
```

Use `after` against the exact isolated candidate to verify reversal preconditions.
The verifier does not apply/reverse content, clean products or authorize adoption.
The owned byte-reversal copy proves full source/mode restoration, refusal on
changed bytes/modes and preservation of an unrelated input. It creates no native
products. This is distinct from executing native consumers after reversal of
this new patch; the earlier round-trip's integrated restoration remains separate
supporting evidence. Future rollout rollback must stop positively owned work,
clear only its incompatible generated products, reverse complete reviewed
content and rerun restored consumers. `KOTLIN_IOS_BUILDER=gradle` alone is not
rollback. Current pending documentation must be integrated deliberately rather
than overwritten by an old-base patch.

## Decision and remaining gates

Maintainer approval must cover the facade API, preservation of current async
behavior and development/test/unsigned default with credentialed lanes held.
The current [risk decision](toolchain-adoption-risk-review.md) expressly excludes
`bridge_default_switch`, `credentialed_release_delivery` and
`physical_bridge_deletion`. Its 18 source bindings include README and pre-commit
inputs changed by this draft; exact source/scope review is needed before rollout.
Its expiry remains **2026-11-03T05:48:38Z**. Refresh applicable advisory/provider
evidence within the existing freshness window; bridge retirement does not fix
the inherited Android build-tool findings.

After approval, integrate only reviewed source, collect exact-head hosted PR
checks and confirm both test plans and unsigned product scope on that revision.
Physical/exact-floor runtime, broader Compose/resource coverage, empty-host/SDK
license onboarding and signed/export delivery retain their own gates. Physical
bridge deletion remains a distinct later review after applicable parity and
approved default integration. Review completion does not close those gates.
