## 1. Change Classification and Host Tests

- [x] 1.1 Add a repo-owned conservative changed-path classifier with local fixtures for documentation, behavior, UI, build-system, and unknown changes
- [x] 1.2 Expand the Android host-test job to execute every shared and Android module that currently contains tests

## 2. Apple Test Scope

- [x] 2.1 Add explicit PullRequest and Nightly Xcode test plans to the shared app scheme
- [x] 2.2 Update the iOS test wrapper to select a plan and retain a deterministic xcresult bundle

## 3. Workflow Tiers

- [x] 3.1 Convert pull-request/default-branch CI to job-level impact selection with one aggregate gate and no standalone build prerequisite for test-only changes
- [x] 3.2 Add a scheduled and manually dispatchable full candidate workflow with release-configuration builds, full tests, and a SHA-addressed manifest
- [x] 3.3 Move credentialed archive, store upload, and track promotion jobs into a release-only workflow

## 4. Documentation

- [x] 4.1 Document validation tiers, changed-path policy, Apple test plans, local commands, and the exact-SHA certification boundary
- [x] 4.2 Document the current unsigned nightly boundary and the protected-signing requirements for build-once/promote-later releases

## 5. Validation and Activation

- [x] 5.1 Run classifier fixtures, shell checks, Xcode test-plan discovery, representative host tests, workflow parsing, and strict OpenSpec validation
- [ ] 5.2 Configure repository branch protection to require only the aggregate pull-request gate
- [ ] 5.3 Configure protected scheduled signing environments and store retention before labeling nightly outputs as releasable binaries
