# Kotlin Toolchain rehearsal

Slice 6 adds an independent Kotlin adapter to the [common executor](executor-guide.md).
The reviewed baseline is now Toolchain 0.12.2 with `apple-silicon` targets.
Historical 0.11.1 → 0.12.2 receipts remain in the
[measured validation](sixth-slice-validation.md) and
[target assessment](apple-silicon-assessment.md). The manifest keeps both versions
for provenance but has no pending candidate after adoption.

## Prepare and run

Install the existing pinned quality tools first, following the [README](../../README.md).
Preparation explicitly downloads the four reviewed consumer wrappers:

```bash
./scripts/dev/dependency_updates.sh prepare-kotlin
# After reviewing and allowlisting a future version, replace VERSION with it:
./scripts/dev/dependency_updates.sh rehearse-kotlin VERSION inputs
./scripts/dev/dependency_updates.sh rehearse-kotlin VERSION mobile
```

A future version needs verified wrapper/distribution pins, release evidence,
age eligibility and versioned output-parser coverage. The adopted baseline is
not a pending update candidate. OS-only comparisons use `rehearse-support` from
the [mobile support guide](mobile-support-policy.md).

The default target policy comes from `maintenance-kotlin-toolchains.json` and is
now `apple-silicon`. The historical migration recipe can remove `iosX64` from the
five shared module lists and the bridge target/source mapping in an isolated
candidate. Already migrated declarations are verified without additional edits.
Changed declaration shapes/new libraries require review. Candidate graphs must
retain ARM main/test coverage and have no Intel iOS roots; native execution
requires ARM64 macOS. Xcode app/test targets, Swift adapters and plugins remain.
An explicit `current` override is a diagnostic comparison of captured declarations;
it is not authorization to change support policy or bypass native evidence.

Preparation verifies URLs, SHA-256 values and embedded distribution checksums in
`maintenance-kotlin-toolchains.json`. Its owned cache is under
`.maintenance/kotlin-wrappers`. Rehearsal verifies those bytes again and rejects
unreviewed candidates, wrapper drift and releases younger than the existing
seven-day policy. The repository uses LF for the Windows wrapper; downloaded
upstream CRLF bytes are verified before normalizing the candidate copy to LF.
A missing or damaged preparation is a refusal, never an implicit repair.

The input profile bootstraps each pinned Toolchain into private caches and runs
`--version`, `show settings --all-modules` and
`show dependencies --all-modules --include-tests`. It needs network access for
cold dependency resolution. It does not establish native compatibility.

The mobile profile currently requires macOS, JDK 21 discoverable through
`java_home`, the selected Xcode installation, an available iOS simulator runtime
and an Android SDK with accepted licenses. SDK selection uses `ANDROID_SDK_ROOT`,
then `ANDROID_HOME`, then the normal macOS SDK location. Each phase receives a
private writable SDK copy, using APFS cloning where available. Downloads may add
SDK packages to that copy. The caller's SDK/cache directories are not build output.

After input capture, mobile runs the existing jobs in order:

1. `android-test`: Android app and declared shared host tests.
2. `android-build-debug`: debug application packaging.
3. `ios-test`: Xcode's `PullRequest` test plan, using the Gradle bridge.
4. `ios-build-debug`: Xcode debug application build.

`MOBI_VALIDATION=1`, `KOTLIN_IOS_BUILDER=gradle`, `IOS_TEST_PLAN=PullRequest`,
`SKIP_MACRO_VALIDATION=YES` and `SWIFT_ENABLE_EXPLICIT_MODULES=NO` are explicit
rehearsal settings. The adapter creates a uniquely owned simulator and passes its
destination to the existing jobs. Signed release/archive/upload jobs are outside
this plan. A complete baseline must pass before the candidate is allocated.
There are no automatic retries, dependency repairs or adoption steps.

Keep source, index and tool files unchanged while the command runs. The executor
captures the working tree, including nonignored untracked files, and refuses
changed inputs. Each phase has a strict source snapshot plus a separate generated
build copy. Existing authored files are hash/mode checked around every command;
new Kotlin/Swift source in declared source/test roots is refused. Generated
outputs are confined to the owned copy, but this is not a hostile-code sandbox.
Each mobile phase has a 20-minute limit within the common 45-minute outer limit.

## Inspect the evidence

The command prints a sanitized result with `run_id`, source/HEAD/index, patch,
implementation/runtime/policy identities, named status and missing capabilities.
Every result sets `adoption_authorized: false`. `checks_passed` means only that the
requested plan passed; it does not mean the candidate is ready to adopt.

Private records live at `.maintenance/runs/RUN_ID/steps/PHASE-toolchain-PROFILE/`
(or `.maintenance/runs-NAME/` with a trailing `--store NAME`):

| Record | Evidence |
| --- | --- |
| `check.json` | Typed outcome and hash of the adapter evidence |
| `evidence.json` | Commands, exits, elapsed time, log/artifact hashes and coverage |
| `version.log`, `settings.log`, `dependencies.log` | Raw versioned CLI output |
| `effective-settings.json` | Settings for every declared module, including compiler-plugin declarations |
| `resolved-graphs.json` | Printed main/test compile/runtime roots, edges, requests and selected versions |
| `downloaded-artifacts.json` | SHA-256 and size of recognized artifacts in private caches/HOME |
| `sdk-inputs.json` | Android SDK package metadata identities after copying |
| Native job logs and `debug-products.json` | Attempted test/build diagnostics and successful debug product hashes |
| `observed-jvms.json`, `native-resources.json` | Private process/device ownership evidence |

The parser is deliberately limited to the two reviewed CLI versions. Missing
modules, missing main/test scopes, unresolved nodes and unfamiliar syntax fail
closed. Repeated graph branches remain references to earlier printed branches;
there is no invented expansion. These are Toolchain Maven graphs, not a complete
Gradle bridge target graph or proof that every downloaded compiler/Native artifact
was executed. Raw logs and control records contain local absolute paths and must
be reviewed and sanitized before sharing. Retained hashes alone cannot replace
missing diagnostic content when assessing a failure.

## Failure, recovery and cleanup

Use the [common outcome table](executor-guide.md#outcomes-and-evidence).
An attributable candidate compiler/test/target-resolution failure after the same baseline plan
passes is `incompatible`. Missing capabilities remain in the ledger. A failed
baseline, network/bootstrap failure, timeout or ambiguous diagnostic is
`inconclusive`; missing prerequisites are `incomplete`. Input mutation is
`refused`. Unconfirmed resource cleanup is an `executor_failure` and cannot be
reported as a successful check.

```bash
./scripts/dev/dependency_updates.sh recover RUN_ID
./scripts/dev/dependency_updates.sh recover RUN_ID --stop
./scripts/dev/dependency_updates.sh cleanup RUN_ID
./scripts/dev/dependency_updates.sh cleanup RUN_ID --apply --discard
```

Inspect the exact returned run before explicit discard. Cleanup removes only
owned disposable workspaces; result JSON, journals and check logs remain. Review
holds, active leases and uncertain ownership prevent deletion. Recovery preserves
the original outcome and starts no new candidate work. A new rehearsal gets a
new ID and runs the baseline again.

Native cleanup verifies host, phase marker, process uid/start/group and either a
random JVM tag or the exact private Gradle daemon classpath and artifact hash.
Toolchain's Tooling API replaces the configured JVM options, so the latter proof
is required for its real daemon. Unknown registry processes remain untouched.
Simulator intent is saved before creation; cleanup verifies its unique name,
runtime and recorded identifier. Test clones require the exact `Clone N of`
name containing the owned base nonce and the same runtime; they are recorded and
removed before the base. Unfamiliar names carrying that nonce refuse cleanup.
Unconfirmed creation blocks workspace deletion.
Existing user devices and global CoreSimulator services are not cleanup targets.
The supervisor also attempts owned cleanup after coordinator loss.

## Assessment boundaries and upstream sources

The manifest records the official [0.12.2 release](https://github.com/JetBrains/kotlin-toolchain/releases/tag/v0.12.2),
published on 2026-09-15, with the reviewed response hash. The versioned
[CLI documentation](https://github.com/JetBrains/kotlin-toolchain/blob/v0.12.2/docs/src/cli/index.md),
[settings command](https://github.com/JetBrains/kotlin-toolchain/blob/v0.12.2/sources/amper-cli/src/org/jetbrains/amper/cli/commands/show/ShowSettingsCommand.kt),
[dependency command](https://github.com/JetBrains/kotlin-toolchain/blob/v0.12.2/sources/amper-cli/src/org/jetbrains/amper/cli/commands/show/ShowDependenciesCommand.kt)
and [defaults](https://github.com/JetBrains/kotlin-toolchain/blob/v0.12.2/sources/frontend-api/src/org/jetbrains/amper/frontend/schema/DefaultVersions.kt)
explain the captured input surfaces. Release facts and compiler defaults are not
native execution evidence.

The next review combines this result with authenticated, current provider/advisory
evidence and a complete target/packaging assessment. Bridge-stack upgrades remain
separate from direct Toolchain parity with the bridge physically unavailable.
Neither framework compilation nor a Swift export announcement closes the
[retirement matrix](kotlin-compatibility.md). Mobi's adopted policy intentionally
excludes Intel iOS. Linux and cold hosted execution remain evidence gaps, along
with device/release packaging. The common fixture commands remain
independent of Kotlin, Xcode, Elixir and Codex; the production
[Elixir profile](elixir-profile.md) is still dormant.
