# Toolchain 0.14.1 retained project-JDK cache — 2026-11-21

**The scoped upgrade and project-clean controls passed; 0.14.1 is not adopted.**
This follows merged [#128](https://github.com/Mekate-Studio/Mobi/pull/128), source
`568deb38a15d8ee0c434b95bbfd77f312a112baa`. The app stays on 0.13.0.
The [compact receipt](2026-11-21-toolchain-0141-jdk-cache.json) binds source,
implementation, actual commands, state transitions and cleanup. Raw state,
file manifests, logs and one-off inspection scripts remain ignored.

## Scenario and cost

The control uses an authentic 0.13.0 project provisioning record for Temurin
25.0.4.1, its retained JDK-list record and the matching JDK installation. Only
absolute JDK-home prefixes were relocated into an owned copy: the old
`codeVersion`, criteria, serialized result and recorded file states were
preserved. All **400 JDK files** retained identical bytes, sizes and timestamps.
The real baseline cache hit verifies the relocated record's usability; this is
not a fabricated provider response or fake Java executable.

The current app source was copied into that workspace. Only its candidate
wrapper pair changed to the reviewed 0.14.1 bytes. The existing version-specific
[qualification exception](2026-11-21-toolchain-0141-qualification.md) applies;
selection remains `experimental`, `age_blocked`, and `adoption_authorized: false`.
Normal eligibility remains November 26 at 17:46:59 UTC. No app, CI, cache-policy
or maintained guard implementation changes.

All commands used a private home, bootstrap/shared caches and project copy, with
both `JAVA_HOME` and `KOTLIN_CLI_JAVA_HOME` absent. Diagnostic VM properties and
process-only telemetry disablement do not alter normal app behavior. The probe
used the existing bounded command/process-group helper and source verification.
The original records and all 400 source JDK files were checked unchanged afterward.

## Actual commands and state transitions

Seven real commands exited 0: two `--version` probes, four default-JDK probes
using `tool jdk jcmd -- -J-XshowSettings:properties -h`, and one project `clean`.
The JDK probes used debug logging to distinguish cache hits from provisioning.

| Control | Observed result |
| --- | --- |
| 0.13.0 with the retained project state | Actual cache hit; selected JDK `25.0.4.1+1-LTS`; provisioning record unchanged |
| Switch wrappers, then 0.14.1 `--version` | CLI JRE `25.0.5.1+2-LTS`; old project record still unchanged |
| First 0.14.1 default-JDK request | Rebuilds provisioning state; selects Temurin `25.0.5.1+2-LTS`; record code version changes from `0.13.0` to `0.14.1` |
| Repeat that JDK request | Actual cache hit; same patched JDK and unchanged record |
| 0.14.1 project `clean` | Removes the project provisioning record; retained shared JDK remains |
| Request the JDK after clean | Recreates the record; same patched JDK path and runtime version |

The baseline CLI JRE separately reported `25.0.2+10-LTS`; its selected JDK
reported `25.0.4.1+1-LTS`. Both 0.14.1 owners reported `25.0.5.1+2-LTS`.
A CLI version/JRE check alone therefore does not establish the project's selected
compiler/tool JDK. These probes select the default JDK; they do not execute every
compiler or qualify all module-specific criteria.

The tagged [project context](https://github.com/JetBrains/kotlin-toolchain/blob/f53674bce744f0b5e9ff235110dcc1d565d2c114/sources/amper-cli/src/org/jetbrains/amper/cli/context/ProjectCliContext.kt)
uses the Toolchain code identifier for incremental state. The
[incremental cache](https://github.com/JetBrains/kotlin-toolchain/blob/f53674bce744f0b5e9ff235110dcc1d565d2c114/sources/libraries/incremental-cache/src/org/jetbrains/amper/incrementalcache/IncrementalCache.kt)
rejects a different stored code version. This explains the measured refresh
consistently with the source; it is not a guarantee about every retained-cache
scenario. The [JDK provider](https://github.com/JetBrains/kotlin-toolchain/blob/f53674bce744f0b5e9ff235110dcc1d565d2c114/sources/amper-jdk-provisioning/src/org/jetbrains/amper/jdk/provisioning/JdkProvider.kt)
otherwise retains successful provisioning without an expiry.

## Supported cleanup and update review

The [release guidance](https://github.com/JetBrains/kotlin-toolchain/releases/tag/v0.14.1)
recommends a project clean for previously provisioned JDKs. The supported
`./kotlin clean` was measured only inside the owned copy; the
[command source](https://github.com/JetBrains/kotlin-toolchain/blob/f53674bce744f0b5e9ff235110dcc1d565d2c114/sources/amper-cli/src/org/jetbrains/amper/cli/commands/CleanCommand.kt)
removes project build output and caches. No cleanup was applied to a developer
checkout or machine-wide cache, and no automatic cleanup step is added.

For owner updates, check both actual runtime versions and project record
code-version/hit/recalculation behavior, then qualify a chosen cleanup path.
Re-evaluate this procedure if upstream introduces a supported freshness policy.
Matching-major `JAVA_HOME` and explicit `KOTLIN_CLI_JAVA_HOME` still have their
separate selection/maintenance rules from the
[actual override controls](2026-11-21-toolchain-0141-qualification.md); neither a
wrapper update nor project clean proves those installations were replaced.

## Limits and evidence handling

This arm64 check relocates two JDK-related records, not an entire historical
project/Gradle/Native/SDK cache. Other origins, vendors, criteria and architectures,
the affected x64 advisory path and machine-wide `clean-shared-caches` remain
outside its measured scope. No security clearance or workaround retirement follows.

An initial immutable-copy guard rejected the two intentional build-state files
before any CLI command. That refusal is retained. The successful probe verified
every authored file and confined generated paths to its private `build/`
directory; no maintained guard was relaxed. All seven command logs/state
snapshots and original-cache preservation evidence were retained before the
marked owned workspace was removed after verifying no command was active.

The 0.14.1 unsigned Release/resource/relocated-delivery checks and the dependency
findings/transform gap remain, followed by a separate risk/adoption decision.
Device/signed delivery stays separate. Normal staged and hosted documentation-only
gate results are recorded in the final PR comment; native builds/tests were not
rerun by this runtime-only qualification.
