# Stop Putting Your Kotlin Multiplatform CI Logic in YAML

I did not set out to build a "portable CI architecture" for Kotlin
Multiplatform.

I was just trying to get a mobile pipeline under control.

The usual pattern started showing up almost immediately: more logic in GitHub
Actions, more conditionals, more environment-specific behavior, more secrets
handling, more release steps, and more moments where the answer to "what does
this job actually do?" was "open the CI UI and start digging."

That works for a while, until it doesn't.

At some point, the YAML stops being orchestration and starts becoming the
application. Local reproduction gets harder. Migrating between CI providers gets
expensive. Debugging turns into archaeology.

So I took a different route: move the job contract into the repository, and let
CI providers stay thin.

That decision ended up producing a Kotlin Multiplatform mobile CI setup that is
much easier to run locally, much easier to explain, and much easier to share
with other teams.

## The real problem with mobile CI

Kotlin Multiplatform mobile CI is not hard because any single step is unusual.
It is hard because too many concerns pile up in the same place:

- Android builds
- Android tests
- iOS builds
- archive and upload flows
- versioning
- signing
- store credentials
- runner-specific setup
- CI-provider-specific environment variables

When all of that gets pushed directly into YAML, the pipeline becomes tightly
coupled to the CI product that happens to be running it.

That tends to create a few predictable problems:

- the workflow becomes harder to read than the codebase it builds
- local debugging stops looking like CI debugging
- secrets handling gets duplicated in too many places
- switching from GitLab to GitHub, or vice versa, feels like a rewrite

The issue is not YAML itself. The issue is putting too much meaning into it.

## The shift that made this manageable

The setup in this repository is built around one idea:

CI should describe when a job runs, not what the job means.

Once I leaned into that, the architecture got much simpler:

1. GitHub Actions or GitLab decides when to run a job.
2. A shared repository script decides what that job means.
3. Helper scripts prepare the environment the same way everywhere.
4. Fastlane provides the build and release command layer.
5. Amper remains the actual build system.

In this repository, the layers look like this:

- [`.github/workflows/mobile-ci.yml`](../.github/workflows/mobile-ci.yml)
- [`.gitlab-ci.yml`](../.gitlab-ci.yml)
- [`scripts/ci/run_job.sh`](../scripts/ci/run_job.sh)
- [`scripts/ci/lib/`](../scripts/ci/lib)
- [`fastlane/Fastfile`](../fastlane/Fastfile)
- [`project.yaml`](../project.yaml)

This is the important part: the pipeline now has a stable contract that lives
inside the repo.

That contract is a set of portable job names:

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

Those names are more valuable than they look.

They give the team a shared vocabulary. They let local development and CI talk
about the same operations. They make it obvious what belongs in the repo and
what belongs in the CI adapter.

## If I were publishing this as a public example, I would start with Amper

One improvement I would absolutely make when sharing this with other teams is to
use a separate minimal repository as the public reproduction target.

And importantly, that repo does not need to be hand-assembled from scratch.

The current Amper CLI can scaffold a strong starting point for this setup:

```bash
mkdir my-kmp-ci-app
cd my-kmp-ci-app
amper init compose-multiplatform
```

I verified locally on March 27, 2026 that `amper init compose-multiplatform`
works non-interactively and generates a fresh project.

That matters for the story.

It means the article can start with a command readers can run, not just a repo
they are supposed to copy. It also means the public sample can stay focused on
the CI pattern itself instead of also having to justify a bunch of unrelated app
boilerplate.

The generated project includes:

- `android-app/`
- `ios-app/`
- `shared/`
- `project.yaml`
- checked-in `amper` wrappers

It also includes a `jvm-app/` module. For a strict mobile-only sample, I would
either remove that module after generation or just leave it in place and ignore
it in CI until there is a reason to use it.

## What "thin CI" actually looks like

Once the real job logic moves into the repo, the GitHub Actions workflow gets
surprisingly boring.

That is a good thing.

A typical job becomes little more than:

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

At that point, the YAML is doing exactly what I want it to do:

- pick a runner
- install prerequisites
- define dependencies
- scope environments
- move artifacts around

And just as importantly, it is not doing a bunch of things I do not want it to
do:

- encode build logic
- normalize CI variables
- rewrite secrets into local files
- invent a second command system

The same idea applies to GitLab. The adapters can differ, but the contract stays
the same.

## The dispatcher is where the pipeline becomes understandable

The shared entrypoint is [`scripts/ci/run_job.sh`](../scripts/ci/run_job.sh).

It answers the question every pipeline eventually needs to answer clearly:

"What does this job actually do?"

Here is the shape of it:

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

That is dramatically easier to reason about than chasing behavior across a CI
file full of conditionals, environment mappings, and inline shell.

It also means a developer can run the exact same job locally without having to
fake an entire CI environment.

## The helper scripts do the quiet work that usually clutters pipelines

Most of the portability comes from the helper layer under
[`scripts/ci/lib/`](../scripts/ci/lib).

That layer is responsible for:

- normalizing GitHub and GitLab variables into shared ones
- preparing a writable Amper cache
- setting up Java and PATH consistently
- detecting the Android SDK
- running Bundler the same way everywhere
- materializing signing files and API keys only when needed

That gives the rest of the pipeline stable concepts such as:

- `BUILD_NUMBER`
- `BUILD_SHA`
- `BUILD_BRANCH`
- `DEFAULT_BRANCH`
- `VERSION_CODE`
- `VERSION_NAME`
- `IOS_BUILD_NUMBER`

This matters more than it might seem. Once those values are normalized, the
actual job logic stops caring whether it is running in GitHub Actions, GitLab,
or a local shell session.

## Separating validation from release made the pipeline calmer

One of the best decisions in this setup was to keep normal CI validation
separate from release delivery.

For Android, that means separate jobs for:

- debug builds
- release builds
- tests
- Play internal publishing
- promotion across tracks

For iOS, it means separating:

- unsigned CI sanity builds
- signed archive generation
- TestFlight upload

That split is not just organizational neatness. It keeps normal pull request
feedback from depending on Apple signing or release credentials. It makes store
delivery something deliberate instead of something every commit has to survive.

In practice, that makes the whole pipeline feel less fragile.

## Secrets are materialized at runtime, not stored in the repo

The repository does not commit signing files or API keys.

Instead, release-oriented jobs materialize them at runtime through small helper
scripts:

- [`scripts/ci/write_android_signing_files.sh`](../scripts/ci/write_android_signing_files.sh)
- [`scripts/ci/write_google_play_key.sh`](../scripts/ci/write_google_play_key.sh)
- [`scripts/ci/write_app_store_connect_api_key.sh`](../scripts/ci/write_app_store_connect_api_key.sh)

That model has been much easier to explain and maintain.

There is still one unavoidable caveat on the iOS side: Apple certificates and
provisioning profiles have to exist on the macOS runner that performs the
archive. A repository can materialize API keys, but it cannot magically replace
proper host-level signing setup.

That is not a flaw in this design. It is just the reality of Apple delivery
workflows.

## Fastlane still makes sense here

Fastlane fits well into this arrangement because it sits at a natural boundary.

It is not trying to be the CI orchestrator. It is not trying to replace the
build system. It is simply the command layer between the repository scripts and
the platform-specific delivery steps.

That keeps the responsibilities clean:

- Amper builds the project
- Fastlane wraps build and delivery commands
- shell scripts prepare the environment
- CI platforms orchestrate execution

When those responsibilities are separated cleanly, every layer gets easier to
read.

## Local reproduction stopped being an afterthought

This is probably the most practical benefit of the whole approach.

Because the job contract lives in the repository, I can run the same jobs
locally that CI runs:

```bash
bundle install
export AMPER_BOOTSTRAP_CACHE_DIR="$PWD/.amper-cache"
./scripts/ci/run_job.sh android-build-debug
./scripts/ci/run_job.sh android-test
./scripts/ci/run_job.sh ios-build-debug
```

That changes debugging completely.

If a shared job works locally, then most remaining failures are usually not
"mysterious CI problems." They are much narrower:

- missing secrets
- runner provisioning gaps
- artifact handoff issues
- environment scoping mistakes

That is a much better place to debug from.

## If I were starting this again, I would still roll it out slowly

Even with a cleaner architecture, release workflows are still release
workflows. I would adopt this pattern in stages:

1. Get Android debug build working locally.
2. Get Android tests working locally.
3. Get iOS debug build working locally.
4. Move those jobs into CI.
5. Add Android release signing.
6. Publish manually to Play internal testing.
7. Add iOS archive signing on the macOS runner.
8. Upload manually to TestFlight.
9. Add promotion flows only after the basics are stable.

That order keeps the learning curve manageable and avoids conflating
"our pipeline design is wrong" with "store delivery is inherently complicated."

## The part worth sharing

The most useful thing here is not a specific Actions feature, a specific
Fastlane lane, or a specific Amper command.

It is the decision to stop treating the CI provider as the home of the build
logic.

Once the job contract moved into the repository, a lot of problems got smaller:

- the pipeline became easier to explain
- local reproduction became normal
- provider migration became less scary
- secrets handling became clearer
- documentation became much easier to write

That is the part I think is worth copying.

Not the exact YAML. Not the exact project structure. Not the exact runner label.

The idea.

Let CI orchestrate. Let the repository define the jobs.

That one shift made this Kotlin Multiplatform setup feel less like a collection
of fragile automation and more like an actual system we can understand, debug,
and share.

If you want the practical reproduction steps, start with the
[GitHub Actions Quickstart](quickstart-github-actions.md). If you want the
repo-specific implementation details, see
[`docs/reference/`](reference).
