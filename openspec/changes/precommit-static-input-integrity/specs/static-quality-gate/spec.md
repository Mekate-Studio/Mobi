## Purpose

Make Mobi's static validation cover its declared source surfaces and ensure local
commit checks validate the same complete content that is staged for commit.

## ADDED Requirements

### Requirement: Shared and explicit static inputs

Lint and explicit formatting SHALL share source discovery for declared modules,
platform source roots, Kotlin scripts, Swift package source and repository shell
scripts/hooks. Manual lint SHALL include nonignored new source files. Tracked
ignored source SHALL remain accounted for. Unsupported layouts or paths SHALL
fail explicitly. Generated untracked outputs SHALL be excluded with a documented
policy. The gate SHALL expose its exact input manifest.

#### Scenario: A new module and Swift package file
- **WHEN** a developer declares a module with platform-qualified source and adds Swift package source
- **THEN** applicable analyzers receive those files without updating a module-name allowlist

#### Scenario: Unsupported layout
- **WHEN** source discovery encounters a template, custom source root or unsupported source symlink
- **THEN** it fails with the offending input before returning a successful result

#### Scenario: Unusual filenames
- **WHEN** eligible files contain spaces, tabs, newlines or leading dashes
- **THEN** the files remain distinct inputs and cannot be interpreted as flags

### Requirement: Commit content identity

The hook and manual commit check SHALL require actual checkout bytes and modes
to equal the index before and after analysis. They SHALL reject partial staging,
unstaged deletions or renames, intent-to-add, unmerged entries, unsupported sparse
or trust flags, escaping symlinks and nonignored untracked files. A change to the
index or checkout observed after analysis SHALL invalidate the result, including
changes with restored size and modification time.

#### Scenario: Partial staging
- **WHEN** staged source differs from the working copy
- **THEN** the commit check fails before running an analyzer and preserves both copies

#### Scenario: Concurrent modification
- **WHEN** a tracked file or index changes during analysis and remains changed at the final check
- **THEN** the check fails even if all analyzers report success

#### Scenario: Fully staged content
- **WHEN** every intended file is staged and remains unchanged through analysis
- **THEN** the check can pass without modifying the index or checkout

### Requirement: Read-only static execution and distinct modes

The commit gate SHALL NOT format, install tools, look up dependencies, stage,
stash or restore files. Missing tools SHALL fail before analysis with setup
guidance. Static-only manual and CI entry points SHALL use the same collector
without imposing commit staging requirements. Each applicable analyzer SHALL run
once per invocation. The gate SHALL report tool versions, input counts and
per-tool and total duration. Formatting SHALL require explicit invocation.

#### Scenario: Manual and CI parity
- **WHEN** manual lint, commit check and the CI quality job inspect the same fully staged fixture
- **THEN** they expose equivalent source manifests and one execution per applicable analyzer

#### Scenario: Missing tools
- **WHEN** one or more required analyzers are unavailable
- **THEN** the command fails with setup guidance before starting any analyzer
