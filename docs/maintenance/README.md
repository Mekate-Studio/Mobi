# Quality and dependency maintenance

Status: audit and proposed design, 2026-09-19; static-gate and pinned-tool slices
implemented and locally validated on 2026-09-20. The broader dependency workflow remains a
proposal. Audit baseline: `7810841cf58196b4564ce78ce30d6ebb1f0db2f4`.

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
static coverage, commit guards and pinned quality tools. They do not upgrade
mobile dependencies, remove the bridge, change release defaults, or create
schedules. Slice 2 updates only the existing hosted quality job's setup/cache and
contract-test steps; a hosted run remains unexecuted.
The proposal requires no private service, account, Codex installation or Go
application profile.
