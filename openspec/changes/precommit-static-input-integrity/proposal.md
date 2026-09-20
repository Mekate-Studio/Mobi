## Why

The existing static gate can pass while omitting new Kotlin files, Swift package
sources, additional module roots, or the hook itself. It also checks working-tree
content even when a commit contains different staged content. The first approved
maintenance slice closes these false-green paths before expanding the toolset.

## What Changes

- Share source discovery between lint and explicit formatting; include declared
  modules, platform roots, Kotlin scripts, Swift package code and shell hooks.
- Make the pre-commit hook and `just check` reject an index/checkout mismatch,
  unsupported Git states and changes made during analysis.
- Keep `just lint` and the repository quality job as explicit static-only paths.
- Report input manifests, installed tool versions and timings; add disposable
  repository contract tests and representative real-analyzer probes.

## Capabilities

### New Capabilities

- `static-quality-gate`: Complete, shared static inputs and content-bound local
  commit validation with explicit failures and read-only analysis.

### Modified Capabilities

None. Native CI selection and release behavior are unchanged.

## Impact

Changes are limited to development scripts, the hook, static source selection,
documentation and contract tests. Commit checks become stricter: stage complete
intended content first, or use manual lint during development. Analyzer versions
and rules are unchanged. Dependency adoption, bridge changes, runtime pinning,
native-test orchestration and scheduling remain later work.
