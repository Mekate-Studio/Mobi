## Context

See proposal.md. Slice 2 is pushed at `10319cd`; the existing classifier and
repo-owned jobs remain the integration points. Static tooling is already pinned.

## Goals / Non-Goals

**Goals:** Exact staged-path selection, discovered host tests, validation without
tracked metadata rewrites, and explicit drift/failure evidence.

**Non-Goals:** A general dependency executor, hermetic native tools, simulator
provisioning, native-platform expansion, upgrade/adoption or release changes.

## Decisions

- Keep classifier policy in Bash so the Ubuntu classification job needs no new
  runtime. Move manifests/build inputs ahead of platform patterns. Use NUL paths
  from Git with rename detection disabled (both names remain inputs); retain the
  existing newline fixture interface and add an explicit NUL interface.
- Reuse the existing validated YAML graph reader for test discovery. Enumerate
  test-bearing Android modules, including new declared modules. Unsupported
  platform-specific Kotlin tests fail explicitly until a runner is provided.
- Android test prep configures Java/SDK and synthetic debug signing only. It
  neither versions tracked manifests nor installs Bundler. The host test job
  calls the existing Kotlin log wrapper directly; Fastlane and local test
  helpers consume the same discovered module list.
- Commit mode runs pinned static checks once, then copies all reviewed tracked
  files/modes into a temporary directory without Git registration/index writes.
  Jobs run there with validation mode enabled and a small environment allowlist.
  No ignored credentials or caches are copied. Locked project dependencies and
  the existing Toolchain wrapper can download into owned snapshot caches;
  analyzer installation, dependency upgrades and global gem installation do
  not occur. This is source isolation, not an OS/network sandbox.
- Reuse android-test, ios-test and selected debug builds once each. Behavior
  paths need tests without a second standalone package build; app manifests,
  dependencies, toolchain/CI inputs and unknown paths retain full validation.
- Check copied tracked bytes/modes before and after each job and caller/index
  and HEAD identity throughout. Bind copied bytes/modes to captured staged Git
  objects before execution; reject new authored sources in module/package roots.
  Any drift, job failure or interruption prevents success.
  Bound child job execution and stop its process group before deleting only the
  owned snapshot. Report plan/input identities and completed jobs; no reusable
  pass receipt can skip future checks.
  Stop each installed Gradle version against only the owned Gradle user home,
  using its local distribution offline and a 30-second shutdown deadline. Missing
  or escaping launchers/registries, shutdown failure or timeout retain the copy
  for recovery and prevent success. Do not invoke global Gradle or download a
  replacement during cleanup.
  Retry only directory-not-empty removal failures for at most five seconds to
  tolerate native shutdown registry writes. Persistent failure retains recovery
  guidance and prevents success; permission and other removal errors are not hidden.
- Keep `--static` and `--manifest` behavior; add `--plan` for a read-only staged
  plan. CI quality never invokes the local native orchestrator.

## Risks / Trade-offs

- Cold owned caches add time → report job timings; do not share mutable caller
  caches or invent success when SDK/network/simulator prerequisites are missing.
- Xcode may rewrite lock/project inputs → fail with the path and repair outside
  the gate. Do not silently accept or restore those writes.
- Concurrent edits can invalidate evidence → compare forced content/modes and
  index identities after jobs; edits changed and restored entirely between
  observations remain outside the snapshot guarantee.
- Native tools and selected simulator are host resources → disclose this limit;
  no new simulator creation/deletion or release signing is introduced.
- Process groups do not own native daemons that detach → request nonpersistent
  CLI Gradle and in-process Kotlin compilation in the owned cache. Gradle Tooling
  API always uses a daemon despite that setting, so stop each registered version
  explicitly before removal. Inspect residual resources after interrupted probes.
  Broader detached-process ownership belongs to the common executor; do not claim
  hermetic cleanup from group termination alone.

## Migration Plan

Existing hook and `just check` gain selected native checks. Use `just lint` or
`check.sh --static` during unstaged development and `check.sh --plan` before a
commit. Revert this slice to restore the static-only hook; slice 2 stays usable.
