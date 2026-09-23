# Quality and dependency maintenance

Status: audit and proposed design, 2026-09-19; slices 1–2 integrated with passing
hosted CI at `10319cd`. Slice 3 is implemented locally for review on 2026-09-22,
with the rehearsed iOS compatibility update adopted locally on 2026-09-23.
The full local staged gate passed, including 50 native tests, both debug builds
and owned-workspace cleanup. The broader dependency workflow remains a proposal. Audit baseline:
`7810841cf58196b4564ce78ce30d6ebb1f0db2f4`.

Mobi's next maintenance investment should make the existing pre-commit checks
reproducible and complete, then use isolated evidence to assess Kotlin Toolchain
upgrades. Upgrading the current iOS bridge and retiring it are separate decisions.
Bridge retirement is **deferred** pending native, clean-clone and release evidence.

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
The bridge, release defaults and schedules remain unchanged. The existing hosted workflow passed for slices 1–2; slice 3's exact
commit and native Intel execution remain unverified.
The proposal requires no private service, account, Codex installation or Go
application profile.
