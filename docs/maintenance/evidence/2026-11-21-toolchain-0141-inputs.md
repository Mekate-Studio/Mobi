# Toolchain 0.14.1 inputs and module advisories — 2026-11-21

**Input qualification passed; module findings still require triage.** The app
remains on Toolchain 0.13.0. The [compact receipt](2026-11-21-toolchain-0141-inputs.json)
binds actual source/implementation identities, output and provider hashes,
coverage, failure controls and cleanup. Raw outputs, graphs and artifact
inventories remain in ignored evidence storage.

## Scope and authorization

This follows merged [#125](https://github.com/Mekate-Studio/Mobi/pull/125),
source `4a1b9cc1a7cc6dad73222b4ad3d8bf0483726a1a`, and uses the
[0.14.1-only qualification exception](2026-11-21-toolchain-0141-qualification.md)
confirmed by the maintainer on November 21. It covers the reviewed distribution
`39fb5f7e0bd5148a02f5519e88d78752fb04e719ddb086258ff57e94d83c0fcb`.
Selection remains `experimental`, `age_blocked`, and
`adoption_authorized: false`; normal eligibility remains November 26 at
17:46:59 UTC. No adoption or dependency-risk decision is inferred.

The existing Ruby `KotlinRehearsal` adapter runs `inputs` with
`candidate: '0.14.1'`, `target_policy: 'current'`, `experimental: true`, through
the existing baseline-first executor. The CLI shortcut does not expose that
experimental argument. For normal age-eligible execution, its existing command
is `./scripts/dev/dependency_updates.sh rehearse-kotlin 0.14.1 inputs current`.
The normal age refusal is unchanged.

`current` preserves every target declaration. An initial construction using the
historical `apple-silicon` migration recipe refused the expanded library-module
set before execution allocation. That guard remains intact. This qualification
does not migrate targets: actual output was separately checked against every
declared module's platform/main/test/compile/runtime coverage, with no `iosX64`
roots. Kotlin/exporter 2.5.0-RC, Metro 1.5.0, native packages and platform floors
stay fixed.

## Reader cost and actual output

Raw 0.14.1 commands were first inspected in an owned source copy using the
existing CLI/source-guard methods. Inspection confirmed the existing format;
normal 0.14.1 reader admission still refused before the change. Extended
contracts failed for the unsupported version, then passed after adding **one
exact allowlist entry**. No parsing branch, fallback, runner or adapter is added.

The paired run `55b1ac8a0509079fd21c419958c665d3` then passed both phases:

| Measured scope | 0.13.0 baseline | 0.14.1 candidate |
| --- | --- | --- |
| Actual version/settings/dependencies commands | All exit 0 | All exit 0 |
| Declared modules | Nine | Same nine |
| Main/test compile/runtime graph roots | 104 | 104 |
| Normalized named Maven queries | 359 | Same 359 queries |
| Effective Kotlin and Metro versions | 2.5.0-RC / 1.5.0 | Same |
| Declared target-scope coverage | Passed | Passed |

The graphs are **not identical**. Candidate Android main/test runtime views omit
the printed `androidx.lifecycle:lifecycle-livedata:2.11.0 (c)` constraint. The
reader preserves that difference and does not reconstruct omitted nodes.
Constraint labels are excluded from advisory queries, whose sets match exactly.
This is not proof of binary or complete resolution equivalence.

Settings have 44 changed rows across variants, comprising two newly emitted
defaults: disabled `android.desugaring` in six modules, with configured library
`com.android.tools:desugar_jdk_libs:2.1.5`, and
`publishing.mavenCentral.notifyKlibsIo: false` in all nine modules. These defaults
do not enable desugaring or publication in Mobi. This matches the previously
observed 0.14.0 output differences.

All 29 Kotlin rehearsal tests and all 21 existing contract suites passed.
Coverage checks, requested/selected versions, graph edges, repeated branches,
unresolved-node/unknown-metadata refusals and unknown-version refusals remain.
Source verification and raw-output replay passed before disposable work/cache
cleanup. The existing recovery API verified quiescence and retained result,
control records and raw logs while removing only the two owned workspaces.

## Fresh module advisory evidence

One fresh OSV snapshot covers the identical baseline/candidate query sets:
359 queries, four complete HTTP 200 batches, 359 response rows, no pagination,
and both full matched records. Retrieval started **2026-11-21T17:52:20Z**.
It is one shared lookup, not two independent provider observations.

The measured matches remain `io.opentelemetry:opentelemetry-api:1.41.0`:
[GHSA-ccrj-gw8r-854m](https://osv.dev/vulnerability/GHSA-ccrj-gw8r-854m) and
[GHSA-rcgg-9c38-7xpx](https://osv.dev/vulnerability/GHSA-rcgg-9c38-7xpx), both
Moderate. The receipt remains `triage_required`. The
[exporter owner review](2026-11-13-exporter-opentelemetry-review.md) remains
relevant; this lookup neither remediates those bytes nor extends an acceptance.

This is public named module-Maven coverage only. Toolchain distribution,
delegated Gradle/buildscript/transform owners, shaded code, Native internals,
Swift/Ruby/npm packages and artifact attribution remain separate. No complete
dependency-surface or security-clearance claim follows.

## Simplification and remaining work

The reviewed `show settings --help` and `show dependencies --help` expose no
machine-readable format switch. On Toolchain updates, check official command
documentation/source and actual help for a supported structured replacement.
Retire pretty-output parsing only after that replacement covers every declared
module/target/test scope, preserves graph semantics, and passes malformed and
incomplete-output controls. Review narrowing old version cases when retained
replay/recovery no longer needs them; full-revision replay preserves old tools.

Native evidence from [#124](https://github.com/Mekate-Studio/Mobi/pull/124) stays
version/source bound. This input run does not repeat candidate native, Release,
resource-invalidation, relocated-delivery, retained-JDK-cache or signed/device
checks. The PR's normal local gate and required hosted checks validate the
reader integration with the adopted app tuple; their completion is recorded in
the final PR review comment. All active interop and warning follow-ups remain.
