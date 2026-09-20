# Local Development

One of the goals of this CI design is that the same job contract works locally.

## Prerequisites

- JDK 21+
- Ruby (the repository's `.ruby-version` is the validated runtime) and Bundler
- Android SDK for Android jobs
- Xcode with an installed iOS Simulator runtime for iOS jobs
- `ktlint`, `detekt`, `SwiftFormat`, `SwiftLint`, and `ShellCheck` for the
  quality commands

Set a writable Kotlin Toolchain cache before running build commands:

```bash
export KOTLIN_CLI_BOOTSTRAP_CACHE_DIR="$PWD/.kotlin-cache"
```

## IDE flow without Gradle sync

Because this repository uses Kotlin Toolchain instead of Gradle as the project
model, Android Studio will not generate the normal Android run configurations
for the app module. The supported low-friction workflow is:

- use the checked-in shell run configurations under `.run/`
- use repo-owned scripts under `scripts/dev/`
- treat Xcode as the primary runner/debugger for iOS

If your JetBrains IDE does not show the shared `.run` configurations, make sure
the Shell Script plugin is enabled.

Recommended daily entry points:

```bash
just doctor
just format
just lint
just check
just android-emulators
just android-start <avd-name>
just android-run
just android-run-debug
just android-test
just android-build-debug
just ios-open
just ios-build-debug
just ios-test
```

`just android-run` builds the debug APK with the same repo-owned flow used by
CI, installs it with `adb`, and launches `studio.mekate.mobi.MainActivity`. If
multiple Android devices are connected, set `ANDROID_SERIAL` first.

`just android-run-debug` does the same install flow, but launches the app with
`am start -D`, so the process waits for a debugger. After that, use `Run >
Attach debugger to Android process` in Android Studio or IntelliJ IDEA and
select `studio.mekate.mobi`.

`just android-test` runs the shared feature tests and the Android app tests,
stores JUnit XML under `build/reports/shared-feature-home/android` and
`build/reports/android-app/android`, and prints a compact summary for both.
This is the recommended local and IDE-friendly Android test entry point.

`just android-emulators` lists the locally available Android Virtual Devices.

`just android-start <avd-name>` starts a named emulator in the background and
writes its output to `build/logs/android-emulator-<avd-name>.log`.

`just ios-open` opens [`ios-app/module.xcodeproj`](../../ios-app/module.xcodeproj)
in Xcode, where you can use the standard iOS run/debug loop against a simulator
or device.

By default, the iOS project builds Kotlin through the temporary Gradle bridge.
To override the cache location explicitly, set:

```bash
export KOTLIN_IOS_BUILDER=gradle
export GRADLE_USER_HOME="$PWD/.gradle-user-home"
```

Then run the same local entry points, for example:

```bash
./scripts/ci/run_job.sh ios-build-debug
bundle exec fastlane ios buildRelease
```

That keeps the local flow aligned with the CI and TestFlight path while the
bridge is in use.

`KOTLIN_IOS_BUILDER=kotlin` is kept as an experimental direct integration path,
but it is not the default while Kotlin Toolchain 0.11.1 still requires an
iOS app Xcode project with a single target and the app still needs SKIE on the
Gradle bridge for sealed-state ergonomics.

`just doctor` checks the expected local toolchain and shows whether an Android
device or emulator is already available for `just android-run`.

`just format` applies Kotlin and Swift formatting through repo-owned scripts.

`just lint` runs Kotlin formatting checks, Kotlin static analysis, Swift
formatting checks, Swift linting, and `ShellCheck` for the repo-owned shell
scripts and Git hook. It includes nonignored new source files and Swift package
code. `just format` uses the same source inventory and only runs the two formatters.

`just check` runs static analysis with an additional commit guard: all tracked
checkout contents and executable/symlink modes must equal the index before and
after analysis. Stage complete intended changes first. Nonignored untracked
files also block this mode. Use `just lint` during unstaged development.

`./scripts/ci/run_job.sh quality-check` and `./scripts/dev/check.sh --static`
use the same static inputs without local commit orchestration or build bootstrap.
The gate does not install tools, format files, stage, stash, restore, or run
dependency discovery. Native tests and builds remain separate commands.

### Static gate inputs and recovery

[`quality.rb`](../../scripts/dev/quality.rb) uses Ruby's standard library and
NUL-delimited Git filenames. It reads the explicit module list in `project.yaml`
without invoking Kotlin Toolchain. Current supported inputs are:

- Kotlin `.kt` files under declared modules' `src`, `test`, `src@platform` and
  `test@platform` roots, and repository `.kts` files. All receive ktlint; `.kt`
  sources also receive detekt. Modules are discovered, not named in the script.
- All repository Swift source, including `Package.swift` and package sources.
- `scripts/**/*.sh` and files in `.githooks/`.

Tracked source is accounted for even when matched by Git ignores. Untracked
ignored files are excluded. Untracked outputs under `build/`, each declared
module's `build/`, the bridge's build/cache directories, root Kotlin/Gradle/Amper
caches and `ios-app/Dependencies/.build/` are also excluded from manual analysis.
These paths are generated build or downloaded package output, not authored
source. **Nonignored** output still blocks commit mode: add a reviewed ignore
entry for an intended generated directory. There is no blanket `vendor/`
exclusion for authored source. A tracked `.kt` outside supported roots fails
explicitly instead of disappearing.

Templates, custom source roots, overlapping/glob module declarations, duplicate
YAML keys, multiple YAML documents, source symlinks and directory symlinks are
unsupported and fail with the offending input.
Module paths use letters, digits, `_`, `-` and directory separators. Kotlin and
Swift paths with glob metacharacters, backslashes or commas fail explicitly
because analyzer argument parsers differ. Spaces, tabs, newlines and leading
dashes remain exact arguments; normal filename/style rules still apply.

Commit mode rejects partial staging, unstaged deletion/rename/mode changes,
intent-to-add, unmerged entries, skip-worktree/assume-unchanged flags, sparse
entries, submodules and symlinks resolving outside the repository. It reads
actual file bytes, so restored size/mtime cannot bypass the check. Checkout
transforms such as CRLF conversion or clean filters that produce different
index bytes are not supported. Resolve the reported state and stage only the
intended complete files; the gate never repairs Git state for you. After a
concurrent edit, rerun the check. Use a full checkout for sparse-index failures.

Every run reports versions, input counts, a JSON manifest with source SHA-256
hashes, and per-tool/total elapsed seconds. Commit mode also reports an index
identity digest. To inspect the inventory without running analyzers:

```bash
./scripts/dev/lint.sh --manifest
# Pure JSON, without shell environment setup messages:
ruby scripts/dev/quality.rb static --manifest
```

The five existing analyzer versions are reported, not enforced. Missing tools
fail before analysis; install them explicitly with
`./scripts/ci/install_quality_tools.sh` on macOS. Ruby and Git must be executable
for the current architecture. If an old Intel-only Git shadows the system Git
on Apple Silicon, select a compatible PATH for the command, for example:

```bash
PATH=/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin ./scripts/dev/lint.sh
```

This command changes only its own environment. The gate does not repair shell
configuration. Tool/runtime pin enforcement is the next maintenance slice.
Before/after checks detect persistent drift; they do not provide an atomic
snapshot or detect edits that are changed and restored entirely during a run.
Static mode has no commit-content guarantee. Installed tools, inherited
environment and analyzer configuration remain trusted inputs.

Run the gate's contract suite with Ruby, Git and Bash, then optionally exercise
installed analyzers. Both commands use disposable repositories and clean them
up automatically. They do not install dependencies or change the caller's index.

```bash
ruby scripts/dev/test_quality.rb
ruby scripts/dev/test_quality_real.rb
```

## IntelliJ commit checks

IntelliJ IDEA's `Analyze code` commit check runs the IDE inspection profile,
not the repo-owned quality tools. To keep the commit workflow aligned with the
project's established analysis path, use the versioned Git hook in
[`/.githooks/pre-commit`](../../.githooks/pre-commit) instead.

Activate the repo hooks once per clone:

```bash
git config core.hooksPath .githooks
```

Then in IntelliJ IDEA:

- disable the `Analyze code` commit check
- enable `Run Git hooks`

That makes IDE commits run the repo-owned commit guard and static checks.
The guard requires all intended working-tree content to be staged in full.

## Shared job dispatcher

The fastest way to exercise the same paths CI uses is through
[`scripts/ci/run_job.sh`](../../scripts/ci/run_job.sh):

```bash
./scripts/ci/run_job.sh android-build-debug
./scripts/ci/run_job.sh android-test
./scripts/ci/run_job.sh android-build-release
./scripts/ci/run_job.sh quality-check
./scripts/ci/run_job.sh ios-build-debug
./scripts/ci/run_job.sh ios-test
./scripts/ci/run_job.sh ios-build-release
```

This is the best path for reproducing CI behavior without pushing commits.
Use `just android-test` instead when you want cleaner local test output in the
terminal or through the shared `.run/Android Test` configuration in IntelliJ
IDEA / Android Studio.

When the Android debug smoke jobs run without release signing material, the repo
creates ignored local debug signing files under `android-app/` so a clean clone
can still build. Android release jobs remain explicitly signing-driven.

The iOS build jobs target a generic iOS Simulator destination, prefer the
shared Xcode workspace when Swift packages are present, and set
`SWIFT_ENABLE_EXPLICIT_MODULES=NO` for the CLI path. That keeps the CLI build
aligned with the TCA-based iOS setup without depending on a precreated
simulator device.

## Just recipes

The repo also exposes common jobs through [`justfile`](../../justfile):

```bash
just android-build-debug
just android-test
just check
just ios-build-debug
just ios-test
just ios-build-release
```

## Fastlane directly

If you want to work one layer lower, you can run Fastlane commands directly.

Install gems:

```bash
bundle install
```

Run Android lanes:

```bash
bundle exec fastlane android buildDebug
bundle exec fastlane android test
bundle exec fastlane android buildRelease
```

Run iOS lanes:

```bash
bundle exec fastlane ios buildRelease
bundle exec fastlane ios uploadTestFlight
```

## Local Android release flow

Set version values:

```bash
export VERSION_CODE=1
export VERSION_NAME="1.0-local"
./scripts/ci/apply_android_version.sh
```

If you want signing:

```bash
export ANDROID_KEYSTORE_FILE="$PWD/secrets/upload-keystore.jks"
export ANDROID_KEYSTORE_PASSWORD="your-keystore-password"
export ANDROID_KEY_ALIAS="upload"
export ANDROID_KEY_PASSWORD="your-key-password"
./scripts/ci/write_android_signing_files.sh
```

Then build:

```bash
bundle exec fastlane android buildRelease
```

## Local iOS release flow

The machine must already have the correct Apple signing assets installed.

Set:

- `IOS_BUNDLE_IDENTIFIER`
- `IOS_DEVELOPMENT_TEAM`
- `IOS_PROVISIONING_PROFILE_SPECIFIER`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_FILE` or `APP_STORE_CONNECT_API_KEY_BASE64`

Then run:

```bash
bundle exec fastlane ios buildRelease
bundle exec fastlane ios uploadTestFlight
```

## What local success tells you

If local runs succeed through `run_job.sh`, then the remaining CI work is
usually one of these:

- runner provisioning
- missing secrets
- environment scoping
- artifact handoff between jobs

That is exactly why the shared job dispatcher is worth keeping.
