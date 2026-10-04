# Mobi

`Mobi` is a public reference architecture repository for Kotlin Multiplatform
mobile work.

It demonstrates how to structure a modular shared Kotlin codebase, how to keep
native Android and iOS shells explicit while still sharing meaningful feature
state, and how to document architecture decisions in a way that stays useful as
the code evolves.

This repository is not trying to be:

- a polished product app
- a minimal starter template
- a CI portability showcase first

Those concerns still matter here, but the primary value of `Mobi` is the
architecture itself and the documentation around it.

## What Mobi Demonstrates

- modular shared Kotlin layers for core, feature, dependency wiring, and shared
  UI
- native Android and iOS shells consuming the same shared feature state
- shared async feature state modeled explicitly instead of with ad hoc booleans
- repo-owned build and release orchestration that stays understandable from the
  codebase itself
- architecture documentation through ADRs and focused reference guides

## Clean-Clone Quickstart

The reviewed baseline is Kotlin Toolchain 0.13.0. iOS development requires an
Apple Silicon Mac; shared Kotlin and the bridge target `iosArm64` devices and
`iosSimulatorArm64` simulators. Intel iOS simulators are outside Mobi's support
policy. App minimums are iOS 26.0 and Android 16/API 36; Android compile SDK is API 37; target SDK
remains API 36. These floors follow a configurable policy of one stable major
behind the latest reviewed stable release. See the
[mobile support workflow](docs/maintenance/mobile-support-policy.md) and
[adoption evidence](docs/maintenance/support-policy-validation.md).

Install Android platform API 37 and build tools 37.0.0, and review/accept the
Android SDK license explicitly before running Android jobs. See the
[local SDK setup](docs/reference/local-development.md#android-sdk-provisioning).

Install Ruby dependencies:

```bash
bundle install
```

Install the pinned static-quality tools explicitly on macOS (Xcode command-line
tools are required; the first run downloads artifacts and builds a private Ruby):

```bash
./scripts/ci/install_quality_tools.sh
```

Set a writable Kotlin Toolchain cache:

```bash
export KOTLIN_CLI_BOOTSTRAP_CACHE_DIR="$PWD/.kotlin-cache"
```

Run the main local smoke path:

```bash
./scripts/ci/run_job.sh android-build-debug
./scripts/ci/run_job.sh android-test
./scripts/ci/run_job.sh ios-build-debug
./scripts/ci/run_job.sh ios-test
./scripts/ci/run_job.sh quality-check
```

That path is the fastest way to validate that a clean clone can exercise the
same repo-owned jobs used by CI.

For the Android smoke jobs, the repository generates ignored local debug
signing files under `android-app/` if no Android signing material has been
provided. Release-oriented Android jobs still expect explicit signing inputs.

## Start Here

If you are approaching this repo as a reader first, these are the most useful
entry points:

- [Mobile Architecture](docs/reference/mobile-architecture.md)
- [Platform Direction](docs/reference/platform-direction.md)
- [Architecture Decisions](docs/adr/README.md)
- [How To Add A Feature](docs/reference/how-to-add-a-feature.md)
- [Local Development](docs/reference/local-development.md)
- [CI Validation And Release Candidates](docs/reference/ci-validation.md)
- [Secrets Reference](docs/reference/secrets.md)
- [iOS Gradle Bridge Migration](docs/reference/ios-gradle-bridge.md)
- [Quality And Dependency Maintenance Audit](docs/maintenance/README.md)

The approved direct development default uses Kotlin Toolchain for iOS development, tests
and unsigned builds, with explicit typed Swift projections. Gradle/unknown
iOS builder overrides refuse; rollback restores complete content first.
Credentialed iOS archive/export/TestFlight lanes are held pending separate
signed-delivery evidence and authorization. The retained bridge files are
preserved for content rollback. See the [accepted decision](docs/adr/0008-explicit-ios-projections-and-direct-development-builds.md).

## Repository Shape

- [`project.yaml`](project.yaml): Kotlin Toolchain workspace entry point
- [`shared-core/`](shared-core): platform-agnostic shared domain logic
- [`shared-feature-home/`](shared-feature-home): shared feature contract and
  state
- [`shared-di/`](shared-di): shared dependency graph and composition helpers
- [`shared-ui-home/`](shared-ui-home): shared Compose UI for the home feature
- [`android-app/`](android-app): Android app shell
- [`ios-app/`](ios-app): iOS app shell
- [`docs/adr/`](docs/adr): architecture decision records
- [`scripts/ci/run_job.sh`](scripts/ci/run_job.sh): repo-owned job dispatcher
- [`fastlane/Fastfile`](fastlane/Fastfile): build and release lanes

## Architecture And Operations

Even though this repository is not primarily a CI showcase, the operational
layer is still part of the reference architecture.

The main pattern is:

- GitHub Actions stays thin
- repository scripts own the job contract
- Fastlane wraps build and release commands
- Kotlin Toolchain remains the multiplatform build entry point

That keeps the runtime and release mechanics close to the architecture instead
of hiding them inside CI configuration alone.

Pull requests use conservative changed-path classification to avoid standalone
native app builds for behavior-only changes. Scheduled validation runs the full
test and release-configuration build surface for an exact `main` SHA. See
[CI Validation And Release Candidates](docs/reference/ci-validation.md) for the
selection rules, Apple test plans, and the distinction between an unsigned
nightly validation candidate and a credentialed release artifact.

## Linting and Static Analysis

The repository keeps quality checks behind repo-owned scripts instead of
pushing tool orchestration into CI or the Gradle bridge.

- `just format` applies Kotlin and Swift formatting
- `just lint` checks Kotlin, Swift (including package source), and repository shell files, including new nonignored files
- `just check` runs those checks once, then selected native jobs in an owned source copy; stage the full intended content first
- `just deps` records a pinned dependency inventory and explicit coverage gaps

The pre-commit hook uses `just check`'s script. CI's `quality-check` job uses
explicit static mode without local staging requirements. See
[static gate inputs and recovery](docs/reference/local-development.md#static-gate-inputs-and-recovery)
and [staged validation and recovery](docs/maintenance/third-slice-validation.md).
Use `./scripts/dev/check.sh --plan` to inspect the staged job selection.
[`quality-tools.json`](quality-tools.json) locks the analyzers, their private
Ruby/Java runtimes, artifact checksums and rule profiles. Quality commands verify
the installation offline; they never install or select tools from PATH.

The current tool split is:

- `ktlint` for Kotlin formatting checks and autofix
- `detekt` for Kotlin static analysis
- `SwiftFormat` for Swift formatting checks and autofix
- `SwiftLint` for Swift linting
- `ShellCheck` for repo-owned shell scripts

## Dependency Maintenance

Renovate is the repository's dependency update orchestrator. The checked-in
[`renovate.json`](renovate.json) covers GitHub Actions, Bundler, the Gradle
version catalog used by the iOS bridge, and custom Kotlin Toolchain
`module.yaml` Maven coordinates that generic Gradle tooling does not see.
Native iOS dependencies
such as TCA, Point-Free Dependencies, and MapLibre are declared in
[`ios-app/Dependencies/Package.swift`](ios-app/Dependencies/Package.swift), so
Renovate can manage them through its native Swift Package Manager support.
Enable the Renovate GitHub App for hosted pull requests, or point a
self-hosted Renovate runner at this repository.
Metro and Kotlin coroutines updates are grouped across Kotlin Toolchain modules
and the Gradle bridge catalog because the bridge must stay aligned with the
shared Kotlin dependency surface used by the app modules.
The retained bridge uses Kotlin 2.4.20, Metro 1.4.5 and SKIE 0.10.15; bridge
Compose remains 1.9.0. Renovate ceilings are bounded at Metro <=1.4.5 and bridge
Kotlin <=2.4.20 after the [reviewed adoption](docs/maintenance/bridge-adoption-review.md).
Toolchain 0.13.0 supplies Kotlin 2.4.20 and Compose 1.12.1 independently. The
[compatibility assessment](docs/maintenance/kotlin-compatibility.md) keeps this
upgrade separate from proving an equivalent direct Kotlin Toolchain path.
The existing scheduled compatibility workflow uses the repository-owned
[isolated watch](docs/maintenance/compatibility-watch.md). It records evidence
without changing production dependencies or granting adoption permission.
Physical bridge deletion still requires its own review after default integration
and applicable native, interop, onboarding and release gates. Preserved bridge
pins remain rollback inputs; they are not the active iOS builder on the adopted source.

Install the pinned discovery tools once, then record a local inventory:

```bash
./scripts/maintenance/install_tools.sh
just deps > /tmp/mobi-inventory.json
```

For manual compatibility assessment and isolated bridge rehearsal:

```bash
./scripts/dev/dependency_updates.sh assess-compatibility
./scripts/dev/dependency_updates.sh prepare-kotlin
./scripts/dev/dependency_updates.sh rehearse-compatibility bridge-compile --store compatibility
```

The [compatibility runner guide](docs/maintenance/compatibility-runner.md) separates
compile/link, full mobile and direct-path evidence, with review and cleanup steps.
The existing scheduled caller remains unchanged pending its dedicated integration.

The `just deps` command uses verified Node/Renovate pins for isolated native
extraction. It records declarations, locked packages and missing resolved graphs;
it does not fetch update catalogs or claim a clean vulnerability scan. Missing
tools fail with explicit setup guidance. The [inventory guide](docs/maintenance/dependency-inventory.md)
covers source-bound release/advisory evidence, failure states and recovery.
The inventory also includes the configured minimum-OS assessment. Use
`./scripts/dev/dependency_updates.sh assess-support` for the lightweight check.
Architecture, API, support-window and Toolchain-default changes require an impact
review and explicit adoption decision; the workflow does not automatically update
source or retire the bridge. The [support guide](docs/maintenance/mobile-support-policy.md)
explains source freshness, candidate rehearsal and per-project configuration.
The [executor guide](docs/maintenance/executor-guide.md) demonstrates independent
Kotlin/Elixir rehearsal fixtures and safe cleanup before real native rehearsal.

## Current Example Surface

The current sample app exposes three visible flows on both platforms:

- `Native Home`: a native shell consuming shared feature state
- `Nearby Map`: a lightweight native coordinate map consuming shared map state
- `Shared UI`: a shared Compose screen consuming the same home feature state

The home feature includes an asynchronous repository seam so both native shells
and the shared UI can exercise the same loading, success, and failure states.
The nearby map feature keeps map product rules in shared Kotlin while Android
and iOS draw a functional rider-centered coordinate map without requiring an
external map SDK or API key.

## Contributing And Support

- Use GitHub Discussions for architecture questions and design conversations.
- Use GitHub Issues for bugs, docs gaps, and concrete improvement requests.
- See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidance.
- See [SECURITY.md](SECURITY.md) for security reporting expectations.

## Licensing

Code in this repository is licensed under the GNU Affero General Public License
v3.0. Documentation and brand/trademark handling are intentionally treated
separately. See the repository license files and notices for the current
details.
