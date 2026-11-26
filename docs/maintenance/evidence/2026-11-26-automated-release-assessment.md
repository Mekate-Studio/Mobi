# Automated assessment qualification — November 26, 2026

The local pipeline completed an automated Metro 1.5.0 → 1.6.0 comparison.
Its decision is **incomplete**. Native qualification passed; unsupported source
formats, incomplete selected-input provenance and provider bounds prevent an
adoption recommendation. The automation prerequisite and manual-assessment gate
remain open. No dependency adoption or policy exception is authorized.

## Bound evidence

The assessed working snapshot was based on main
`532acda44241d4084967385679fae152ff45702d`, with source digest
`418196d3fd1f8f63427bf27069970a9bc7c0ac74f73c0607c508d204836a845c`.
It includes the assessment implementation before the partial-comparison guard
described below and this dated record. It is historical implementation evidence,
not an adoption packet for the final PR source.

- Assessment: `0146e18d1f3697c6223d043d6056e89f`, started 15:14:32 UTC.
- Native run: `8e9fb2bf00b072dcb5b30a43a2a53b74`, 15:15:36–15:51:01 UTC.
- Packet: `d663b664de12519f22638e01ff80865d409aa089d4cf1d044edaa04dc3796381`.
- The verifier returned `packet_verified`, with assessment state `incomplete`,
  before source/index edits. Integrity verification grants no adoption authority.
- Raw packet, receipts and logs remain under ignored `.maintenance/` storage.

| Stage | Actual result |
| --- | --- |
| Official interval | Complete exact endpoint diff of 731 changed files; temporary Git transport removed. |
| App impact | Incomplete: unsupported source formats and opaque binaries remain explicit. |
| Baseline | Static quality, all 23 contract suites, 94 Android/shared tests, iOS PullRequest plan and both Debug builds passed. |
| Candidate | The same prerequisites and native jobs passed in its own copy; 94 Android/shared tests passed. |
| Security | Fresh queries attempted for 630 inputs per phase; provider/provenance coverage remains incomplete. |
| Cleanup | Both successful phase workspaces released; final recovery/cleanup returned `cleaned`. |
| Evidence export | Complete, 113,442,848 bytes, excluding disposable workspaces and caches. |
| Decision | Incomplete; adoption, publication and workaround retirement remain unauthorized. |

The run used the already reviewed Java 25 build, an installed Android SDK copied
per phase, and the explicitly selected supported Google Maven Central endpoint.
It establishes development qualification on this host. Device/exact-OS-floor,
restoration, Shared Home UI and signed delivery acceptance remain separate.

## Cost and isolation

The native comparison took 35 minutes 25 seconds, within the unchanged
45-minute assessment deadline. Recorded commands took 1,037.41 seconds in the
baseline and 973.24 seconds in the candidate. The shared test/Debug Swift package
checkout directory is phase-owned; their DerivedData remains separate. Neither
Debug log repeated package checkout operations. Baseline cleanup restored about
16 GiB free before the candidate phase, which passed the 14-GiB preflight.

The run reached the 128-request provider cap. Increasing that cap is not a
substitute for selecting owners and allocating provider work deliberately.
Archive inspection reached its 768-JAR bound. Other downloaded artifact kinds,
unassigned metadata, delegated configurations and unsupported transform/AGP
conditions remain coverage gaps. Embedded identities and published checksum
leads do not establish selected classpath or shaded-code provenance.

## Partial-comparison guard

The full run exposed a reporting defect: one-sided findings in incomplete
provider receipts were labelled as resolved. The implementation now retains
those observations without claiming introduction or resolution. A regression
contract covers either incomplete side and the complete-pair case.

The corrected calculation was replayed offline against the two digest-bound
receipts from the real run, with zero provider requests and no freshness renewal.
It reports 38 retained IDs, 26 unconfirmed baseline-only observations, and zero
confirmed introduced/resolved IDs. The original unguarded delta is superseded.
Replay digest:
`99f4ca49bca9b3d7f963c9ff7d4199039356f3d8a7eb5ab827c7f83bd3dc7633`.
The replay and raw receipts remain ignored; the assessment regression suite now
has 30 cases plus four archive-scanner cases.

## Next automation slices

1. Extend supported source analysis in `scripts/maintenance/lib/release_assessment.rb`
   for protocol schemas, service registration, API dumps and JavaScript. Establish
   source/artifact roles before excluding fixture binaries from relevance.
2. Establish missing selected owner/classpath provenance through
   `lib/build_inputs.rb`, `assessment_provenance.py` and
   `lib/assessment_security.rb`. Allocate provider requests across both phases
   before optional checksum leads; retain explicit bounds and incomplete states.
3. Improve bounded catalog coverage and official prerelease metadata handling.
   Kotlin tag truncation/unreadable entries and Toolchain development versions
   lacking official dates/notes remain visible, not inferred away.
4. Surface the existing adopted-tuple/Renovate-ceiling inconsistency for an
   explicit policy decision. This implementation changes no ceiling.

These are automation work, not permission for manual release investigation.
Complete local assessment, exact-packet approval, one adoption PR and a separate
merge decision remain the required adoption flow.
