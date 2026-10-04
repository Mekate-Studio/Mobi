# Compiler plugin attribution assessment

Date: 2026-10-03. Decision: **selected compiler file attribution passes;
advisory triage and bridge retirement remain open**. No dependency adoption,
production builder/default change, commit or push was made.

Final resolver run `4fe1d2f29b3ac1c5e1b0135fac5e6a7f` binds the original paired
compiler run `9c17d97f1070e64cbe7dad16149610da` and its source snapshot
`d53589373d8177e04b93f91899162e4e146b721076388884aa5b2b38331e07ff`.
The new resolver source snapshot is
`c7690024d37028d853fa7a88bc6631edd597daad07716e1dce6c2cae32a42957`, at
HEAD `ba8270fabed862ae52a09e918e9803390d0fd8cb`. These are captured working
snapshots, not clean-commit or hosted-CI proof. Fresh resolution reuses retained
successful compiler producers; compilation was not rerun in this slice.

Both independent Gradle 9.6.1/JVM runtime resolver phases pass. Every one of the
37 retained compiler invocations in each original phase has the exact resolver
artifact set configured for its module. Both measured plugin files match a
unique selected component and variant by bytes and SHA-256:

| Selected component | Bytes | SHA-256 |
| --- | ---: | --- |
| `dev.zacsweers.metro:compiler:1.4.5` | 5,966,028 | `e94246f0f3af1f7e8b34d4238f5c95187abf69cb940bf96d239d4a731ebb824e` |
| `org.jetbrains.kotlin:kotlin-compose-compiler-plugin-embeddable:2.4.10` | 949,238 | `07edff96c6196c5354caa275b748616794cc8883af02e380d091d221f02bdc80` |

Each root's observed runtime graph contains its one selected artifact. There
are no extra retained transitive artifacts or excluded compiler artifacts in
these resolutions. This does not inventory classes or dependencies embedded
inside those JARs. Coordinates come from resolver component identities;
compiler/cache filenames did not establish them. Independent resolver success
alone would not meet the join checks.

Fresh OSV review covers 578 exact Maven pairs in six successful batches and
retrieves 17 full finding records. Neither new plugin query matches an advisory.
The 17 earlier delegated findings remain `triage_required`; see the
[owner/exposure/remediation review](direct-advisory-triage.md). Provider transport
completeness is not a clean dependency surface or adoption authorization.

Caller source bytes/modes, HEAD and index were verified unchanged by execution;
a separate whole-source comparison passed before publishing these documents.
Both process groups and owned JVM handlers are quiescent. Explicit disposable
cleanup completed, and `plugin-report` replayed successfully afterward. The
[public receipt](evidence/2026-10-03-plugin-attribution.json) records independent
input/result/source identities, graphs, matches, provider hashes and cleanup.
The original compiler control evidence remains necessary for future replay.

One initial attempt (`273125fc9c10dd33e6c3fdaa5012a031`) failed before resolution
because the new check lacked its namespace; no candidate ran. Its failure logs
remain, recovery and cleanup completed. An intermediate passing resolver pair
(`2e564180405c1313dace702ba22bbcbb`) established the joins; its recovery and
cleanup completed. The final fresh pair above adds the existing owned JVM
handler and is the acceptance result. No failed attempt supplies a passing cell.

Contracts cover missing/different/ambiguous hashes, coordinate/variant ambiguity,
extra measured/resolved inputs, excluded compiler artifacts, disconnected or
incomplete graphs, changed configuration, unsupported platform-specific roots,
private content and consistently rehashed summaries that fail producer replay.
See the [repeatable command guide](compiler-plugin-attribution.md).

Remaining gaps include shaded code, Native distribution contents, unmeasured
Native test compiler inputs, general module/artifact attribution and uncollected
delegated variants. This slice does not add lifecycle/cancellation/failure or
generic-export parity, device/minimum-floor app execution, Swift Full/macro,
release/archive/signing, clean-clone or cold hosted direct proof. Those remain
independent [retirement gates](bridge-retirement-path.md).

Validation passed 229 repository contracts (seven new attribution contracts),
pinned static gates and 18 strict OpenSpec items. An initial contract invocation
selected an incompatible Git through inherited PATH; after selecting system Git,
the sandbox still denied required process inspection. The complete run with
macOS process access passed; neither failed environment attempt was treated as
application incompatibility.

A later [Toolchain 0.13.0 adoption assessment](toolchain-adoption-assessment.md) executes a fresh version-bound resolver pair against the retained upstream compiler producers. It closes their measured plugin-file joins independently and expands the candidate lookup to 549 pairs; all 17 advisory IDs remain. This historical 0.12.2 proof still replays and is not automatically transferred to the candidate.
