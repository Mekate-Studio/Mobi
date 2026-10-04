## Why

Toolchain adoption and the local direct round trip do not establish typed API or async behavior parity. The next bridge-retirement gate needs identical native consumer fixtures in the retained-bridge and bridge-unavailable paths, including the current Swift client's cancellation behavior.

## What Changes

- Add bounded assessment fixtures for typed sealed-state payloads, one generic payload box, real exported suspend success/failure/cancellation and explicit continuation completion/reuse.
- Execute both paths through the existing owned `direct-facade` profile, without changing the production integration or maintenance evaluator.
- Retain fixture bytes, original and added test identities, complete producer/report bindings, failures, cleanup and measured behavior in a separate public evidence record.
- Review measured equivalence and limitations before preparing a reversible direct-default proposal.

## Capabilities

### New Capabilities

- `bounded-native-interop-assessment`: Source-bound paired native evidence for named typed/async fixtures, with explicit missing and unmeasured capabilities.

### Modified Capabilities

None. Existing production APIs, build defaults and maintenance policy behavior are unchanged.

## Impact

Assessment-only Kotlin/Swift fixture templates, maintenance documentation/evidence and this OpenSpec change. Fixture source is added only to an isolated assessment source and executor-owned copies. No application feature, generic production state, dependency change, schedule, direct-default switch or physical bridge deletion is introduced. Existing risk scope and expiry remain unchanged; hosted adoption validation proceeds independently.
