## Context

See `proposal.md` and the first slice in `docs/maintenance/implementation-proposal.md`.
The repository has a simple explicit module list, five installed analyzers and
Bash entry points. Ruby is already part of the development environment.

## Goals / Non-Goals

**Goals:** One deterministic source inventory and a truthful commit check without
altering a developer's index or working tree. Keep ordinary manual lint useful
while files are unstaged.

**Non-Goals:** Hermetic execution, tool installation or pin enforcement, native
tests, arbitrary Toolchain configuration evaluation, dependency maintenance.

## Decisions

- Use a Ruby standard-library collector/runner behind the existing shell entry
  points. NUL-delimited Git inventory includes tracked and nonignored untracked
  files. JSON output quotes unusual filenames and records inputs, hashes,
  versions and timings without creating repository output files.
- Validate the explicit `project.yaml` module list and simple source layout.
  Include Kotlin sources in `src`, `test`, `src@*` and `test@*`, Kotlin scripts,
  all Swift source and repository shell scripts/hooks. Reject unsupported
  templates, custom roots, undeclared Kotlin roots and ambiguous analyzer path
  syntax instead of silently accepting incomplete coverage. Generated untracked
  outputs have explicit exclusions; tracked files are never hidden by ignores.
- Pass individual files as argv (SwiftLint uses its script-input environment).
  Do not pass directories that would let tools discover additional ignored files.
  Reject source symlinks explicitly because analyzers differ in traversal;
  other symlinks must resolve within the repository in commit mode.
- Commit mode requires the entire index to match actual checkout bytes and
  executable/symlink modes. Reject unmerged entries, intent-to-add, sparse and
  trust flags, submodules and nonignored untracked files before analysis.
  Compute Git blob hashes directly, bypassing Git's stat cache and trust flags.
  Repeat the comparison and compare index snapshots after analysis, including
  when an analyzer fails. This avoids stashing and staging automation.
- Keep manual lint and CI static checks free of commit orchestration. Formatting
  is a separate explicit operation using the same collector. Missing tools fail
  together before analyzers run. Report installed versions without claiming pins.

## Risks / Trade-offs

- Full staging is less convenient than partial commits → give actionable
  diagnostics and keep `just lint` available at any time.
- Direct byte comparison rejects checkout-transforming filters and line-ending
  conversions → document this boundary; do not execute arbitrary clean filters.
- Before/after checks are not an atomic snapshot or a sandbox → reject observed
  drift and avoid claiming protection against edits that are changed and restored
  entirely during analysis. Process isolation is a later slice.
- Existing analyzers have different filename syntax → reject unsupported glob
  or comma syntax clearly; cover whitespace and leading dashes in tests.
- Tool versions remain environment-dependent → report them; pinning is slice 2.

## Migration Plan

Keep command names stable. Change the hook to `check.sh` and dispatch the CI
quality job with `check.sh --static`. Document staging requirements and supported
layouts. Verify contracts in disposable repositories plus real-analyzer baseline
and negative probes. Rollback is a normal reviewed revert of this slice; no
environment, schedule, dependency or release migration is involved.
