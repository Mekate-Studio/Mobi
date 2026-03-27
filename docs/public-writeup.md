# A Portable CI Setup for Kotlin Multiplatform Mobile

Most Kotlin Multiplatform CI write-ups stop at "here is my GitHub Actions file."
That is useful for one repository, but it is hard to reuse, hard to test
locally, and hard to migrate when your team changes CI providers.

This project takes a different approach.

Instead of putting the real logic in GitHub Actions or GitLab CI YAML, it keeps
the pipeline contract inside the repository itself:

- CI providers stay thin
- repository scripts own the job logic
- Fastlane is the command layer
- Amper remains the build system

The result is a setup that is easier to explain, easier to debug, and much
easier to share with other teams.

## The problem

Mobile CI gets messy quickly because it has to coordinate several kinds of work
at once:

- Android builds and tests
- iOS builds and archive/upload flows
- versioning
- secrets materialization
- signing
- store delivery
- CI-provider-specific environment variables

When all of that logic lives directly in YAML, a few things usually happen:

- the workflow becomes hard to read
- local reproduction gets worse
- secrets handling gets duplicated
- moving from GitLab to GitHub, or the reverse, becomes expensive

That is the trap this setup is trying to avoid.

## The pattern

The core design is simple:

1. CI YAML decides when jobs run.
2. A shared dispatcher decides what each job means.
3. Helper scripts prepare the environment consistently.
4. Fastlane runs the build and release commands.
5. Amper builds the project.

In this repository, that maps to:

- [`.github/workflows/mobile-ci.yml`](../.github/workflows/mobile-ci.yml)
- [`.gitlab-ci.yml`](../.gitlab-ci.yml)
- [`scripts/ci/run_job.sh`](../scripts/ci/run_job.sh)
- [`scripts/ci/lib/`](../scripts/ci/lib)
- [`fastlane/Fastfile`](../fastlane/Fastfile)
- [`project.yaml`](../project.yaml)

That separation turns the CI pipeline into something more like an API:

- `android-build-debug`
- `android-build-release`
- `android-test`
- `ios-build-debug`
- `ios-build-release`
- `ios-archive-release`
- `ios-testflight`
- `publish-internal`
- `promote-alpha`
- `promote-beta`
- `promote-production`

Those names are the contract. GitHub Actions and GitLab both call the same job
names, and local development can call them too.

## A cleaner way to publish this as a reproducible example

One thing I would do if I were sharing this more broadly is keep a separate
minimal repository whose only job is to demonstrate the CI pattern.

Amper makes that easier because the current CLI can scaffold a suitable starting
point for you.

If you already have the Amper CLI available locally, you can start with:

```bash
mkdir my-kmp-ci-app
cd my-kmp-ci-app
amper init compose-multiplatform
```

I verified locally on March 27, 2026 that `amper init compose-multiplatform`
works non-interactively and produces a fresh project.

That is a strong public starting point because it gives readers a generated
baseline first, and then your article only has to explain what CI-specific files
to add and why.

The generated template is not quite the smallest possible mobile-only repo
because it also includes a `jvm-app/` module, but that is not a blocker:

- you can leave it in place and ignore it in CI
- or you can remove it later if you want the example repo to be strictly
  Android + iOS + shared

Either way, it is much easier for readers to trust a flow that starts with a
project-generation command than a flow that starts with "copy this whole sample
repo and hope your paths match."

I also recommend publishing a concrete companion sample repository alongside the
article. In this repository, that shape now exists under
[`examples/minimal-public-sample-repo/`](../examples/minimal-public-sample-repo/README.md)
as a mobile-only scaffold derived from the Amper template.

To keep that sample maintainable, this repository also includes
[`scripts/regenerate_minimal_public_sample_repo.sh`](../scripts/regenerate_minimal_public_sample_repo.sh).
It reruns `amper init compose-multiplatform`, trims the generated project back
to Android + iOS + shared, and reapplies the CI overlay. That means the public
sample can be refreshed from a command when Amper evolves instead of slowly
drifting away from the article.

The companion sample itself now also includes a self-contained
`./scripts/regenerate_from_amper.sh`, so if you publish that folder as its own
GitHub repository it can delete and rebuild the Amper-generated app layer
without depending on this parent repository.

## What the GitHub Actions layer looks like

The workflow is intentionally thin. A job installs a little toolchain setup and
then hands off to the shared dispatcher:

```yaml
- uses: actions/checkout@v4
- uses: actions/setup-java@v4
  with:
    distribution: temurin
    java-version: "17"
- uses: ruby/setup-ruby@v1
  with:
    bundler-cache: true
- uses: android-actions/setup-android@v3
- name: Build Android debug
  run: ./scripts/ci/run_job.sh android-build-debug
```

That is the main idea in one snippet.

The workflow remains responsible for:

- triggers
- runner selection
- job dependencies
- environments
- artifact upload and download

It is not responsible for build logic, version logic, or secrets translation.

## What the shared job layer looks like

The shared entrypoint is [`scripts/ci/run_job.sh`](../scripts/ci/run_job.sh).
It maps portable job names to the correct implementation path:

```bash
case "${job_name}" in
  android-build-debug)
    ci_prepare_android_job
    ./scripts/ci/run_fastlane_with_amper_logs.sh buildDebug
    ;;
  ios-testflight)
    ci_prepare_ios_testflight_job
    bundle exec fastlane ios uploadTestFlight
    ;;
esac
```

This solves a very practical problem: people no longer need to read CI YAML to
figure out what a job actually does.

They can inspect one script, run the same job locally, and reason about the
pipeline from there.

## Why the helper layer matters

The helper modules under [`scripts/ci/lib/`](../scripts/ci/lib) are doing the
quiet but important work:

- normalizing GitHub and GitLab environment variables into shared values
- preparing a writable Amper cache
- resolving `JAVA_HOME`
- detecting the Android SDK
- setting up PATH
- running Bundler consistently
- materializing signing files and API keys only when needed

That means the rest of the pipeline can work with stable variables like:

- `BUILD_NUMBER`
- `BUILD_SHA`
- `BUILD_BRANCH`
- `DEFAULT_BRANCH`
- `VERSION_CODE`
- `VERSION_NAME`
- `IOS_BUILD_NUMBER`

This is one of the biggest reasons the setup feels portable instead of
provider-bound.

## Android and iOS are intentionally split

Another important part of the design is that CI validation and release delivery
are not the same thing.

For Android, the setup separates:

- debug build
- release build
- tests
- Play internal publish
- track promotion

For iOS, it separates:

- unsigned CI sanity builds
- signed archive generation
- TestFlight upload

That matters because you do not want all normal pull request feedback to depend
on Apple signing or store credentials. Keeping those steps separate makes the
pipeline much calmer to operate.

## Secrets stay out of the repository

The repository never stores signing assets directly in source control.

Instead, the CI jobs materialize them only when they are needed:

- Android keystore files are created at runtime
- Google Play service account JSON is materialized at runtime
- App Store Connect API keys are materialized at runtime

That approach is implemented by:

- [`scripts/ci/write_android_signing_files.sh`](../scripts/ci/write_android_signing_files.sh)
- [`scripts/ci/write_google_play_key.sh`](../scripts/ci/write_google_play_key.sh)
- [`scripts/ci/write_app_store_connect_api_key.sh`](../scripts/ci/write_app_store_connect_api_key.sh)

There is still one important exception for iOS: certificates and provisioning
profiles must already exist on the macOS runner host that performs the archive.
The repository can materialize API keys, but it cannot fully provision Apple
signing on its own.

## Why Fastlane still fits well here

Fastlane is useful in this setup because it sits at a clean boundary:

- above raw CI scripting
- below the CI provider
- close to store delivery workflows

Android lanes call Amper and Play Store actions. iOS lanes call archive/export
and TestFlight upload actions. That makes Fastlane the command layer instead of
the place where CI orchestration gets mixed together.

It also makes the release flows easier to test locally.

## Local reproduction is a first-class feature

One of the nicest outcomes of this design is that CI jobs are not trapped inside
the CI system.

You can run the same shared jobs locally:

```bash
bundle install
export AMPER_BOOTSTRAP_CACHE_DIR="$PWD/.amper-cache"
./scripts/ci/run_job.sh android-build-debug
./scripts/ci/run_job.sh android-test
./scripts/ci/run_job.sh ios-build-debug
```

That changes the debugging experience quite a bit. If the shared job works
locally, most later failures are usually about runner provisioning, secrets, or
artifact handoff, not about hidden YAML behavior.

## What I would recommend to teams copying this setup

If you want to reproduce this pattern in another repository, copy the smallest
useful slice first:

- the CI workflow
- the shared dispatcher
- the helper scripts
- the Fastlane files

Then make only the project-specific edits:

- Android package name and SDK settings
- iOS scheme and bundle identifier
- environment names
- runner labels

Most teams will get better results by keeping the portable job contract stable
and changing project details around it, rather than redesigning the whole
pipeline from scratch.

## A good rollout order

If you are adopting this in a fresh repository, do it in this order:

1. Get Android debug build working locally.
2. Get Android tests working locally.
3. Get iOS debug build working locally.
4. Move those jobs into CI.
5. Add Android release signing.
6. Publish to Play internal testing manually.
7. Add iOS archive signing on the macOS runner.
8. Upload to TestFlight manually.
9. Only then add promotion flows.

That sequence keeps the feedback loop fast and avoids mixing core CI debugging
with store-release debugging.

## The main takeaway

The valuable part of this setup is not a specific GitHub Actions trick or a
specific Fastlane lane.

It is the architectural choice to keep CI orchestration thin and move the real
job contract into the repository.

That makes the pipeline:

- easier to understand
- easier to run locally
- easier to migrate
- easier to document
- easier to share

If you want the practical reproduction steps, start with the
[GitHub Actions Quickstart](quickstart-github-actions.md). If you want the
deeper implementation details, see the docs under
[`docs/reference/`](reference).
