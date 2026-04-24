# Platform Direction

`Mobi` is evolving from a public mobile architecture reference into a public
platform proof of concept for living documentation.

The long-term target is broader than a mobile sample app. The repository should
eventually demonstrate how capability-driven specifications, architecture
documentation, and runnable code can stay aligned across mobile, backend, and
web-facing surfaces. The mobile app remains the current implementation focus,
but it should now be framed as the first serious slice of a larger car-sharing
platform.

## Product framing

The reference product is a consumer-facing car-sharing platform operating under
simulated but realistic conditions.

That means the system should model real product constraints such as:

- rider location and proximity-based vehicle discovery
- changing fleet availability over time
- stale snapshots and transient network failures
- reservation holds and expirations
- trip lifecycle rules
- range, energy, and readiness signals

The repository does not need real vehicles or production infrastructure to be
credible. It does need realistic state transitions, realistic failure modes,
and documentation that explains those behaviors clearly.

## Living documentation model

OpenSpec is the preferred way to describe product capabilities once they are
sharp enough to state in behavioral terms.

The intended layering is:

- direction documents explain long-lived project framing and sequencing
- capability backlog entries capture future work that is still being shaped
- OpenSpec specs define durable capability behavior
- OpenSpec changes capture concrete planned modifications to those capabilities

Until a dedicated GitHub project or issue taxonomy is set up, this document can
serve as the durable backlog index for future capability exploration.

## Current implementation focus

The current implementation focus stays on the mobile architecture.

That focus should still reinforce the broader platform story:

- capability language should be product-oriented, not module-oriented
- shared Kotlin should own business rules and typed feature state
- Android and iOS should keep native presentation ownership
- shared UI should remain optional and justified feature by feature
- realistic simulation is preferred over toy demo behavior

## Capability backlog

These items are intentionally sequenced from narrower mobile-facing behavior
toward broader platform behavior.

### Current exploration

- `nearby-vehicle-map`: show rider location and a refreshable map snapshot of
  nearby vehicles

### Near-term follow-ups

- `vehicle-list-discovery`: provide a non-map discovery surface over the same
  fleet snapshot
- `vehicle-detail-preview`: let a rider inspect a selected vehicle before
  acting on it
- `vehicle-reservation`: allow a rider to hold an available vehicle
- `reservation-expiry`: model countdown, expiry, and loss of a held vehicle
- `trip-start`: begin a trip from an eligible reserved vehicle
- `active-trip`: represent an in-progress trip with realistic state changes
- `trip-end`: end a trip under realistic completion rules
- `trip-history`: review completed trips and their outcomes

### Broader platform capabilities

- `fleet-availability`: simulate and reason about vehicle status changes
- `vehicle-state-simulation`: represent readiness, range, and vehicle
  condition changes over time
- `pricing`: calculate trip cost under realistic rules
- `driver-readiness`: represent account and eligibility requirements before a
  rider can take certain actions
- `incident-reporting`: capture problems that arise before or during a trip
- `operations-views`: expose platform-facing operational workflows in later
  surfaces beyond the mobile app

## Sequencing notes

The first capability should stay narrow enough to be explained clearly in docs
and enforced clearly in specs. That is why the current scope begins with
`nearby-vehicle-map` instead of the broader `vehicle-discovery` umbrella.

Clustering, rich vehicle details, and reservation behavior are explicitly
deferred until the basic map snapshot lifecycle is specified cleanly.
