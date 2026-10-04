# Retained-bridge Toolchain adoption gates

These manual profiles extend the [upstream remediation rehearsal](upstream-toolchain-remediation.md). They compare the pinned production Toolchain with the reviewed candidate in disposable owned workspaces. They preserve the Gradle bridge, original Xcode app/test targets, Swift adapters, compiler-plugin declarations, application identity, and minimum/target OS declarations. Passing checks provide review evidence; they never authorize adoption or bridge retirement.

These paired profiles currently use the macOS mobile preflight, including Xcode readiness, JDK 21, an Android SDK and the repository-pinned Ruby runtime. Even the Android packaging profile uses that preflight; portable Linux execution has not been validated. Follow the public [local setup guide](../reference/local-development.md) and record missing prerequisites as setup failures.

## Run separately

```sh
./scripts/dev/dependency_updates.sh prepare-kotlin
./scripts/dev/dependency_updates.sh rehearse-upstream --experimental --compile-sdk 37 --profile mobile --store adoption-native
./scripts/dev/dependency_updates.sh rehearse-upstream --experimental --compile-sdk 37 --profile android-packaging --store adoption-android-packaging
./scripts/dev/dependency_updates.sh rehearse-upstream --experimental --compile-sdk 37 --profile ios-release --store adoption-ios-release
./scripts/dev/dependency_updates.sh rehearse-upstream --experimental --compile-sdk 37 --profile ios-archive --store adoption-ios-archive
```

Run one pair at a time on a constrained host. Keep the source snapshot unchanged until each pair completes. `--experimental` admits an age-blocked reviewed release for evidence gathering only; normal runs enforce release age. No schedule, private infrastructure, or AI access is required.

| Profile | Required evidence in both phases |
| --- | --- |
| `build-inputs` (default) | Android tests/debug APK, shared ARM KLIBs, graph and compiler-input evidence |
| `mobile` | ARM simulator framework compile/link; Android tests/debug APK; original Xcode native tests and debug app |
| `android-packaging` | Repository debug job with synthetic signing inputs; release APK; repository AAB job |
| `ios-release` | Repository unsigned Release simulator app job |
| `ios-archive` | Unsigned Release ARM device archive of the existing Xcode app; no export or upload |

The explicit compile SDK 37 patch is required for these candidate native/packaging profiles. It changes only the candidate application compile SDK, leaving minimum and target SDK 36. The adapter rejects unknown profiles and the oversized combined `packaging` profile; its interrupted historical receipt remains inconclusive. Narrower profiles use the existing 45-minute overall budget and bounded checks rather than raising release defaults or time limits.

The native profile selects an owned simulator of the declared minimum iOS major in both phases. Record its actual runtime patch version. Macro validation is enabled (`SKIP_MACRO_VALIDATION=NO`), overriding an inherited skip flag. Packaging profiles create no simulator and do not execute tests. The archive uses unsigned signing settings and the repository's explicit-module workaround; it does not exercise the credentialed release delivery path.

For `mobile` and `android-packaging`, the candidate removes API 37 and build tools 37 only from its private SDK copy before automatic provisioning. The host SDK and accepted license files remain untouched. Successful provisioning with copied host licenses is narrower than onboarding on an empty machine or a cold hosted runner. Missing licenses are recorded; the workflow does not accept them. Xcode first-launch readiness is checked read-only; machine-wide setup requires separate authorization.

## Inspect, recover, retain

```sh
./scripts/dev/dependency_updates.sh compatibility-report RUN_ID --store STORE
./scripts/dev/dependency_updates.sh recover RUN_ID --stop --store STORE
./scripts/dev/dependency_updates.sh cleanup RUN_ID --apply --discard --store STORE
./scripts/dev/dependency_updates.sh compatibility-report RUN_ID --store STORE
```

Read the original outcome, both phases, command logs, source preservation, candidate age, actual simulator/macro/SDK evidence and artifact fingerprints. Review product metadata before discarding products. Report verification rechecks retained output and reference hashes, plus profile-specific capability requirements; a consistent receipt with an omitted required job refuses verification.

Recovery verifies owned process group/JVM identities and recognized detached native compiler children, including private binaries and Xcode commands bound to the private project. It rechecks PID, user, group, start identity and executable fingerprint before signaling; identity changes refuse cleanup. This is scoped recognition, not authority to terminate arbitrary host processes. Owned simulators are recovered separately. Cleanup requires quiescence and removes only disposable owned files; control receipts and failures remain replayable. Never replace a failed or inconclusive run with a successful retry.

## Android minimum-runtime supplement

After a fresh passing `mobile` pair, before source edits or product cleanup, run the repository-owned probe against its baseline and candidate APKs:

```sh
PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin \
/usr/bin/ruby -r ./scripts/quality_tools.rb -e \
'exec(*PinnedQuality::Toolchain.new(Dir.pwd).command("ruby"), "scripts/maintenance/android_runtime_probe.rb", *ARGV)' \
.maintenance/runs-adoption-native/RUN_ID/work/baseline/output/project/build/tasks/_android-app_buildAndroidDebug/gradle-project-debug.apk \
.maintenance/runs-adoption-native/RUN_ID/work/candidate/output/project/build/tasks/_android-app_buildAndroidDebug/gradle-project-debug.apk
```

Replace `RUN_ID` with the fresh mobile producer ID. The probe requires passing upstream-mobile producer receipts, matching current source, recorded product hashes and version logs. It uses a private API 36 ARM emulator/AVD and foreground ADB server on a nondefault port, with owned keys, no metrics or snapshots, and bounded install/launch/UI/crash observation. It grants location permission and injects explicit synthetic coordinates in that emulator. It preserves the host ADB server and user devices. Recover and clean the resulting run through store `adoption-runtime`.

This is an install/launch smoke, not full feature, instrumentation, permission-flow, physical-device or signed-release validation. The assessment records the tested implementation hashes; a later guarded controller revision is not credited with execution of an earlier probe.

## Candidate compiler-plugin attribution

After a passing `build-inputs` pair and completed bundled attribution, reuse its retained compiler producers in the same store:

```sh
./scripts/dev/dependency_updates.sh rehearse-plugin-attribution BUILD_RUN_ID --store upstream-remediation
./scripts/dev/dependency_updates.sh plugin-report PLUGIN_RUN_ID --store upstream-remediation
./scripts/dev/dependency_updates.sh review-advisories PLUGIN_RUN_ID --store upstream-remediation
./scripts/dev/dependency_updates.sh recover PLUGIN_RUN_ID --stop --store upstream-remediation
./scripts/dev/dependency_updates.sh cleanup PLUGIN_RUN_ID --apply --discard --store upstream-remediation
./scripts/dev/dependency_updates.sh plugin-report PLUGIN_RUN_ID --store upstream-remediation
```

The existing resolver now accepts the retained upstream producer profile. It selects each phase's reviewed mapping from the measured wrapper declaration, requires the separately pinned 0.13.0 mapping/classpath sources, and joins fresh resolver SHA-256/byte identities to every retained compiler invocation. It incorporates the verified bundled-attribution query set rather than returning to the narrower named-only lookup. Unknown versions, changed source fingerprints, different resolver pins or missing producers refuse. Historical 0.12.2 receipts retain their original packet shape and remain replayable.

Advisory command exit 2 with `triage_required` means collection found risks requiring review; it is distinct from a transport failure. Independent resolution and exact joins close only the measured plugin-file attribution scope, leaving shaded code, Native bundle internals and unmeasured native test/compiler paths explicit.

## Review before adoption

Consult the [measured adoption assessment](toolchain-adoption-assessment.md). Keep release age, exact advisory findings and ownership/reachability triage, compiler-plugin attribution scope, clean-clone/hosted provisioning, minimum-runtime limits and signed delivery evidence explicit. A higher compile SDK is a reviewable build input; raising minimum/target SDK or dropping an architecture affects support policy and requires a separate informed decision.

A reversible rehearsal patch preview is not a complete adoption packet. Integration must update reviewed wrapper/compatibility baselines, integrate the reviewed candidate compiler-plugin mapping, document SDK provisioning and verify the resulting clean integration. Present the concrete implications and rollback before requesting adoption. The [direct-path retirement gates](bridge-retirement-path.md) remain independent, including actual bridge absence, native tests/adapters/plugins, onboarding and release parity.
