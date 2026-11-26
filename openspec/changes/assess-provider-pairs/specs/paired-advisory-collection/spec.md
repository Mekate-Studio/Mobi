## Purpose

Preserve a meaningful baseline/candidate advisory comparison when optional provenance reference requests compete for the same bounded provider budget.

## ADDED Requirements

### Requirement: Advisory work precedes checksum leads for both phases

The assessment SHALL request both phases' advisory query batches and unique matched finding records before requesting optional archive checksum leads. Shared finding IDs MUST be fetched once per paired collection.

#### Scenario: Checksum budget is exhausted

- **WHEN** baseline and candidate share findings and checksum requests consume the remaining provider budget
- **THEN** both advisory receipts retain their completed advisory results and independently report incomplete checksum coverage

### Requirement: Shared evidence preserves phase attribution

The assessment SHALL retain each phase's exact query requests, matched queries and original provider packets. A shared record failure MUST be visible in each matching phase without contaminating unrelated phases.

#### Scenario: A candidate-only query fails

- **WHEN** a candidate query batch fails while baseline queries and records succeed
- **THEN** candidate advisory coverage is incomplete and baseline coverage remains attributable to its own successful evidence

### Requirement: Incomplete evidence cannot authorize adoption

The assessment MUST keep existing request/deadline bounds, incomplete comparison guards, and explicit human adoption decisions.

#### Scenario: Required provider work exceeds its limit

- **WHEN** the provider budget expires before required advisory work completes
- **THEN** affected receipts and comparisons remain incomplete and missing records establish no resolution or introduction
