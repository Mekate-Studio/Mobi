## Purpose

Provide source-bound dependency inventories and conservative evidence checks
that preserve missing coverage before maintenance decisions can be reviewed.

## ADDED Requirements

### Requirement: Explicit pinned discovery tools
Discovery SHALL use verified pinned tools and runtime. Installation SHALL be
explicit and isolated from application dependency adoption and discovery.

#### Scenario: Missing or changed installation
- **WHEN** required tools are absent or their receipt no longer matches
- **THEN** discovery fails with installation/recovery guidance instead of using PATH or downloading tools

### Requirement: Native extraction and coverage ledger
The inventory SHALL bind source, effective configuration and tool identities.
It SHALL retain native extraction, supplemental sources, module/manager coverage,
locked direct/transitive records and unresolved target/variant graphs separately.

#### Scenario: Extraction omits an input
- **WHEN** a declared module, plugin, lock or required manager lacks successful coverage
- **THEN** the inventory reports the omission and cannot claim complete resolved coverage

#### Scenario: Failed extraction
- **WHEN** extraction fails, times out, produces malformed/truncated data or changes source inputs
- **THEN** it reports an explicit failure and cleans only its owned temporary resources

### Requirement: Conservative release evidence
Evaluation SHALL retain raw candidates and every applicable exclusion reason.
Stable candidates need a verified publication time at least seven days old;
major updates require separate review and repository ceilings remain enforced.

#### Scenario: Missing or blocked candidate data
- **WHEN** a release lacks timestamps, a provider fails or is incomplete, or a ceiling excludes a candidate
- **THEN** those candidates and reasons remain visible and unavailable data cannot mean no updates

### Requirement: Fresh resolved advisory evidence
Advisory evaluation SHALL require exact input identity, complete provider coverage
and response digests retrieved within 24 hours. It SHALL report all findings,
block high/critical severity and require triage for unknown severity.

#### Scenario: Stale or unavailable required evidence
- **WHEN** a required ecosystem or resolved graph is absent, or its advisory evidence is stale, failed or mismatched
- **THEN** evaluation is incomplete and cannot report a clean result

### Requirement: Independent dormant backend adapter
The common inventory/evidence core SHALL NOT require Android, Xcode, Erlang or
PostgreSQL. The absent Elixir backend SHALL remain explicitly not applicable.

#### Scenario: Mobile-only checkout
- **WHEN** no backend is configured
- **THEN** discovery reports the Elixir profile dormant without provisioning tools or services
