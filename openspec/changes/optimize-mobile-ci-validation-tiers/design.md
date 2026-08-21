## Context

See `proposal.md` for motivation and
`specs/mobile-ci-validation/spec.md` for the behavior contract. Mobi currently
uses one workflow for pull requests, pushes, and manual releases. Android and
iOS test jobs run after separate debug-build jobs on fresh runners, while the
repo-owned dispatcher already provides stable local job names. The iOS scheme
autocreates its test plan, and the Android test lane covers only two of the five
modules that currently contain host tests.

The repository is a public architecture reference. Workflow YAML should stay
thin, operational behavior should remain reproducible through repo-owned
scripts, and release credentials must never be available to pull-request jobs.

## Goals / Non-Goals

**Goals:**

- Reduce ordinary pull-request setup and native-build work without weakening
  behavior-test coverage.
- Make change-impact decisions visible, deterministic, tested, and
  conservative.
- Follow Apple's recommendation to use different test plans for affected-target
  review feedback and broader scheduled validation.
- Give nightly artifacts an explicit source identity and preserve the existing
  build/promotion boundary.

**Non-Goals:**

- Add a large emulator/device matrix before stable UI tests exist.
- Claim that app-hosted Xcode tests can execute without compiling their test
  host and dependencies.
- Automatically publish scheduled builds to production stores.
- Introduce a third-party path-filter action or move operational logic into
  large workflow expressions.

## Decisions

### Keep one always-triggered pull-request workflow and classify at job level

A repo-owned `classify_changes.sh` script will compare the event base and head
SHAs, emit job-selection outputs, and default unknown paths to full validation.
The workflow itself will not use top-level path filters because required
workflows skipped by path filtering can remain pending. One final `pr_gate` job
will inspect all selected job results and become the stable branch-protection
surface.

An external path-filter action was considered but rejected so classification
can be exercised locally, reviewed as normal shell code, and reused by other CI
providers.

### Treat UI as one subset of native-build-affecting change

Shared UI, native views/resources, project files, module manifests,
dependencies, CI scripts, and release tooling select builds. Shared feature
implementation and native presenter/reducer logic select tests without a
standalone app build. Shared public composition changes select both builds.
Unknown files select everything.

This is intentionally more conservative than a filename-only "UI changed"
rule because build and integration regressions commonly originate outside view
files.

### Run complete shared and Android host tests through one repo-owned job

The Android test lane will enumerate every module that currently contains host
tests: `shared-core`, both shared feature modules, `shared-di`, and
`android-app`. This job does not assemble an APK or AAB explicitly. The first
increment keeps platform setup compatible with the current Kotlin Toolchain;
moving Android host tests to Linux is a measured follow-up after the exact job
is proven there.

### Use explicit `PullRequest` and `Nightly` Xcode test plans

Both plans initially contain the existing `appTests` target. `PullRequest` is
the default and stays focused on deterministic reducer and adapter behavior.
`Nightly` is selected explicitly by scheduled CI and is where future UI,
integration, localization, and broader configuration tests are added. The Xcode
wrapper will always emit an `.xcresult` bundle so failures retain structured
diagnostics.

Separate Xcode schemes were considered but test plans express test scope more
directly and follow Apple's intended mechanism for running different suites and
configurations from the same scheme.

### Separate validation from credentialed delivery

The pull-request workflow receives read-only repository permissions and no
release environments. A scheduled workflow runs full tests and release-
configuration, code-signing-disabled smoke builds and publishes SHA-addressed
diagnostic artifacts plus a candidate manifest. Credentialed archive creation
and store upload remain manual release operations.

Until the repository has protected signing environments available to scheduled
jobs, the nightly output is a source/build candidate rather than a signed store
binary. The documentation will state this boundary rather than labeling an
unsigned simulator build releasable. A later increment can archive signed AAB
and IPA artifacts once secrets and retention policy are configured.

### Use the store as the durable promotion boundary

Once signed nightly candidates are enabled, Android candidates should enter the
Play internal track and iOS candidates should enter TestFlight. Later release
steps promote/select those exact builds. GitHub artifacts remain useful for
logs, manifests, and short-lived inspection but are not the sole long-term
release registry.

## Risks / Trade-offs

- **Classifier misses an important path** → Unknown paths and all operational
  manifests fail open to full validation; classifier fixtures cover each
  category.
- **Skipped standalone builds hide integration failures** → Shared composition,
  UI, project, dependency, and tooling changes still select builds; nightly
  validates both complete apps.
- **App-hosted iOS tests remain relatively expensive** → Use a focused PR plan
  now; consider extracting pure Swift behavior into a package only after timing
  evidence justifies an architectural change.
- **Nightly failures are detected after merge** → Document that only an exact
  successful nightly SHA is certified; urgent releases can manually dispatch
  the same full candidate workflow.
- **Unsigned scheduled builds are not store artifacts** → Call them build
  candidates explicitly and keep signed-release enablement as a tracked task,
  not an implicit guarantee.

## Migration Plan

1. Add and test the repo-owned classifier and complete host-test lane.
2. Convert the current workflow to selective PR/default-branch validation with
   one aggregate result while preserving manual releases until split safely.
3. Add explicit Xcode test plans and structured result bundles.
4. Add the nightly full-validation workflow and SHA manifest.
5. Move manual credentialed jobs into a release-only workflow and update branch
   protection to require the aggregate PR result.
6. After protected signing environments and retention are configured, extend
   nightly certification to signed Play Internal and TestFlight builds.

Rollback is performed by restoring the previous workflow trigger/job graph;
the repo-owned job names remain compatible throughout the migration.

## Open Questions

- The target pull-request duration and macOS-runner budget should be set after
  authenticated run history is available and p50/p95 timings can be measured.
- The first Android and iOS UI smoke flows will be selected when stable UI test
  targets exist.
