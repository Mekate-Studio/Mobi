# Quality and dependency maintenance

Current baseline: [approved direct iOS development/test/unsigned integration](direct-default-integration.md)
is merged through PR #35. A separately authorized [physical bridge removal](bridge-removal.md)
is in progress. Signed delivery remains held and risk acceptance retains its original expiry.
Historical assessments and proposal receipts below describe their original snapshots;
they do not override the current direct default or validate this removal source.

## Historical maintenance slices

Status: slices 1–8 integrated. Slice 7 was committed and pushed as `9d25553`;
its [measured results](seventh-slice-validation.md) keep bridge upgrades separate
from direct-path parity. Slice 8 was committed and pushed as `815b16d` and consolidates the [existing watch](compatibility-watch.md);
[validation and hosted status](eighth-slice-validation.md) remain explicit.
Audit baseline: `7810841cf58196b4564ce78ce30d6ebb1f0db2f4`.

Slice 9's manual review profile and [upgrade packet](ninth-slice-review.md) are
implemented locally, with [paired validation and cleanup](ninth-slice-validation.md).
The candidate passed the local checks but still matches moderate build-tooling
advisories. That earlier candidate was deferred; its assessment did not change production pins or policy.
Its implementation is committed locally as `9f730ef`, with the full pre-commit gate passing; it has no hosted validation yet.

Slice 10 adds a manual [direct incremental/restoration profile](direct-roundtrip.md).
Its [validation record](tenth-slice-validation.md) distinguishes implementation
checks from passing local native incremental/restoration evidence and the
remaining untested gates. Its original receipt predates integration. The transition ADR remains proposed and
the retained bridge remains the default.

The [retained-bridge adoption review](bridge-adoption-review.md) records a passing
paired assessment for Kotlin 2.4.20 / Metro 1.4.5 / SKIE 0.10.15. The maintainer
approved the exact three-patch packet after its concrete review; real age
admission and fresh checks passed, and the pins, bounded ceilings and matching
maintenance baseline are applied. [Final local validation](bridge-adoption-validation.md)
passed 204 contracts and all four native pre-commit jobs. Its measurement receipt predates integration; direct-path retirement and Elixir activation remain independent.

Mobi's maintenance workflow starts with reproducible pre-commit checks and uses
isolated evidence to assess Kotlin Toolchain upgrades. Upgrading the current iOS bridge and retiring it are separate decisions.
Applicable removal validation and broader production/runtime gates are recorded separately in the current removal record.

The [Apple Silicon target assessment](apple-silicon-assessment.md) evaluates
Toolchain 0.12.2 with upstream-supported iOS architectures. It keeps the bridge
and has passing isolated input and mobile comparisons. The approved eight-file
migration is integrated in `ff7146e`. The separate
[minimum-OS workflow](mobile-support-policy.md) assesses configurable stable-major
support windows and architecture implications; its
[validation/adoption record](support-policy-validation.md) reports exact runtime
checks, support loss and outstanding hosted/device/release coverage. Historical
store cleanup remains blocked by its original host identity.

Read the documents in this order:

1. [Audit and coverage gaps](audit.md): inspected configuration, measured checks,
   assumptions and blockers.
2. [Kotlin compatibility matrix](kotlin-compatibility.md): current and candidate
   stacks, upstream corrections, three direct-path options and retirement gates.
3. [Workflow design](workflow-design.md): pre-commit contract, common core,
   independent adapters, evidence, failure states, adoption and cleanup.
4. [Staged implementation proposal](implementation-proposal.md): small slices
   and the first slice's acceptance checks.
5. [Dormant Elixir/Phoenix profile](elixir-profile.md): activation requirements
   without adding a backend or requiring its tools for mobile development.
6. [Dependency review playbook](dependency-review-playbook.md): an English,
   tool-independent review procedure suitable for a future optional AI skill.
7. [First slice validation](first-slice-validation.md): implemented static
   coverage, commit identity checks, verification and remaining limits.
8. [Second slice validation](second-slice-validation.md): reviewed tool/runtime
   lock, explicit bootstrap, offline checks, recovery and platform limits.
9. [Third slice validation](third-slice-validation.md): conservative selection,
   discovered host tests, isolated commit validation and native probe results.
10. [Xcode 27 iOS investigation](ios-xcode27-investigation.md): three diagnosed
    Swift dependency failures, the adopted compatibility update, isolated
    rehearsals and the full local staged-gate adoption receipt.
11. [Pinned inventory guide](dependency-inventory.md): explicit setup, inventory,
    evidence format, failure states and recovery.
12. [Fourth slice validation](fourth-slice-validation.md): measured extraction,
    tests and remaining graph/provider/platform gaps.

13. [Executor guide](executor-guide.md): fixture execution, ownership, recovery
    and cleanup commands.
14. [Fifth slice validation](fifth-slice-validation.md): executor contracts,
    public entry-point evidence and native/platform limits.
15. [Kotlin rehearsal guide](kotlin-rehearsal.md): reviewed preparation, input/mobile
    profiles, evidence, native ownership and recovery.
16. [Sixth slice validation](sixth-slice-validation.md): actual Toolchain comparison,
    native results, failures found and remaining assessment gaps.
17. [Mobile support workflow](mobile-support-policy.md): stable-major policy,
    architecture impact review, OS-only rehearsal and configuration for other projects.
18. [Support-policy validation](support-policy-validation.md): approved Toolchain
    adoption, paired mobile evidence, explicit OS minimums and cleanup.
19. [Compatibility runner](compatibility-runner.md): separate bridge compile/link,
    full mobile and direct-path assessments, with conservative capability receipts.
20. [Seventh slice validation](seventh-slice-validation.md): passing paired bridge
    and direct-facade jobs, retained failures, native tests, cleanup and evidence gaps.

21. [Compatibility watch](compatibility-watch.md): bounded release discovery, semantic deltas, existing hosted caller and recovery.
22. [Eighth slice validation](eighth-slice-validation.md): local watch evidence and separate integration/hosted results.
23. [Ninth slice upgrade review](ninth-slice-review.md): exact proposed patches,
    complete release interval, graph/artifact comparison, advisory triage and OS assessment.
24. [Ninth slice validation](ninth-slice-validation.md): paired native checks,
    contract evidence, retained failures, cleanup and remaining gates.
25. [Direct round-trip guide](direct-roundtrip.md): bounded incremental and exact
    bridge-restoration checks with existing executor recovery.
26. [Tenth slice validation](tenth-slice-validation.md): source-bound stage evidence
    and explicit remaining default/retirement gates.

[Audit evidence](evidence/2026-09-19.json) preserves sanitized probe results,
input identities and upstream source hashes. It is an audit record, not a
dependency adoption receipt or a complete resolved dependency inventory.

The design follows [platform direction](../reference/platform-direction.md):
mobile remains the current slice of a public car-sharing platform proof of
concept. [ADRs 0001–0006](../adr/README.md) remain accepted. No new architecture
decision is implied by these proposals. A concrete implementation should use
the existing OpenSpec change conventions; a change to iOS build ownership or
typed interop needs a new ADR revisiting ADRs 0003 and 0006.

The original audit changed documentation only. The implementation slices add
static coverage, pinned quality tools and selected native commit checks. The
separately approved Swift compatibility update changes three dependency pins.
The bridge, release defaults and schedules remain unchanged. The existing
hosted workflow passed for slice 6's exact commit. Linux execution remains unverified. Intel iOS simulators
are excluded by the adopted support policy.
The proposal requires no private service, account, Codex installation or Go
application profile.

The [bridge-retirement path](bridge-retirement-path.md) explains the independent workflow track, remaining evidence and first assessment against the adopted tuple.

The [adopted-tuple direct assessment](direct-current-assessment.md) passes the
bounded Metro 1.4.5 simulator round trip with exact restored-bridge consumers and
cleanup. The [direct resolution assessment](direct-resolution-assessment.md)
captures module/target graphs and fresh named Maven advisories. The
[selected build-input assessment](direct-build-input-assessment.md) separately
proves compiler plugin paths/hashes and required delegated Android scopes.
Its fresh review finds 17 matches in shared build tooling; broader attribution,
security review and retirement remain deferred.

The [direct resolution guide](direct-resolution-review.md) documents the manual graph-only profile and exact-input advisory command.

The [build-input proof guide](direct-build-input-proof.md) documents the manual
paired profile, explicit uncollected scopes and failed-run evidence handling.

The [compiler plugin attribution follow-up](compiler-plugin-attribution.md) joins
independent resolver artifacts to actual compiler fingerprints and extends the
[advisory triage](direct-advisory-triage.md) without authorizing adoption.

The [current attribution assessment](compiler-plugin-assessment.md) records
passing joins, fresh provider evidence and remaining retirement gates.

- [Toolchain SwiftPM scope and workflow tracking](toolchain-swiftpm-assessment.md)

- [Upstream Toolchain remediation rehearsal](upstream-toolchain-remediation.md)

- [Toolchain 0.13.0 build and advisory assessment](upstream-toolchain-assessment.md)

- [Bundled-file identity follow-up and restored advisory finding](bundled-input-assessment.md)

- [Retained-bridge adoption gates and isolated command guide](toolchain-adoption-gates.md)

- [Toolchain 0.13.0 native, runtime, packaging and plugin adoption assessment](toolchain-adoption-assessment.md)

- [Advisory condition probes, mitigation review and remaining closure checks](advisory-mitigation-review.md)

- [Effective Jetifier conditions, owner-release discovery and remaining security gates](jetifier-condition-assessment.md)

- [Toolchain security decision packet, refreshed fix leads and adoption requirements](toolchain-security-decision.md)

- [Adoption direction, exact draft and bounded residual-risk proposal](toolchain-adoption-risk-review.md)

- [Approved direct iOS default integration](direct-default-integration.md)
