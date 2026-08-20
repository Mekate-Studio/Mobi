## Why

Mobi currently runs separate Android and iOS debug builds before their test
jobs on every pull request, even though those jobs use fresh runners and do not
share build products. The repository needs a documented validation policy that
keeps pull-request feedback small while certifying immutable release candidates
from `main` with broader native and UI-oriented testing.

## What Changes

- Split pull-request validation, nightly release-candidate certification, and
  manual release promotion into distinct workflow responsibilities backed by
  repo-owned scripts.
- Run the existing quality checks and the complete shared/Android host-test
  surface on pull requests without requiring standalone app builds first.
- Add conservative change classification so native app builds run for UI,
  resources, project configuration, dependencies, and other build-affecting
  changes, with full validation as the fallback.
- Add explicit Xcode test plans for pull-request and nightly scopes, following
  Apple guidance for targeted review feedback and broader scheduled testing.
- Build both platforms nightly in release configuration, retain traceable
  artifacts for the exact `main` SHA, and keep publishing as a separate manual
  action.
- Document the validation tiers, releasability boundary, local commands, and
  extension points for future UI and smoke tests.

## Capabilities

### New Capabilities

- `mobile-ci-validation`: Defines impact-aware pull-request validation,
  scheduled release-candidate certification, Xcode test-plan scope, and
  promotion-only release behavior.

### Modified Capabilities

None.

## Impact

- GitHub Actions workflows under `.github/workflows/`
- Repo-owned CI scripts under `scripts/ci/` and Android Fastlane test routing
- The iOS shared scheme and new Xcode test-plan files
- Public CI and local-validation documentation
- Branch-protection configuration, which should eventually require one stable
  aggregate pull-request gate
