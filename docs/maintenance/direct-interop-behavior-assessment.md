# Direct typed and asynchronous interop assessment

Date: 2026-10-04. This is the next bounded bridge-retirement assessment after the committed Toolchain 0.13.0 adoption. [PR #35](https://github.com/Mekate-Studio/Mobi/pull/35) passed its seven retained-bridge hosted checks. The local interop fixture result remains a separate review draft.

The retained bridge and bridge-unavailable direct path each passed 38 Android tests, all twelve original Swift cases plus six identical assessment cases, and Android/iOS debug builds. Run `2e3e4f9ed2e0b2857480e57c0482cf3b` in store `interop-parity` recovered to quiescence, discarded its owned generated copies/caches and passed report replay after cleanup. The [bounded receipt](evidence/2026-10-04-direct-interop-behavior.json) binds both phases, exact fixture hashes, executed cases and the retained failure. This does not authorize a default transition.

## Measured fixture behavior

| Fixture | Observed behavior in both paths |
| --- | --- |
| Typed sealed-state adapters | Initial, loading with absent/present previous value, loaded value and typed error payloads survive the existing native adapters. |
| Bounded generic class | An explicitly typed payload box preserves the label, count and object identity without a native `Any` cast. This covers one class, not all generic APIs. |
| Real suspend clients | Actual Kotlin service calls preserve success, repository-unavailable and unexpected failure states, including absent/present previous values. Existing mock-only reducer tests remain intact. |
| Kotlin cancellation | The exported suspend call throws; the current Swift client's catch-all maps it to unexpected state with the previous value retained. The fixture characterizes the existing behavior without fixing it. |
| Swift task cancellation | Cancelling the Swift task leaves the controlled Kotlin standard-library continuation pending. Explicit Kotlin-side completion returns its value. This is not proof about arbitrary coroutine jobs or production effect cancellation. |
| Controlled continuation lifetime | Completion clears the pending slot and a second cycle starts and completes independently. This is not deallocation, leak or universal lifecycle proof. |

The templates and [manual evidence verifier](evidence/probes/verify_interop_parity.rb) are reviewable under `evidence/probes/`. The verifier requires both complete passing producer phases, the twelve verified original identities, all six actual fixture cases, exact fixture bytes/modes, direct bridge absence, source preservation and owned recovery/cleanup. It replays existing compatibility evidence rather than changing a policy evaluator or creating a stronger automatic profile claim.

## Retained failure

The first run `171073d4418e53d9b2f7a70785dcf399` stopped at the baseline Android build because the fixture imported coroutines without a direct dependency in shared DI. Flattened bridge compilation had passed, illustrating why the real module graph still matters. The candidate was not attempted. Its outcome remains `inconclusive` with reason `baseline_failed`; owned recovery reached quiescence, generated copies were discarded and its report replayed after cleanup.

The [initial coroutine-dependent template](evidence/probes/MobiInteropParity.coroutines.kt.template) remains separate. The corrected fixture uses Kotlin's standard continuation API and changes no module declaration or dependency. The corrected run has its own source snapshot and producer identity. No failed run is relabeled as a pass.

## Remaining transition review

The local typed facade preserves sealed Kotlin state and exhaustive visitors at the shared DI boundary, with typed native adapters. Adopting it publicly introduces an explicit projection surface that needs architecture/API review. Bounded native equivalence does not select that architecture automatically.

| Gate | Remaining work |
| --- | --- |
| Architecture/API | Review the explicit facade, factories, future sealed-case changes and retained cancellation policy. The generic/lifetime result closes only the named fixture claims. |
| Native/release | The [separate operational assessment](direct-release-onboarding-assessment.md) passed local and hosted Nightly, unsigned simulator Release, ARM64 device archive and identity/minimum/native-icon inspection in both paths. Physical/exact-floor runtime, wider Compose resources and signed/export delivery retain their independent limits. |
| Onboarding/hosted | Public source retrieval passed on the prepared local host. The three corrected hosted operational pairs passed with artifact digests and read-only replay verified; earlier collector failures and the unretained full run remain distinct. Adoption PR checks executed the retained bridge. Empty-host/operator-license and wider hosted scope stay explicit. |
| Default content | Review the iOS module graph, Xcode integration phase, two projection files, native reason adapter and all builder callers as one reversible patch. Keep the bridge recoverable. |
| Rollback | Restore exact reviewed source preimages and clear incompatible generated products before rebuilding bridge consumers. An environment variable alone cannot restore a changed module/API/Xcode integration. |
| Physical removal | Review separately after an approved default transition and complete applicable parity evidence. Removing the iOS bridge does not remediate the remaining delegated Android build-tool findings. |

The current builder callers include `scripts/ci/lib/ios.sh`, `fastlane/Fastfile`, `scripts/dev/validate.rb`, the Xcode phase and PR/nightly/release workflow environments. Their Gradle selection stays current. A future patch must also review explicit repository-variable overrides and diagnostic defaults rather than changing a single fallback.

The [adoption risk decision](toolchain-adoption-risk-review.md) retains its original scope and expiry. This assessment changes no production source, dependency, default, schedule or release authorization. Follow the [retirement path](bridge-retirement-path.md) before proposing the next transition.

## Replay the retained manual evidence

Resolve the verified repository-locked Ruby and use the retained assessment source/store:

```sh
quality_ruby="$(/usr/bin/ruby -r ./scripts/quality_tools.rb -e 'tools = PinnedQuality::Toolchain.new(Dir.pwd); tools.verify!; puts tools.command("ruby").first')"
"${quality_ruby}" docs/maintenance/evidence/probes/verify_interop_parity.rb \
  .maintenance/commit-series-2026-10-04/checkout . \
  2e3e4f9ed2e0b2857480e57c0482cf3b
```

Reproduction starts from commit `349e07e` in a separate source checkout, copies the two reviewed templates to their receipt-listed paths, verifies/prepares locked tooling/wrappers, then uses the existing `rehearse-compatibility direct-facade --store interop-parity` command. Use the returned run ID for recover, cleanup and verification; preserve new runs as their own evidence.
