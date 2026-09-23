## Purpose

Select sufficient mobile validation for reviewed staged content and execute it
without hidden changes to that content or silent omission of declared tests.

## ADDED Requirements

### Requirement: Conservative shared selection
Local and CI selection SHALL classify exact changed paths. App manifests,
dependency/toolchain inputs and unknown paths SHALL select full validation.
Behavior-only changes SHALL select affected tests without duplicate standalone
packaging. Deletions and both names of a rename SHALL remain inputs.

#### Scenario: Manifest changes
- **WHEN** either app module manifest changes
- **THEN** both platforms' tests and debug builds are selected

#### Scenario: Shared behavior
- **WHEN** shared feature behavior changes without build-affecting paths
- **THEN** host and iOS tests are selected without standalone debug builds

### Requirement: Declared tests cannot disappear
Host test selection SHALL discover test-bearing modules from the declared graph.
Unsupported graph/layout/test targets SHALL fail explicitly before claiming a
successful test plan.

#### Scenario: New module
- **WHEN** a declared Android-capable module contains supported Kotlin tests
- **THEN** its tests are included without editing a module-name list

### Requirement: Isolated commit validation
The commit gate SHALL run static analysis once and selected jobs once against
the reviewed content. Native jobs SHALL execute in an owned source copy with
validation preparation preserving tracked version metadata. The gate SHALL NOT
stage, stash, restore or otherwise repair caller content/index, install analyzers,
adopt dependencies or perform release operations.

#### Scenario: Successful validation
- **WHEN** all selected jobs pass and caller/index/copied tracked inputs retain their identities
- **THEN** the gate reports success with input identities and the completed job plan

#### Scenario: Drift or job failure
- **WHEN** a job fails or tracked content/modes or the caller index change
- **THEN** the gate fails even if prior checks passed and reports recovery guidance

#### Scenario: Interrupted execution
- **WHEN** a selected job times out or the gate is interrupted
- **THEN** it stops its owned child process group and cleans only its owned snapshot without reporting success

#### Scenario: Gradle detaches from the child process group
- **WHEN** native execution creates versioned Gradle daemon registries in its private Gradle user home
- **THEN** the gate stops each version using only an installed distribution within that home, offline and with a bounded shutdown deadline
- **AND** shutdown failure, timeout or an unavailable or escaping launcher/registry retains the owned recovery path and prevents a pass
- **AND** caller/global Gradle registries are not used for shutdown

#### Scenario: Native shutdown metadata races with cleanup
- **WHEN** an exiting native tool briefly recreates files in the owned snapshot during removal
- **THEN** the gate retries directory-not-empty cleanup failures for at most five seconds
- **AND** persistent cleanup failure reports the owned path and prevents a pass

### Requirement: CI separation
CI's quality job SHALL remain static-only; native CI jobs SHALL retain independent
selection and use the same test discovery and validation preparation contracts.

#### Scenario: Quality job
- **WHEN** CI invokes quality-check
- **THEN** native jobs are not invoked recursively
