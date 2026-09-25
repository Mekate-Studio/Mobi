# Pinned dependency inventory

Slice 4 adds an inventory and evidence evaluator behind the existing `just deps`
command. It does not look up available updates by default, scan vulnerabilities,
apply dependency changes, or prove compatibility. Missing evidence remains visible.
See [validation](fourth-slice-validation.md) for measured coverage and platform limits.

## Setup and local use

Use the normal [quality-tool setup](second-slice-validation.md) first. Mobi's
front door reuses its verified Ruby runtime. Install the separate maintenance
tools explicitly:

```bash
./scripts/maintenance/install_tools.sh
./scripts/dev/dependency_updates.sh verify
just deps > /tmp/mobi-inventory.json
./scripts/ci/run_job.sh quality-contracts
```

`maintenance-tools.json` pins Node 24.21.0, its bundled npm 11.19.0 and Renovate
44.93.5. Official Node archives have SHA-256 checksums; the complete npm lock
has integrity hashes and its own reviewed digest. Setup uses `npm ci
--ignore-scripts --no-audit --no-fund` in an owned installation with isolated npm
configuration. Subsequent verification hashes the full installation, including
executables, modes and symlink targets. Setup never changes application pins.
The ignored `.maintenance/tools/` directory contains only this local tool store.
No ambient Node/Renovate, npx download, Docker service or GitHub token is required.

Discovery verifies installed tools, copies tracked and nonignored source inputs
into a temporary owned directory, and runs Renovate's native local
`dryRun=extract`. It disables scripts, plugins and unsafe execution, passes an
explicit environment without caller credentials, bounds execution, and checks
source content/modes/file sets before returning. Process groups and temporary
copies are cleaned on ordinary failure, timeout and handled interruption.
This is isolation by ownership and configuration, not an operating-system sandbox
against hostile repository code or concurrent malicious local processes.

Only bundled `config:` and `:` presets are accepted in repository configuration.
They are resolved from the pinned installation and captured with the shallow
repository config, merged preset config, enforced execution settings and hashes.
External presets require a separately reviewed immutable-source adapter.
Optional RE2 cannot load with lifecycle scripts disabled; the actual native probe
uses Renovate's JavaScript-regex fallback and records its warning. GitHub-token
warnings also remain visible; extraction success is not proof that authenticated
release lookup is available.

The JSON includes source/tool/policy identities, native manager records,
supplemental components, module coverage, locked packages and explicit missing
resolved graphs. Keep reports in `/tmp` or the ignored `.maintenance` directory.
Redirecting into a new nonignored repository file changes discovery inputs and
will fail the drift guard. Raw extraction logs are ephemeral; the report keeps
their digest and warning summaries, not credentials or machine-specific log paths.
An inventory result is `inventory_recorded`, with `release_discovery=not_requested`
and `vulnerability_status=incomplete`. Exit zero means inventory creation worked.

## Evidence evaluation

```bash
./scripts/dev/dependency_updates.sh evaluate \
  /tmp/mobi-inventory.json /tmp/mobi-evidence.json > /tmp/mobi-assessment.json
```

This command validates supplied evidence; this slice does not acquire release
catalogs or advisory databases. Use the exact inventory ID, component ID and
resolved input ID/digest from discovery. The minimal packet shape is:

```json
{
  "schema": 1,
  "inventory_id": "<inventory.id>",
  "releases": [{
    "component_id": "<components[n].id>",
    "provider": {
      "status": "ok",
      "complete": true,
      "url": "https://primary-provider.example/releases",
      "retrieved_at": "<UTC ISO-8601 timestamp>",
      "response_sha256": "<SHA-256 of preserved provider response>"
    },
    "versions": [{
      "version": "1.1.1",
      "published_at": "<verified UTC publication timestamp>",
      "prerelease": false
    }]
  }],
  "advisories": [{
    "input_id": "<resolved_inputs[n].id>",
    "input_sha256": "<resolved_inputs[n].sha256>",
    "provider": {
      "status": "ok",
      "complete": true,
      "url": "https://primary-provider.example/advisories",
      "retrieved_at": "<UTC ISO-8601 timestamp>",
      "response_sha256": "<SHA-256 of preserved provider response>"
    },
    "findings": [{"id": "<advisory ID>", "severity": "high"}]
  }]
}
```

Supply a receipt for every recorded resolved input. Preserve actual response
bytes and query details alongside the packet for review. A syntactically valid
URL/digest or `complete=true` assertion is **not authenticated provider evidence**:
the evaluator does not fetch or independently verify that response. It validates
the contract, timestamps and inventory bindings. Provider acquisition, response
verification and target graph completion remain later work.

`maintenance-policy.json` requires stable releases to be at least seven days old,
retains major updates for separate review, and enforces captured simple `<version`
ceilings. Every candidate and exclusion remains visible. Non-SemVer versions,
unknown publication dates, incomplete providers and unsupported ceilings are
incomplete; older/equal versions are not upgrade candidates. Provider metadata
expires after 24 hours. High/critical advisories block; unknown severity requires
triage, and lower findings remain in the report.

The current Kotlin adapter applies ceilings from explicit `matchPackageNames`
rules in `renovate.json`. Conditional or newly unsupported ceiling rules fail
inventory creation rather than silently dropping policy. The fully resolved
preset configuration is retained for review, not treated as a universal
reimplementation of Renovate's candidate-selection engine. Additional bundled
preset constraints therefore create a required `policy:resolved-preset-rules`
gap until native candidate-policy evaluation is integrated.

Exit codes: `0` is successful inventory/verification or `checks_passed` for the
**named** evaluation scope; `2` is `incomplete` or `blocked`; `1` is failed input,
installation, extraction or identity validation. Empty release evidence and
missing advisory receipts cannot pass. `checks_passed` never authorizes adoption,
claims all dependencies have updates checked, or substitutes for release-note
assessment, native rehearsal, pre-commit review or release packaging.

## Recovery and cleanup

- Missing tools: run explicit setup. Discovery never installs them for you.
- Receipt mismatch: inspect the store and lock changes, then run
  `./scripts/maintenance/install_tools.sh --repair`. Repair deletes only the
  selected directory with a matching ownership marker; symlinks and unowned
  directories are refused. An interrupted installer deletes its incomplete slot.
- Lock/pin mismatch: review and regenerate the exact npm lock and manifest
  hashes together. Do not edit an installation receipt to bypass verification.
- Source/config/policy drift: keep the user's edits and rerun discovery; never
  stash, restore or overwrite caller files to manufacture matching evidence.
- Provider failure or stale evidence: reacquire the exact missing evidence and
  reevaluate. Do not replace unavailable responses with empty success arrays.
- Forced process termination or host crash can prevent cleanup handlers. Inspect
  a leftover `mobi-inventory-*` or `mobi-maintenance-install-*` directory and its
  processes before removing that exact owned directory. Do not glob-delete
  sibling repositories, shared caches or unrelated temporary files.

The common Ruby core and policy have no Android/Xcode/Erlang/PostgreSQL dependency.
Kotlin supplementation is a separate adapter; Elixir reports `not_applicable`
until a `mix.exs` exists, then `incomplete` pending explicit activation. The dormant
profile lists format, compile warnings, Credo, Sobelow, Boundary, vulnerability
checks, ExUnit, isolated PostgreSQL and dependency rehearsal. See the
[Elixir profile](elixir-profile.md); discovery does not provision a backend.

## Primary implementation references

The pinned behavior was checked against Renovate's [local platform](https://docs.renovatebot.com/modules/platform/local/),
[Gradle manager](https://docs.renovatebot.com/modules/manager/gradle/),
[Swift manager](https://docs.renovatebot.com/modules/manager/swift/),
[self-hosted configuration](https://docs.renovatebot.com/self-hosted-configuration/)
and [environment handling](https://docs.renovatebot.com/environment-variable-handling/).
Tool sources are [Node 24.21.0](https://nodejs.org/en/blog/release/v24.21.0),
[official archive checksums](https://nodejs.org/dist/v24.21.0/SHASUMS256.txt),
[Renovate 44.93.5](https://github.com/renovatebot/renovate/releases/tag/44.93.5)
and its [npm metadata](https://registry.npmjs.org/renovate/44.93.5).
The [OSV API](https://google.github.io/osv.dev/api/) is a possible later acquisition
source, not an implemented scanner in this slice.
