## Purpose

Keep mobile platform support explicit and configurable while requiring source-bound
evidence and an informed maintainer decision for compatibility-impacting changes.

## ADDED Requirements

### Requirement: Configurable stable-major support window
The workflow SHALL derive each platform minimum from a configurable number of
stable major releases behind the latest reviewed stable major. Mobi SHALL default
to one. Preview, beta, RC and quarterly/minor releases SHALL NOT advance that window.

#### Scenario: Nonconsecutive version names
- **WHEN** the reviewed stable history is iOS 18, 26, 27 and the lag is one
- **THEN** the proposed minimum is iOS 26 rather than a computed numeric predecessor

#### Scenario: Missing or stale evidence
- **WHEN** release evidence is missing, stale, future-dated or ambiguous
- **THEN** assessment is incomplete and cannot authorize a minimum update

### Requirement: Separate declared and validated support
Assessment SHALL inventory app, test and package minimum declarations separately
from SDK versions. Implicit defaults and disagreement SHALL be visible. Declared
support SHALL NOT be presented as runtime validation.

#### Scenario: Package minimum differs from inherited app minimum
- **WHEN** the package declares iOS 16 and the app has no explicit minimum
- **THEN** assessment reports the implicit app setting and proposes explicit app/test policy

### Requirement: Informed architecture and support decisions
The manual update workflow SHALL assess upstream compatibility and retained/lost
capabilities. Architecture removal, API changes, OS-floor changes and dependency
default changes SHALL require explicit impact review and a maintainer adoption
decision. Passing a build SHALL NOT automatically authorize migration or bridge removal.

#### Scenario: Upstream removes a declared target
- **WHEN** an update fails because upstream no longer publishes that architecture
- **THEN** the workflow offers an isolated supported-target assessment and explains
  its support loss instead of silently downgrading or deleting the target

### Requirement: Isolated OS rehearsal and owned recovery
The OS candidate SHALL run baseline-first with exact edits and existing mobile
checks, recording simulator differences. It SHALL test the candidate on an available
runtime in the proposed minimum major, or report missing evidence. A fresh named
store SHALL NOT change ownership or cleanup permissions for a historical store.

#### Scenario: Host ownership changed
- **WHEN** the historical store belongs to another host and a fresh store is explicitly named
- **THEN** new execution uses a newly owned store and historical resources remain untouched
