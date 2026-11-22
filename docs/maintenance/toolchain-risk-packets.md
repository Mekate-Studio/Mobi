# Toolchain 0.14.1 manual risk packets

The 0.14.1 adoption draft stays separate from this reviewer. Main still selects
0.13.0. The October decision is expired and covers 0.13.0 only; it cannot approve
0.14.1. The earlier 0.14.1 age exception authorizes isolated qualification only.

The [first replay receipt](evidence/2026-11-22-toolchain-0141-risk-replay.json)
is **blocked**: no new risk decision or qualification-receipt signoff exists.
It verifies 851 queries across the retained published/module and delegated
captures. Their complete provider comparison contains 75 distinct IDs; 74
match candidate queries (33 High, three Critical, 37 Moderate, one Low).
The baseline-only High remains in the provider comparison. All 36 candidate
High/Critical IDs have recorded whole-file identities. This is not remediation,
complete attribution, or a claim that every query corresponds to a loaded file.

## Review interface

The existing command without arguments preserves its 0.13.0 producer replay.
The explicit packet route supports **0.14.1 only**, from the exact candidate
checkout after the reviewer is available there:

```bash
./scripts/dev/dependency_updates.sh review-toolchain-risk \
  --packet .maintenance/risk-review/packet.json

# Only after a separately recorded, explicit maintainer decision:
./scripts/dev/dependency_updates.sh review-toolchain-risk \
  --packet .maintenance/risk-review/packet.json \
  --decision .maintenance/risk-review/decision.json
```

Exit 0 means accepted risk for the named manual operations; exit 2 means blocked;
exit 1 means malformed, mismatched or unsupported evidence. The packet route
refuses a 0.13.0 checkout. It does not select a version or grant adoption.

## Packet and trust boundary

The packet is a manually assembled index of retained captures. Keep it and the
large raw records in ignored storage. Each referenced file uses
`{"path":"relative-name.json","sha256":"<exact file digest>"}`. Paths stay
inside the packet directory; symlinks, changed bytes and parent traversal refuse.
The following fields define schema 1:

| Field | Bound evidence |
| --- | --- |
| `toolchain` | Exactly `0.14.1`; the actual Unix wrapper must select it. |
| `source_binding_sha256` | `Maintenance.digest(Maintenance::Source.new(root).files)`, including file modes and all tracked/nonignored inputs. |
| `applied_patch` | File reference to the exact reviewed adoption diff. |
| `captures.distribution` | `inputs` and `advisories` file references from the published distribution review, including retained module queries. |
| `captures.delegated` | `inputs` and `advisories` file references from the observed Android Debug graph review. |
| `attribution` | Candidate distribution attribution JSON, matching the selected version/distribution digest. |
| `delegated_graphs` | Candidate `delegated-graphs.json` with captured artifact identities. |
| `qualification_receipts` | Nonempty array of JSON file references for explicit human review. |
| `coverage_gaps` | Explicit gap IDs, acknowledged exactly by any decision. |
| `release_receipt` | Official tag response with URL, status, retrieval time, raw body and response SHA-256. |

The join recomputes the complete baseline/candidate query union from both input
captures, checks their input digests and reuses `AdvisoryReview.verify!` for
batch cardinality, pagination, raw response bindings, record completeness and
24-hour freshness. It maps candidate findings to recorded distribution and
resolved delegated Maven file identities. Baseline-only matches remain visible
in `providers`, outside the candidate grant set.

**Design decision for review:** this replays retained measurements; it does not
re-execute an input producer, download/reinspect every JAR, verify a reproducible
upstream build, or automatically certify native compatibility. Hashes prevent
silent changes after approval; they do not establish that an attribution claim
was correct. The maintainer must inspect the bound qualification/attribution
records and set `qualification_receipts_reviewed: true` in a new decision only
when satisfied. The report states that manual basis explicitly. Add the exact
hosted adoption checks to the qualification records before that review; the
first blocked replay uses the earlier qualification receipt only.

## Decision and remaining gates

A new decision retains the existing rationale, controls, exact finding/severity
set, High/Critical artifact identities, named operations and maximum 30-day
window. It additionally pins `review_packet_sha256`, acknowledges the exact
`coverage_gaps`, and records the qualification review. A changed packet,
source, provider response, artifact, finding or severity requires a new review.
Store decision files in ignored storage while evaluating the exact source;
adding a nonignored decision/receipt changes that source binding and requires
rebinding before approval.

Before November 26 at 17:46:59 UTC, an explicit new age exception must name
0.14.1, the real publication time, this decision's start and
`scope: scoped_manual_risk_use`. A qualification-only exception is insufficient.
This PR records no approval, expiry extension or new age exception.

These minimum gaps must remain acknowledged even when a scoped grant passes:

- Unassigned/ambiguous files and incomplete shaded/native attribution.
- Configurations outside the observed Android Debug main scope.
- The unsupported candidate Gradle transform observer; zero counters do not prove no transforms.
- Physical devices, exact OS floors and credentialed signed delivery.

Unsigned/native/hosted qualification, actual version adoption and IOS-10
retirement remain separate decisions. The [adoption draft](https://github.com/Mekate-Studio/Mobi/pull/134)
stays unmerged pending the new exact risk/age decision and remaining gates.

## Update and simplification check

On the next Toolchain review, re-evaluate this packet adapter against supported
Toolchain dependency/attribution output. Replace its one-off capture envelope
handling when a maintained producer covers both scopes with equivalent file
identity, query completeness and source bindings. Keep the existing provider
verifier and refusal contracts; remove obsolete capture parsing only after the
replacement passes those checks. Better metadata must not silently erase
unassigned files, outside-scope configurations or unsupported observations.
