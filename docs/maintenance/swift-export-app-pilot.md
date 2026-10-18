# Opt-in real-app Swift export pilot

See the [evidence summary](swift-export-app-pilot-evidence.md) for qualification scope and retained receipts.

Jorge Castro maintains this experimental configuration. The initial local selection is `coroutine-swift5` with `main-confined` repository access. Production profile, policy, runtime limits and diagnostic dispositions remain pending review.

The default iOS project continues to use the repaired direct integration. The pilot command generates an alternate `SwiftExportPilot` project under an owned maintenance run. Its app identity is `studio.mekate.mobi`. It links one exported Kotlin delivery and uses one private `AppComposition` graph. Native Home and optional shared Home receive the same service; all Nearby owners share the graph's exact repository through one hub. The retired iOS Gradle bridge is not part of either path.

Use an explicit Ruby installation with xcodeproj 1.28.1 and an explicit JDK. Inspect the selected shipping source inventory before preparing a settings record:

```sh
MOBI_SWIFT_EXPORT_RUBY=/opt/homebrew/opt/ruby/bin/ruby \
JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-26.jdk/Contents/Home \
./scripts/ci/run_job.sh ios-swift-export-pilot \
  --action inspect --profile coroutine-swift5 \
  --repository-policy main-confined --compose disabled
```

The settings record must use schema 1, bind the inspection's source/tuple identities, and explicitly provide positive parent/per-owner counts and polling/backoff/shutdown observation intervals. Experimental records require `--experimental`; qualified settings require reviewed measurement receipts. See `scripts/maintenance/test_swift_export_pilot_review.rb` for accepted and refused records.

Run `--action test` with the same selections and `--runtime-settings PATH --experimental`. Select `--compose enabled` explicitly for shared Home membership and regenerate the settings identity. Cold original and reordered-enum phases compile the declared source closure, seal a complete delivery, build it in its original and relocated locations, and run the test-host/client and UI suites. Changing repository sources during the run invalidates the receipt.

Guarded `--action replay --delivery PATH --origin-run ID` requires a passed integrated origin, an unchanged source/tool/settings tuple, a verified retained delivery, removed origin work and positive quiescence evidence. A failed or stopped origin cannot qualify replay.

The local repaired rollback content is `.maintenance/swift-export-app-pilot-implementation/baseline-content.tar.gz`, with mode/hash inventory in `baseline-content-manifest.json`. It includes the approved SwiftSyntax/Perception repair; historical HEAD alone does not reproduce this baseline. A restored owned copy passed a direct simulator build and twelve tests. Preserve raw results separately from the earlier maintenance wrapper refusal.

Local simulator results do not qualify hosted runners, published clean clones, physical devices, minimum runtimes, Android parity, fresh advisories or signed release. Runtime settings and diagnostics remain review-required until source/tuple-bound measurements and dispositions are accepted.

| Independent gate | Current pilot status | Next step |
| --- | --- | --- |
| Published clean clone | Unqualified | Validate published shipping sources and documented bootstrap after publication authorization |
| GitHub hosted runners | Unqualified | Authorize and run the explicit pilot lane on cold hosted runners |
| Physical device | Unqualified | Authorize a device build and real navigation/lifetime checks |
| Minimum runtime | Unqualified | Select supported runtime floors and test each floor |
| Android parity | Unqualified for this pilot | Run the affected Android checks separately; delegated bootstrap remains preserved |
| Fresh advisories | Review required | Perform a source/tuple-bound authenticated advisory review |
| Signed release | Unqualified | Separate signing/credential/release authorization and evidence |

Runtime settings, diagnostic acceptance and default switching are separate
review decisions. This implementation does not schedule checks, archive the
change, commit, push or choose a production default.
