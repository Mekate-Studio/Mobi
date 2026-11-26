## Context

See proposal.md. The collector currently completes each phase serially, including optional checksum leads. HTTP payload caching already exists; the global cap is 128 requests and is shared with official release collection.

## Goals / Non-Goals

**Goals:** prioritize comparable advisory evidence for both phases; retain exact raw packets and per-phase query/failure attribution.

**Non-Goals:** raising limits, changing provider/schedule policy, proving selected classpaths, declaring adoption readiness or manually assessing a release.

## Decisions

- Use three ordered stages: both phases' existing query batches; one lookup for each unique finding ID across those phases; checksum leads after both advisory receipts are populated. This removes starvation without changing batch membership or requiring synthetic provider responses. A combined union query batch was considered but would change receipt mapping unnecessarily for this slice.
- Retain the existing single-input collector as a wrapper over the same stage implementation, so historical fixtures and callers share behavior.
- Record `advisory_state` before checksum collection. The overall provider/security states and conservative finding-delta guard remain unchanged: partial independent byte references cannot become an adoption recommendation.
- Shared record fetches carry original provider packets into each affected phase. Query origins and record failures remain specific to the phases that matched the finding.

## Risks / Trade-offs

- Shared record failures affect both matching phases → preserve that failure on each receipt and retain observed findings without inferred clearance.
- The global budget can still expire during required advisory work → mark coverage incomplete and retain existing bounded HTTP behavior; do not reserve or invent successful responses.
- Checksums may still be budget-limited → report them independently after advisory collection; provenance gaps stay blocking.

## Migration Plan

Add focused ordering/budget/failure contracts, route native qualification through paired collection, then exercise its production security stage against digest-bound native inputs with fresh providers. This isolates the provider change without repeating the earlier candidate build. Record that scope explicitly, retain a compact result, and keep raw inventories ignored. The normal local and hosted gates apply before review; dependency adoption remains a separate exact-packet decision.
