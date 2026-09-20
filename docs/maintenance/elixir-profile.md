# Dormant Elixir/Phoenix maintenance profile

Status: design only. No Elixir application, dependency, database, container or
schedule is added. Activation waits for a real backend capability under the
[platform direction](../reference/platform-direction.md). Mobile-only commands
must not check for or install Erlang, Elixir or PostgreSQL.

Use the [common lifecycle and evidence contract](workflow-design.md). The
adapter contributes stack-specific inventory, checks and owned resource types;
it does not import mobile tooling or product-specific architecture rules.

## Activation checklist

- [ ] A backend capability and context boundaries are specified using existing
  OpenSpec/ADR conventions; its source root is explicitly configured.
- [ ] Exact Elixir, OTP, Hex/Rebar and PostgreSQL versions are reviewed together
  and reproducibly bootstrapped outside the gate; compatibility is checked
  against their selected-version primary documentation.
- [ ] `mix.exs` and `mix.lock` are present; direct/transitive packages,
  checksums, Git/path dependencies and active Mix environments are inventoried.
- [ ] Analyzer versions and rule profiles are pinned; no inherited baselines,
  Sobelow fingerprints, vulnerability exceptions or context names are copied.
- [ ] The app can run tests with external side effects disabled, an owned local
  database and no production credentials.
- [ ] Base/candidate checks and negative architecture/security fixtures pass,
  including cached reruns and recovery after fixing a violation.
- [ ] Both `dev`/`test` checking and production release compilation are proven
  on the supported environment; mobile-only behavior remains independent.

## Proposed check contract

Commands below are future adapter actions, not a runnable Mobi backend recipe.
Resolve their exact flags against pinned versions during activation. Current
upstream documentation was consulted on 2026-09-19, but no versions in those
pages are being adopted here.

| Check | Proposed command/policy | Evidence and limit |
| --- | --- | --- |
| Format | `mix format --check-formatted` over configured sources/tests/config | `.formatter.exs`, plugins and input manifest captured; no autofix in hook |
| Application compilation | `MIX_ENV=test mix compile --force --warnings-as-errors`, plus needed dev checks | Capture full reference analysis from owned build output; do not trust stale successful compilation. [Mix compile](https://mix.hexdocs.pm/Mix.Tasks.Compile.html) treats project warnings separately from dependency warnings |
| Maintainability | `mix credo --strict` with reviewed `.credo.exs` | [Credo](https://credo.hexdocs.pm/overview.html) adds consistency/design feedback; explicit priorities, narrow justified suppressions, runtime measured |
| Security analysis | `mix sobelow --config --exit low` with version-checked flags | [Sobelow](https://sobelow.hexdocs.pm/readme.html) does not fail on findings by default; explicitly configure failing confidence threshold. No blanket skip generation |
| Architecture | Boundary compiler integrated into Mix; warnings-as-errors | Real contexts/adapters/repository/web composition, explicit exports and external app restrictions; test actual forbidden references |
| Vulnerabilities | Pinned `mix deps.audit` or another verified Hex auditor | [MixAudit](https://mix-audit.hexdocs.pm/Mix.Tasks.Deps.Audit.html) scans Mix dependencies; wrapper must prove advisory revision/freshness and failed-refresh behavior rather than trusting exit zero |
| Tests | `MIX_ENV=test mix test` with ExUnit; SQL Sandbox when Ecto exists | Unit and integration behavior, deterministic fixtures, owned databases, disabled outbound effects; assertion failures retain full evidence |
| Production package | `MIX_ENV=prod mix compile --warnings-as-errors`, then `mix release` when configured | Build in owned output with review-safe configuration; no server start, deploy, migration or production connection |
| Dialyzer | Evaluate after compiler/Credo/Boundary baseline | Measure added findings, PLT build cost/cache identity and noise before making mandatory; not already installed or a replacement for other checks |

The [Elixir compiler](https://mix.hexdocs.pm/Mix.Tasks.Compile.Elixir.html)
performs incremental verification; force a full owned-source compilation when
proving reference coverage and prohibit `--no-verification` in the gate. Measure
an incremental gate only after negative fixtures show stale results cannot
hide violations. Do not change a non-umbrella application's `build_path` blindly;
an isolated project copy already supplies independent `_build` and `deps`.
Any additional cache/environment overrides must be supported by the selected
Mix release and recorded.

### Boundary enforcement

[Boundary](https://boundary.hexdocs.pm/Boundary.html) can constrain cross-module
references; its [compiler](https://boundary.hexdocs.pm/Mix.Tasks.Compile.Boundary.html)
reports warnings that need warnings-as-errors for enforcement. Define rules
from the actual application, for example domain contexts must not call web
controllers, repository access belongs at declared adapters, and the app
composition root can wire both. Those are examples, not scaffolded namespaces.
Review external app checking: permissive defaults do not automatically forbid
all Phoenix/Plug/Ecto leakage. Explicitly classify protocol implementations
and Mix tasks where needed; document dynamic dispatch limitations.

For each forbidden edge, inject a compilable reference in a disposable fixture,
require a failing exit/diagnostic, rerun from cached output and require failure
again. Then remove it and require success. Also test allowed exports and public
context calls. Record emitted reference coverage, not just a grep result.
Do not carry imported warning fingerprints into a new codebase.

### PostgreSQL and side-effect isolation

Prefer a run-owned local PostgreSQL cluster bound to loopback with an owned
socket/port, or an explicitly designated disposable local instance with
least-privilege trial-database permissions. Create separate baseline/candidate
databases with random run suffixes and journal ownership before creation.
Verify server identity, local endpoint and database prefix against the ledger;
refuse production-like or externally supplied general-purpose connection URLs.
Record versions and configuration, but omit credentials from logs.

Migrate only the owned trial database. Use
[Ecto SQL Sandbox](https://ecto-sql.hexdocs.pm/Ecto.Adapters.SQL.Sandbox.html)
for transactional tests if Ecto is present, and manage child-process ownership
with allowances/supervision. Transaction rollback does not isolate database
creation or migrations, and shared sandbox mode constrains concurrent tests.
Database ownership is still needed outside the test transaction.

Disable email/SMS, payment, provider callbacks, job pollers and network effects
through explicit test adapters. No backend or fake production service should
be created merely to run this profile. If Req, Oban or Ecto is later introduced,
add usage-specific dependency probes to its normal ExUnit suite (for example
retry, scheduling or transaction behavior actually relied upon). Do not create
a duplicate mandatory dependency-test gate.

On interruption, stop owned app/DB processes; terminate only connections to
owned trial databases and drop only those databases after identity checks.
Never drop a database by a broad prefix alone. If ownership is uncertain, leave
it visible in `recover` for explicit resolution. Cleanup dry runs, retention,
concurrency and retry behavior follow the common core.

## Dependency and optional image rehearsal

Discover Hex direct and transitive versions from the effective lock; preserve
mix environment/dependency options. Read official package/runtime/framework
notes across the full interval and map them to real calls/configuration. Run
the exact baseline first, update only the selected set in a candidate copy,
diff the entire lock graph, then execute the same checks and release build.
Unavailable advisory data is `incomplete`, baseline failure is `inconclusive`,
and candidate-specific reproducible breakage is `incompatible`. Review and
adoption bind to source/patch/checksum identities just as in Kotlin.

If a backend image is later introduced, assess Elixir/OTP/distribution/libc/
architecture as one runtime tuple. Use a multi-stage builder and compatible
runtime libraries, then build and exercise the actual release image. Inspect
base-image digests, image/OS vulnerabilities, native NIF compatibility and
startup under non-production configuration. Version-tag discovery, digest
pinning, OS scanning and runtime validation are independent controls. Registry
credentials must remain scoped and redacted. Mobi's existing Android build
Dockerfile is not a Phoenix image or proof of this contract.
