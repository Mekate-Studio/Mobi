# First slice: static coverage and commit identity

Implemented and locally verified on 2026-09-20. This implements slice 1 of the
[proposal](implementation-proposal.md), recorded in the active
[OpenSpec change](../../openspec/changes/precommit-static-input-integrity/proposal.md).
The [original audit](audit.md) remains historical evidence for the earlier gate.

## Implemented behavior

The existing hook calls `check.sh`, which compares the complete index with actual
checkout bytes and modes before and after analysis. Partial staging, new
nonignored files, unmerged/intent-to-add entries, trust flags, sparse entries,
submodules and escaping symlinks fail. No index or checkout repair is attempted.

The five existing analyzers use one inventory shared with explicit formatting.
New declared modules and platform roots are discovered; manual lint sees new
nonignored files. Swift package source and the hook are now covered. Unsupported
layouts and analyzer path syntax fail explicitly. CI's quality job selects
static mode and no longer performs the unrelated Kotlin build bootstrap.

Commands, supported roots, output exclusions and recovery are documented in
[local development](../reference/local-development.md#static-gate-inputs-and-recovery).
Analyzer rules and versions were not changed. The SwiftLint configuration's old
directory selection was replaced by explicit file inputs; disabled rules remain
the same. Ruby uses its standard library without a new gem dependency.

## Verified facts

The [sanitized evidence record](evidence/2026-09-20-static-gate.json) captures
source hashes, actual tool versions, counts, timings and probe outcomes. Logs
were collected outside the checkout. Reproducible tests are repository-owned:

| Verification | Result |
| --- | --- |
| `ruby scripts/dev/test_quality.rb` | 23 disposable-repository contract tests passed with Ruby 4.0.6 and again with system Ruby 2.6.10; shell entry points retain their existing PATH-based runtime selection |
| `ruby scripts/dev/test_quality_real.rb` | Real baseline and violation/repair probes passed for new Kotlin source, Swift package source, detekt in a new module's `src@ios`, and ShellCheck on the hook |
| Real filename probes | Spaces, tabs, newlines and leading dashes stayed distinct. Kotlin's filename rules rejected unsuitable names; Swift and shell inputs passed unchanged |
| `./scripts/ci/run_job.sh quality-check` | Passed over this working copy: 39 ktlint inputs, 36 detekt inputs, 24 Swift inputs, 43 shell/hook inputs |
| Full-checkout pre-commit rehearsal | Copied all 291 then-current tracked/nonignored files into a disposable repository, staged the copy, ran the actual hook successfully, and verified unchanged index and checkout. The caller's index remained unchanged and the copy was removed |
| Contract entry-point parity | Hook, manual check, lint and the CI job exposed identical manifests and one analysis invocation per applicable tool |
| Concurrent edits | Byte changes with restored size/mtime, index updates and new files during a slow fake analyzer invalidated otherwise successful analysis |
| Static review | Ruby syntax, `git diff --check`, and strict validation of this OpenSpec change passed |

Observed tools: ktlint 1.8.0, detekt 1.23.8, SwiftFormat 0.62.1, SwiftLint 0.65.0,
ShellCheck 0.11.0; primary runtime Ruby 4.0.6 on Apple Silicon with system Git
2.54.0. An extra system-Ruby test exposed a fixture-only prerequisite: Apple's
Ruby startup invokes `uname`. The missing-tool fixture now retains that command
while withholding analyzers; the complete suite passes on both runtimes.
The static job took 4.955 seconds and the full-copy hook took 5.373
seconds in these warm local runs. The original audit's 7.05-second measurement
is context, not a controlled performance comparison or a timing guarantee.

No package installation, dependency discovery, native build, release command,
caller staging, commit, push, publishing or schedule change was performed. Tests
create disposable indexes and a synthetic HEAD object for one Git edge case;
they do not commit changes in the working repository. At validation time, the
audit documents and this implementation were uncommitted.

## Untested assumptions and remaining limits

- Hosted macOS runner execution and fresh tool installation were not run. Local
  command parity is verified; cold-runner availability is a separate result.
- Tools and runtime are reported, not enforced. Configuration and inherited
  environment remain trusted. This is content/coverage correctness, not a
  hermetic or fully reproducible gate. Pinning is slice 2.
- Before/after comparisons detect persistent drift, not edits changed and
  restored entirely within a run. There is no process sandbox or atomic source
  snapshot yet. Manual/CI static mode does not claim commit identity.
- Native tests, compiler-plugin compatibility, bridge retention/retirement,
  onboarding builds and release packaging were not revalidated by this slice.
  Their existing entry points/defaults remain unchanged.
- Templates, custom roots, source/directory symlinks, submodules and sparse
  checkouts require explicit support work before use; failures are intentional.
  No Go or Elixir tools are activated by this gate.

## Blockers and recovery

No implementation blocker remains for this slice. One local environment issue
was verified: an old Intel-only Git earlier on PATH cannot be launched by the
native Ruby runtime. Validation selected compatible system Git through a
command-local PATH; no machine configuration was changed. The gate now reports
this failure with recovery guidance.

The caller checkout was intentionally unstaged during validation. The recorded
successful commit-mode result belongs to the isolated fully staged copy. Normal
commit mode requires intended changes to be staged in full. Hook activation is
an explicit per-clone `core.hooksPath` setting documented in the local guide.

The next small integration is reviewed tool/runtime pinning and a separate
bootstrap, keeping installation outside the hook. Dependency rehearsal and the
Kotlin Toolchain upgrade remain subsequent slices.
