# Quality and dependency maintenance

Status: slices 1–8 integrated. Slice 7 was committed and pushed as `9d25553`;
its [measured results](seventh-slice-validation.md) keep bridge upgrades separate
from direct-path parity. Slice 8 was committed and pushed as `815b16d` and consolidates the [existing watch](compatibility-watch.md);
[validation and hosted status](eighth-slice-validation.md) remain explicit.
Audit baseline: `7810841cf58196b4564ce78ce30d6ebb1f0db2f4`.

Slice 9's manual review profile and [upgrade packet](ninth-slice-review.md) are
implemented locally, with [paired validation and cleanup](ninth-slice-validation.md).
The candidate passed the local checks but still matches moderate build-tooling
advisories. Adoption is deferred; production pins and policy are unchanged.
This slice is uncommitted and has no hosted validation yet.

Mobi's maintenance workflow starts with reproducible pre-commit checks and uses
isolated evidence to assess Kotlin Toolchain upgrades. Upgrading the current iOS bridge and retiring it are separate decisions.
Bridge retirement is **deferred** pending native, clean-clone and release evidence.

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
