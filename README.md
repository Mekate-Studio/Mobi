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

Install Ruby dependencies:

```bash
bundle install
```

Set a writable Amper cache:

```bash
export AMPER_BOOTSTRAP_CACHE_DIR="$PWD/.amper-cache"
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
- [Secrets Reference](docs/reference/secrets.md)
- [iOS Gradle Bridge Migration](docs/reference/ios-gradle-bridge.md)

The Gradle bridge material is intentionally documented as a transitional
constraint in the current repository shape, not as the long-term ideal.

## Repository Shape

- [`project.yaml`](project.yaml): Amper workspace entry point
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
- Amper remains the multiplatform build entry point

That keeps the runtime and release mechanics close to the architecture instead
of hiding them inside CI configuration alone.

## Linting and Static Analysis

The repository keeps quality checks behind repo-owned scripts instead of
pushing tool orchestration into CI or the Gradle bridge.

- `just format` applies Kotlin and Swift formatting
- `just lint` verifies Kotlin, Swift, and shell quality checks
- `just check` runs the current quality gate
- `just deps` runs the local dependency update lookup

The current tool split is:

- `ktlint` for Kotlin formatting checks and autofix
- `detekt` for Kotlin static analysis
- `SwiftFormat` for Swift formatting checks and autofix
- `SwiftLint` for Swift linting
- `ShellCheck` for repo-owned shell scripts

## Dependency Maintenance

Renovate is the repository's dependency update orchestrator. The checked-in
[`renovate.json`](renovate.json) covers GitHub Actions, Bundler, the Gradle
version catalog used by the iOS bridge, and custom Amper `module.yaml` Maven
coordinates that generic Gradle tooling does not see. Native iOS dependencies
such as TCA, Point-Free Dependencies, and MapLibre are declared in
[`ios-app/Dependencies/Package.swift`](ios-app/Dependencies/Package.swift), so
Renovate can manage them through its native Swift Package Manager support.
Enable the Renovate GitHub App for hosted pull requests, or point a
self-hosted Renovate runner at this repository.
Metro and Kotlin coroutines updates are grouped across Amper modules and the
Gradle bridge catalog because the bridge must stay aligned with the shared
Kotlin dependency surface used by the app modules.
Metro is currently held below `1.2.0`, and the bridge Kotlin compiler below
`2.4.0`, because Metro `1.2.x` publishes Kotlin/Native artifacts with Kotlin
`2.4.0` ABI while the current SKIE release used by the bridge supports Kotlin
`2.3.x`.
The scheduled `Dependency Compatibility` workflow runs the repo-owned
`scripts/ci/check_skie_kotlin_compatibility.sh` probe to detect when the latest
SKIE release can compile the bridge on the Kotlin `2.4.x` line. Until Swift
export is stable enough for this repository's sealed-state bridge, SKIE remains
the common denominator for coordinated Metro and Kotlin updates.

Use the local lookup before or during dependency maintenance:

```bash
just deps
```

To run the SKIE compatibility probe locally:

```bash
./scripts/ci/check_skie_kotlin_compatibility.sh
```

The `just deps` command runs Renovate in local dry-run lookup mode. It reports
available updates from the current checkout, but branch and pull-request
creation still belong to the hosted Renovate flow. When the command falls back
to `npx`, it expects Node.js 24 or newer because current Renovate releases
require that runtime. If `osv-scanner` is installed, the same command also runs
a local vulnerability scan; set `SKIP_OSV_SCAN=1` to skip that optional step.

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
