## Context

See [proposal.md](proposal.md) for motivation. The current app uses direct typed projections; the maintained candidate is an isolated real-behavior rehearsal, not an app configuration. Read the [adoption handoff](../../../docs/maintenance/swift-export-adoption-plan.md), [candidate review](../../../docs/maintenance/swift-export-candidate-review.md), [macro repair](../../../docs/maintenance/swift-export-macro-repair.md) and [deferred follow-ups](../../../docs/maintenance/swift-export-follow-ups.md) together.

Local evidence under `.maintenance/swift-export-implementation/` includes `final-repaired-qualification-report.json`, `repaired-sequential-matrix-verification.json` and `final-current-execution-input-equivalence.json`. All four profile/policy cases passed cold qualification and guarded post-cleanup replay; 28/28 tasks are complete. These receipts cover local iOS 26.5 simulator execution. The default build and twelve simulator tests passed in raw evidence; its assessment wrapper was refused and must remain refused.

The candidate guide still contains older unassigned-owner and historical-rollback statements. The later handoff/review and explicit instruction govern: Jorge Castro is assigned, and revision `50ae26e4a40c3bc83fe10a2ad05645088330aa63` alone omits the approved repair. Existing documents and evidence remain untouched in this proposal.

## Goals / Non-Goals

**Goals:** Evaluate real app integration through an explicitly selected alternate configuration; make source, module modes, lifetimes, repository access, resources and review inputs inspectable. Share reusable app-facing code with candidate qualification where practical.

**Non-Goals:** Production default selection, signed distribution, automatic dependency adoption, a scheduler, archival, restoring the retired bridge, or claiming hosted/device/minimum-runtime/Android qualification from simulator receipts. No requirement for historical Swift 5 compilers, stable binary ABI or library evolution is introduced.

## Decisions

### 1. Alternate app configuration with an explicit repo-owned command

Add a separately named `SwiftExportPilot` scheme/configuration with isolated output/cache roots, while retaining the current direct configuration. Prefer a generated alternate project when Toolchain regeneration would overwrite custom settings. Keep source selection declarative and inspectable; do not patch the default builder in place.

Proposed command contract (to implement, not available today):

```sh
./scripts/ci/run_job.sh ios-swift-export-pilot --action build \
  --profile coroutine-swift5 --repository-policy main-confined \
  --runtime-settings /absolute/reviewed-pilot-settings.json --compose disabled
./scripts/ci/run_job.sh ios-swift-export-pilot --action test \
  --profile coroutine-swift5 --repository-policy main-confined \
  --runtime-settings /absolute/reviewed-pilot-settings.json --compose enabled
```

The dispatcher delegates to a repo-owned adapter that validates arguments before production, invokes maintained generation/verification and holds one whole-build reader pin. Missing/unknown selections, tuple mismatch and unreviewed settings refuse; no fallback to direct or Gradle occurs. Default smoke commands remain unchanged. GitHub workflow additions are limited to invoking the command after separate hosted-stage authorization. Preserve `studio.mekate.mobi`; configuration-specific outputs avoid installing over the baseline during comparison without inventing a new public bundle identity.

### 2. Initial pilot recommendation and language-mode alternatives

Recommend `coroutine-swift5` plus `main-confined`: only coroutine support requires Swift 5 language mode, and it avoids adding complete-operation serialization before the app cohort demonstrates a need. Explicitly record pilot selection before qualification; it does not select production defaults. Keep `generated-swift5` and `shared-operation-mutex` selectable and trigger applicable requalification when changed. Swift 5 and Swift 6 here are language modes on the recorded installed compiler. Compile Swift 5 support for strict Swift 6 consumers; do not describe it as historical compiler or stable binary distribution qualification.

### 3. One Kotlin delivery and app composition root

For the pilot, one verified joint Kotlin delivery supplies Home, Nearby, facades and optional Compose. Do not link the direct framework alongside exported runtime objects, create a second graph for Shared UI, or pass Kotlin objects across deliveries. One app-lifetime root resolves the actual shared dependency graph once and injects the exact Home service into native and Compose owners and the exact Nearby repository into its cohort hub. The current fixture independently creates its Nearby hub graph; promotion must remove that split rather than copying it as a production pattern.

Promote Home/Nearby facades, wire schema/value copying, native adapters, cancellation relay, admission, polling, drains, shutdown and route ownership into declared `shared-ios-export` and optional `shared-ios-export-compose` modules and maintained iOS-facing Swift sources. Preserve shared platform-neutral feature contracts and Android sources. Use neutral public names instead of probe names. Keep `RootScenario`, transport/Compose qualifications, entry gates, constant clocks, failure injection, forced GC and scripted launch/environment automation outside shipping source membership. Real app location/time providers, TCA reducers, navigation, Home loading/error/retry and Nearby permissions/staleness/rendering remain operational. Optional Compose uses the same Home instance; disabling it excludes its route and composition dependencies as declared by the selected source closure.

### 4. Exact repository cohort and suspension audit

Produce a caller inventory keyed to the actual repository instance and graph lifetime. Inspect shared graph accessors, default service factories, every native Nearby owner/client, Kotlin service/coroutine/background work, optional Compose code and any retained raw repository reference. Home native/Compose peers use the exact Home service and are not Nearby callers; there is no Compose Nearby route today. Tests that create separate graphs are separate cohorts, not proof for the app graph. Seal raw access or make any unguarded caller a blocking finding.

For `main-confined`, assert Main before and after suspension across all callers, with foreign Swift calls entering through the async safe seam. Two refreshes can enter Main, suspend and resume interleaved; confinement does not serialize whole fetches or make read-modify-write transactions atomic. Exercise this overlap against repository mutations and cancellation. If unsafe, repair the repository or explicitly select one shared cohort mutex covering the complete operation and delegate return on Default. Per-client locks/actor annotations cannot substitute. Noncooperative mutex holders can delay all peers; neither policy proves fairness.

### 5. Measured settings and diagnostic review

Introduce a versioned pilot settings record with source/tuple identity, measurement receipts, rationale and review status. Require explicit parent request/Compose-route reservations, per-owner Kotlin job limits, polling/backoff schedule, soft shutdown deadline and busy/retry behavior. Start measurement with declared experimental settings, label them provisional and prohibit a qualified pilot verdict until reviewed. Never silently inherit fixture constants. Measure real navigation, cancellation, manual retry, background/foreground, overlapping owners, sustained polling, peak retained objects/jobs and latency distributions; energy/memory-byte claims need actual instruments beyond poll counts.

Retirement closes admission and cancels delivery, while parent-owned drains retain unfinished Kotlin work. A lease releases only after actual completion; soft deadlines report still-draining and cancelled acknowledgement waiters do not stop cleanup. Tab/background transitions alone do not retire routes. Keep single-scene scope explicit; expanding it requires a new lifetime assessment.

Review findings by tuple/profile/target/emitter/message/location fingerprint. Track coroutine inheritance, Kotlin/C++ casts/target features, generated Swift imports/casts/unused values and MapLibre/SwiftUI runtime findings separately. Record rationale, accountable reviewer, scope and expiry/requalification trigger for each disposition. Unknown findings stay `review_required`; compiler errors/native Swift 6 warnings fail. Preserve historical macro failures and wrapper refusals. The approved tuple is SwiftSyntax 603.0.2 and Perception 2.0.10, including exact Xcode constraint; fresh advisories and broader Perception compatibility are separate inputs. Do not weaken warning/scanner policy.

### 6. Source-bound qualification and complete rollback

Bind the app configuration to full source inventory, descriptor, generator/exporter/compiler/SDK/JDK identities, module modes, native lock revisions, binary checksums, delivery identity, settings and diagnostic review. Requalify affected promoted inputs with cold production and guarded relocated replay; old fixture receipts do not qualify changed shipping code. Exercise actual app tests and resource/plist/privacy/AppIcon/native asset checks, with scripted drivers in test targets only. Compare default raw build/test evidence independently of wrapper status.

Before implementation, capture a fresh content snapshot of tracked and nonignored untracked files, executable modes and symlink targets, plus HEAD, dirty status and an exact hash inventory. Include the repaired lock and matching project constraint; record evidence locations/hashes separately, preserve original evidence in place, and inventory required ignored build inputs if any. Store the snapshot outside disposable build roots. Verify restore into an owned directory and replay the direct build/test path. A proposal-time content snapshot is a starting checkpoint, not a tested rollback receipt: refresh if source changes before implementation. Rollback restores the complete baseline closure, verifies hashes/repair, removes only pilot-owned build products and rechecks direct commands. A flag change or historical revision alone is insufficient. Restoring the user's checkout is a separately authorized live action.

## Risks / Trade-offs

- Custom exporter/compiler coupling → Jorge Castro owns input upgrades, diagnostics, recovery and reproducibility; preserve upstream support limits from the existing handoff.
- Alternate configuration can drift → share app presentation sources, declare exclusions, and test both configurations against real behavior.
- Promoting fixture code changes qualified bytes → inventory the promotion delta and repeat affected cold/replay/app gates.
- Main suspension overlap can violate repository assumptions → audit actual instances and test interleavings before accepting policy.
- Polling/drains can retain work or use energy → measure actual app behavior and refuse unjustified qualified settings; soft deadlines are not backend bounds.
- Same public bundle identity prevents side-by-side installs → compare sequential simulator installs with explicit destinations and preserve independent output roots.
- Ignored local evidence is unavailable to public readers → maintain a durable public summary and reproducible instructions without making local products prerequisites.

## Migration Plan

1. Verify current inputs and snapshot complete repaired direct content; validate restoration in an owned copy.
2. Record explicit provisional pilot choices; promote reusable code and seal graph/cohort boundaries.
3. Add alternate configuration and command, then validate real Home/Nearby and optional Compose with source-bound app tests.
4. Measure settings, review each diagnostic and repeat applicable cold/replay qualification. Publish a bounded review summary in repository documentation without committing/pushing implicitly.
5. Keep each external gate separately recorded: published clean clone, GitHub-hosted macOS, actual device, minimum supported runtime, Android parity, fresh advisories, release/signing. Record deferred or blocked gates honestly; they do not prevent a bounded local pilot report, but they prevent broader adoption claims. Release/signing execution requires separate authorization.
6. Review production selection as a later decision. No scheduler or archive work is included; deferred cadence/history work remains in `swift-export-follow-ups.md`.

## Open Questions

Final numeric limits and diagnostic dispositions depend on pilot measurements and review; the schema and refusal behavior above are fixed. Production profile/policy and broader rollout remain later decisions, not implementation defaults. Whether to enable Compose in the first review run can be selected through the explicit command without changing the design; both configurations require tests before claiming optional Compose support.
