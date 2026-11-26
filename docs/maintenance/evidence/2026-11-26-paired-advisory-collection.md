# Paired advisory collection — November 26, 2026

The production security stage now collects both phases' advisory query batches,
fetches their unique finding records once, and then requests archive checksum
leads. The unchanged overall request cap is 128. Receipts expose advisory
coverage separately while keeping broader provenance gaps blocking.

## Live stage check

The check used the digest-bound native graph/provenance inputs retained by the
[earlier automated comparison](2026-11-26-automated-release-assessment.md).
It executed the production security-stage entry point with fresh providers.
It did not repeat native builds, collect a new release interval or establish
qualification for the current PR source. This is provider-stage evidence;
the overall assessment prerequisite remains open.

| Phase | Reported queries | Matched finding records | Advisory state | Broader provider state |
| --- | ---: | ---: | --- | --- |
| Baseline | 630 | 64 | Complete | Incomplete |
| Candidate | 630 | 64 | Complete | Incomplete |

The reported sets include module graphs, observed delegated configurations,
embedded claims and locked Swift commits. Complete advisory requests for these
sets do not establish complete selected classpaths or runtime reachability.

The check ran at 18:18:54–18:19:35 UTC, with a 600-second deadline and a
96-request cap, conservatively reserving 32 of the production total for upstream
collection. Eight distinct query-batch requests and 64 unique finding-record
requests completed before checksum work. Existing payload caching reused shared
batches. The full stage reached 96 requests; checksum bounds, unavailable
checksum responses and byte attribution remained explicit gaps. Neither the
global cap nor provider freshness policy was relaxed.

The original run had retained only 38 candidate finding records after its
baseline-first provider allocation. Both phases now retain all 64 matched
records for the captured query sets. One-sided observations from an incomplete
provider pair still cannot establish introduced or resolved findings; the
existing conservative delta guard remains in force.

## Bindings and limits

- Merged starting point: `53f494a3590fa6ecf5d069557fbea5dcd23a7a7c` (PR #137).
- Native input packet: `d663b664de12519f22638e01ff80865d409aa089d4cf1d044edaa04dc3796381`.
- Native source digest: `418196d3fd1f8f63427bf27069970a9bc7c0ac74f73c0607c508d204836a845c`.
- Tested implementation snapshot: `e202336391ac44af8dcc666164ddfd959ac4ef1ce608688e7675f90f67da31d9`.
- Stage proof: `6cd23e19b28758fdfecf63f3f936b054508bcc9d1a69bc437526886c10ac8802`.

The proof digest, tested source/index identity and all retained provider body
digests were verified before adding this dated record. Original native evidence
was checked and copied into a separate ignored store; prior packets were not
modified. Raw inputs, provider bodies and receipts stay in ignored maintenance
storage. This stage allocated no native workers or build workspaces.

All 23 contract suites passed, including 34 assessment cases and four archive
scanner cases. New contracts exercise checksum-budget exhaustion after both
advisory phases, shared-ID fetch/failure behavior, phase-specific query failure
and a request cap that prevents required finding records. Static quality and
strict OpenSpec validation pass; normal-hook and hosted results are recorded on
the implementation PR.

Source-format analysis, selected owner/classpath provenance, non-JAR artifacts,
uncollected delegated configurations and catalog limits remain separate work.
No dependency update, risk exception, workaround retirement or manual release
assessment is authorized by this result.
