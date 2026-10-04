# Direct release and onboarding assessment

This review draft follows the committed Toolchain 0.13.0 adoption and the separate [typed/asynchronous interop assessment](direct-interop-behavior-assessment.md). Production selects the retained Gradle bridge. Its [adoption PR](https://github.com/Mekate-Studio/Mobi/pull/35) passed seven hosted checks at revision `349e07e`.

The complete local operational pair passed and replayed after owned cleanup. All three hosted pairs passed at one source/probe revision, with provider ZIP digests verified and foreign-host read-only replay after owned cleanup. These outcomes establish their measured operations and preserve the independent transition gates below.

| Operation | Local retained/direct pair | Hosted retained/direct pair |
| --- | --- | --- |
| Original twelve Nightly cases | Passed / passed | Verified / verified |
| Unsigned simulator Release and product inspection | Passed / passed | Verified / verified |
| Unsigned ARM64 device archive and product inspection | Passed / passed | Verified / verified |

The operational probe starts from that published revision in a clean isolated source checkout. It uses the existing owned executor, private phase caches, an owned simulator and the reviewed direct transformation only in the candidate's generated copy. The original interop source/store remains independent and replayable.

The [manual probe](evidence/probes/direct_release_probe.rb) and [evidence verifier](evidence/probes/verify_direct_release.rb) require Nightly case identities, unsigned simulator Release, unsigned ARM64 device archive, source preservation and owned recovery/cleanup. Product inspection checks `studio.mekate.mobi`, minimum iOS 26.0, ARM64 slices, Mach-O platform/minimum, native compiled asset catalog/app icon entries and file inventory hashes. It does not establish visual rendering, arbitrary Compose resources, physical-device execution, exact-floor runtime or signed/export delivery.

## Setup scope

A fresh clone from the public GitHub adoption branch was clean at revision `349e07e`, tree `8080301c915fb35815692dfc4092ee677162228c`. Its source manifest SHA-256 was `7607524b09aec13642bb784e922b3228665d872fed091b8384077af4fcd867b3`. The [clone/setup receipt](evidence/2026-10-04-public-clone-setup.json) demonstrates public source retrieval on the prepared local host. SDK licenses already accepted by its operator are recorded as a prerequisite; copied phase licenses do not establish empty-host onboarding.

The manual hosted check uses a separate assessment branch and a workflow-dispatch entry point. It restores no repository cache, explicitly installs/verifies locked quality tools and reviewed Kotlin wrappers, declares JDK 21 and requires existing SDK license acceptance. The [Android setup action](https://raw.githubusercontent.com/android-actions/setup-android/v4/action.yml) supports disabling its default license acceptance; the assessment explicitly disables it. The ordinary production compatibility schedule and all builder defaults remain on their existing branches.

## Execution status

Initial local producer `1d655ee51fe09525415d31cd579dc10f` passed the retained bridge's twelve Nightly cases, unsigned simulator Release/product inspection and unsigned ARM64 archive build. Its archive asset inspection then failed because the host's `assetutil` prepended a duplicate `OS_at_encoder` class warning to valid JSON. Its outcome remains infrastructure-inconclusive; the direct candidate was not attempted. The [initial receipt](evidence/2026-10-04-direct-operations-initial.json) passed replay after owned recovery/cleanup, and the original [probe](evidence/probes/direct_release_probe.initial.rb.template) and [verifier](evidence/probes/verify_direct_release.initial.rb.template) bytes remain separate.

Corrected producer `903a35a38d36439bda97b1a43c68b2eb` passed both complete operational phases: twelve Nightly cases, unsigned simulator Release, unsigned ARM64 device archive and product inspection. Both products retain `studio.mekate.mobi`, minimum iOS 26.0 and ARM64 slices. Each platform's 42 compiled native icon payload records match across the retained and bridge-unavailable direct paths. This does not extend to arbitrary Compose resources.

The [local receipt](evidence/2026-10-04-direct-ios-operations.json) binds both phases (1079.390 and 1251.954 seconds), source preservation, raw command hashes, product facts and icon payload comparison. Owned recovery reached quiescence, generated phase copies/caches were discarded and the receipt replayed after cleanup. The exact [local probe](evidence/probes/direct_release_probe.local.rb.template) and [local verifier](evidence/probes/verify_direct_release.local.rb.template) remain byte-bound to that result.

The local correction uses a narrowly matched known-warning parser that retains the warning's hash and rejects unknown prefixes. Replay against the initial retained output accepted its 42 icon entries; an unknown-class warning refused JSON parsing. It reuses only phase-local Release derived data across simulator/device builds and allows 1800 seconds per phase within the unchanged 2700-second outer policy. No failed producer is relabeled.

The separately published initial manual assessment revision `31db83fe9295b7c906724c4e8373f789e6be6e34` passed the [normal static/native commit hook](evidence/2026-10-04-hosted-direct-commit.json) and was dispatched in [hosted run 37198289492](https://github.com/Mekate-Studio/Mobi/actions/runs/37198289492). Its baseline Nightly command succeeded, but the collector looked for raw cases in runner-formatted output. The assessment remains incomplete and the candidate was not attempted. Manual observation finds the twelve original identities in that formatted output; this does not relabel the producer. The [initial hosted receipt](evidence/2026-10-04-hosted-direct-initial.json) binds the foreign-host hash replay, setup scope and provider artifact digest. The original [foreign evidence reader](evidence/probes/verify_hosted_direct_release.initial.rb.template) remains available.

That runner used macOS 26.6.2, Xcode 26.6 and iOS simulator 26.5, with no repository cache restore and preexisting SDK acceptance. It does not establish exact-floor or empty-host runtime/setup.

The correction at `e2cd390261a7d7a91383d220a1ffec2838e4b06e` passed the normal hook and captured `build/logs/xcodebuild-ios-tests.log` before owned cleanup. In [hosted run 37199743696](https://github.com/Mekate-Studio/Mobi/actions/runs/37199743696), the Nightly command again succeeded but the worker read valid UTF-8 output as US-ASCII. That producer remains infrastructure-inconclusive and its candidate was not attempted. The [retained receipt](evidence/2026-10-04-hosted-direct-raw-ascii.json), original [probe](evidence/probes/direct_release_probe.raw-ascii.rb.template), [verifier](evidence/probes/verify_direct_release.raw-ascii.rb.template) and [foreign reader](evidence/probes/verify_hosted_direct_release.raw-ascii.rb.template) preserve this distinct failure. A local reproduction refuses the ASCII scan and recovers exactly the twelve original identities with explicit UTF-8 decoding.

Revision `3450c1c2e11b4143b07d8e7d4c625a18d74e39db` passed the normal hook and explicitly decodes raw cases as UTF-8. Its [full hosted run 37201067843](https://github.com/Mekate-Studio/Mobi/actions/runs/37201067843) exited 23 during finalization. Upload then rejected a generated Kotlin cache filename containing a colon, leaving no provider artifact. The [failure record](evidence/2026-10-04-hosted-direct-unretained.json) preserves those observable facts. Native cell outcomes, candidate execution and owned recovery/cleanup are unverified; the run is not relabeled as a native failure or timeout. Its exact [probe](evidence/probes/direct_release_probe.utf8-full.rb.template) and [verifier](evidence/probes/verify_direct_release.utf8-full.rb.template) remain separate.

Revision `faf6787742e7b3d49ad64754b8185e76f18a505c` passed the normal static/native hook and declares three smaller operational pairs in [hosted run 37203086765](https://github.com/Mekate-Studio/Mobi/actions/runs/37203086765). Each pair independently measures both the retained and bridge-unavailable paths, preserving the 1800-second phase and 2700-second outer limits. Nightly, simulator Release/product and device archive/product each declare excluded cells as unattempted. Complete hosted operational coverage requires all three passing pairs bound to the same source/probe revision. A green workflow alone will not establish direct bridge retirement.

The [hosted Nightly receipt](evidence/2026-10-04-hosted-direct-nightly.json) verifies both original twelve-case phases (858.249 and 809.089 seconds), source preservation, direct bridge absence, owned recovery/cleanup and foreign-host read-only hash replay. Its provider ZIP digest matches.

The [hosted simulator Release receipt](evidence/2026-10-04-hosted-direct-release.json) verifies both unsigned product phases (997.008 and 1066.812 seconds), the same source/probe binding, owned recovery/cleanup and read-only hash replay. Both products retain `studio.mekate.mobi`, ARM64, minimum iOS 26.0, Mach-O simulator platform 7 and SDK 26.5. Each has 42 compiled native icon entries; their native asset catalog hashes match. File inventories differ, so this is not whole-product binary parity. The provider ZIP digest matches.

The [hosted device archive receipt](evidence/2026-10-04-hosted-direct-archive.json) verifies both unsigned ARM64 archive/product phases (1089.446 and 1152.977 seconds), source preservation, bridge absence, owned recovery/cleanup and read-only replay. Both products retain the same identity and iOS minimum, Mach-O device platform 2, SDK 26.5 and 42 compiled native icon entries. Their native asset catalog hashes match and the provider ZIP digest matches. Neither product was signed, exported or delivered, and no physical device was exercised.

The [aggregate receipt](evidence/2026-10-04-hosted-direct-operations.json) binds all three successful pairs to source SHA-256 `8177b67f961dcfa96ad87d3e9f3ba68c7faf7c7dd391be2172ffa871ca7c0b19` and probe SHA-256 `3bc19fe3811ea10bf83495019ff5811afb44790ac0f7b744139d12e5c14533e2`. All six recorded phases used macOS 26.6.2 and Xcode 26.6; Nightly used simulator runtime 26.5. This closes the named hosted operational checks on that runner. Exact-floor/physical runtime, complete Compose resources, empty-host/license onboarding, signed delivery and architecture/default/removal approval remain outside this result. Phase times include setup and native work and are not application-performance measurements.

The separate finalization/retention fix at `dd9437ea86fb0f6711a8f496f925b9a7fd5f41bc` passed the [normal static/native hook](evidence/2026-10-04-hosted-direct-retention-commit.json). It retains journals and raw step evidence while excluding generated work/cache filenames, and prints bounded terminal outcomes if finalization refuses. The existing guarded recovery handler may stop positively owned active resources; uncertain ownership or a held run still refuses cleanup. This changes no producer probe, risk-bound runtime file, outcome or production default. The successful hosted run remains bound to `faf6787` and its [original launcher](evidence/probes/run_direct_operations.sliced.sh.template); the later retention fix is locally validated, without claiming a hosted execution at that later revision.

## Replay the local operational pair

Resolve the repository-locked Ruby, copy the exact local probe/verifier templates into an ignored replay directory under their original filenames, and retain the assessment source/store:

```sh
quality_ruby="$(/usr/bin/ruby -r ./scripts/quality_tools.rb -e 'tools = PinnedQuality::Toolchain.new(Dir.pwd); tools.verify!; puts tools.command("ruby").first')"
mkdir -p .maintenance/release-continuation/local-replay
cp docs/maintenance/evidence/probes/direct_release_probe.local.rb.template .maintenance/release-continuation/local-replay/direct_release_probe.rb
cp docs/maintenance/evidence/probes/verify_direct_release.local.rb.template .maintenance/release-continuation/local-replay/verify_direct_release.rb
cp docs/maintenance/evidence/probes/MobiInteropParity.original-cases.json .maintenance/release-continuation/local-replay/
"${quality_ruby}" .maintenance/release-continuation/local-replay/verify_direct_release.rb \
  .maintenance/release-continuation/checkout 903a35a38d36439bda97b1a43c68b2eb
```

Fresh reproduction uses a separate checkout, reviewed tooling/wrappers and the current manual probe. Preserve the returned source/probe/producer identities and results; historical templates are for exact retained replay.

## Replay the hosted operational pairs

Retain the three provider artifacts and their ZIPs, metadata and a clean checkout at `faf6787742e7b3d49ad64754b8185e76f18a505c`. The [foreign evidence reader](evidence/probes/verify_hosted_direct_release.rb) treats the downloaded store as data and never rebinds its owner or invokes its recovery/cleanup. With the retained assessment layout:

```sh
for slice in nightly release archive; do
  "${quality_ruby}" docs/maintenance/evidence/probes/verify_hosted_direct_release.rb \
    ".maintenance/hosted-direct/artifact-sliced-${slice}" \
    .maintenance/hosted-direct/source-sliced \
    faf6787742e7b3d49ad64754b8185e76f18a505c
done
```

The aggregate's three receipt hashes and common source/probe binding distinguish complete measured coverage from a single partial pair. Provider ZIP digest verification is recorded separately from producer hash replay.

## Independent transition gates

Architecture review must still select the explicit typed facade and cancellation policy. Device/exact-floor runtime, signed/export delivery and complete resource/target coverage retain their own scope. A default proposal must review the module graph, Xcode phase, native adapters and every builder caller as one reversible patch; rollback restores source preimages and clears incompatible generated products. Physical bridge removal remains a later decision.

The subsequent [direct-default proposal review](direct-default-proposal-review.md) makes that API/cancellation/caller and rollback decision concrete as an unapplied draft. It does not inherit hosted execution at its new source identity or extend the risk acceptance.

The [risk acceptance](toolchain-adoption-risk-review.md) retains its original artifact tuples, allowed operations and 2026-11-03T05:48:38Z expiry. No assessment outcome extends that decision or authorizes a production transition.
