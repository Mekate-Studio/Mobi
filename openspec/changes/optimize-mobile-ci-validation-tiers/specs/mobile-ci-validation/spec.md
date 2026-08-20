## Purpose

Defines how Mobi validates pull requests efficiently while certifying traceable
mobile release candidates from the default branch with broader native testing.

## ADDED Requirements

### Requirement: Pull requests receive impact-aware validation

The repository MUST classify changed paths conservatively and MUST run the
quality checks and test/build jobs selected for the affected architecture
surfaces. An unrecognized or build-system-affecting change MUST select full
native validation rather than skipping potentially relevant work.

#### Scenario: Behavior-only shared code changes
- **WHEN** a pull request changes shared behavior without changing shared UI,
  native project configuration, or build tooling
- **THEN** the pull request runs the affected shared and native behavior tests
- **AND** standalone Android and iOS app-build jobs are not required

#### Scenario: Native-build-affecting paths change
- **WHEN** a pull request changes shared UI, native UI or resources, native
  project configuration, dependencies, release tooling, or CI behavior
- **THEN** the pull request runs the affected platform tests and app builds

#### Scenario: Change impact is unknown
- **WHEN** the classifier encounters a changed path it does not recognize
- **THEN** it selects full Android and iOS validation

### Requirement: Pull requests expose one stable required result

Pull-request validation MUST produce an aggregate result that fails when any
selected validation job fails or is cancelled and succeeds when all selected
jobs succeed or irrelevant jobs are intentionally skipped.

#### Scenario: Documentation-only change
- **WHEN** a pull request changes only recognized documentation files
- **THEN** expensive native jobs are skipped
- **AND** the aggregate pull-request result still completes successfully after
  the selected lightweight validation passes

#### Scenario: Selected validation fails
- **WHEN** any job selected by change impact fails or is cancelled
- **THEN** the aggregate pull-request result fails

### Requirement: Existing behavior tests are complete

The pull-request test contract MUST execute the repository's shared-core,
shared feature, shared dependency-wiring, and Android presentation tests rather
than describing a partial module list as all tests.

#### Scenario: Shared module adds a regression test
- **WHEN** a test is added to a registered shared behavior or dependency module
- **THEN** the normal shared/Android test job executes that module's tests

### Requirement: iOS tests use explicit review and scheduled plans

The iOS project MUST expose an explicit pull-request test plan for fast native
behavior feedback and a separate nightly plan that is the extension point for
the complete unit, integration, and future UI-test surface.

#### Scenario: Pull-request iOS tests run
- **WHEN** iOS validation is selected for a pull request
- **THEN** Xcode runs the pull-request test plan on one eligible iPhone
  simulator

#### Scenario: Nightly iOS tests run
- **WHEN** scheduled candidate validation runs
- **THEN** Xcode runs the nightly test plan and retains its result bundle for
  failure diagnosis

### Requirement: Nightly validation certifies an exact default-branch commit

The scheduled candidate workflow MUST run against the default branch, MUST
execute the full test and release-configuration build surface for both
platforms, and MUST identify every retained artifact with the exact source
commit SHA.

#### Scenario: Nightly validation succeeds
- **WHEN** all nightly tests and release-configuration builds succeed
- **THEN** the workflow retains Android and iOS candidate artifacts and a
  manifest that identifies the source SHA and workflow run

#### Scenario: Default branch advances after certification
- **WHEN** new commits reach the default branch after a nightly candidate was
  certified
- **THEN** only the previously certified SHA is considered the green candidate
- **AND** the newer default-branch head is not represented as certified by that
  run

### Requirement: Release delivery promotes a certified build

Release delivery MUST consume or promote artifacts associated with a validated
candidate SHA instead of silently rebuilding a different source revision and
calling it the same candidate.

#### Scenario: Candidate is released
- **WHEN** a maintainer approves delivery of a certified candidate
- **THEN** the release path uses the stored Android or iOS build associated with
  that candidate SHA
