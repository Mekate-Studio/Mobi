# Approved direct iOS default integration

On 2026-10-04 the maintainer approved applying the reviewed typed Kotlin/Swift
boundary and direct iOS default for development, repository tests and unsigned
builds. The approval covers the explicit API and preservation of current async
behavior. Credentialed archive/export/TestFlight remains held, and physical
bridge deletion is a separate later decision.

The reviewed [patch](evidence/2026-10-04-direct-default-proposal.patch) is bound
to base `349e07e` and SHA-256
`651301bf42c6e9949985ce7a9b7d3c4583fbe97efaa2f8d0beac81c6febb85bb`.
Its immutable candidate receipt remains historical. Application verified every
runtime preimage, preserved the caller index and unrelated pending inputs, and
retained all eleven bridge/catalog paths. Newer ADR/assessment documentation was
merged deliberately. The facade comments now describe the accepted boundary.

[ADR 0008](../adr/0008-explicit-ios-projections-and-direct-development-builds.md)
supersedes the iOS Gradle/SKIE build and projection portions of ADRs 0003 and
0006. Native Swift package ownership, sealed shared state, feature clients and
reducers remain. Android Toolchain builds may still delegate to Gradle/AGP.

## Risk and evidence boundaries

The original exception expires **2026-11-03T05:48:38Z**. Approval of this default
does not extend that date or claim vulnerability remediation. The generic risk
evaluator continues to grant no automatic adoption or retirement permission.
The explicit transition record binds the reviewed patch and current source;
credentialed delivery and physical deletion stay excluded.

Provider refresh initially refused because replay dropped finding IDs from
expired historical batches before checking their full records. The parser now
retains IDs from intact stale batches while preserving `stale_provider` and
`incomplete`. A regression contract also retains duplicate/unexpected-record
refusals. The failed attempts remain separate in the local integration log.

The [applied receipt](evidence/2026-10-04-direct-default-integration.json) records
288 contracts in eighteen suites, five static analyzers, 38 Android tests,
twelve original Swift cases and both debug builds. The same measured snapshot
passed the Nightly plan, unsigned simulator Release and unsigned ARM64 device
archive. Both products retain `studio.mekate.mobi`, minimum iOS 26.0, ARM64 and
compiled native assets. Owned process quiescence and cleanup were verified;
the caller index was preserved.

Native gate source SHA-256:
`a7485c06858ebaee18334bdd9f63a9c0b4e0dca1649d6656521828d511e50f55`.
Later evidence/risk-status documentation and two existing dead-reference repairs
leave native runtime bytes and modes unchanged. The refreshed risk report retains
549 queries and seventeen findings; exact artifact scope and original dates
remain unchanged. Retained producers are not a new integrated dependency scan.

Exact-revision hosted integration is pending publication of this approved source.
Earlier candidate and hosted operational receipts do not validate the applied
preflight/default source. Physical-device, exact-floor runtime, broad Compose
resources, empty-host/license onboarding and signed/export scope remain separate
gates.

## Rollback

Preserved bridge files are rollback inputs. A selector change alone cannot
restore SKIE consumers. Stop positively owned work, clear only its incompatible
products, restore the complete source bytes/modes from the prior revision and
rerun restored native consumers. The reviewed patch's byte/mode reversal and
earlier native round-trip restoration are separate evidence tracks; integrated
rollback must bind any documentation and risk-source changes as well. The
[byte/mode patch](evidence/2026-10-04-direct-default-integration.patch) and receipt
record reversal of the measured native snapshot, drift refusal and unrelated-input
preservation. Restored runtime matches published retained baseline `349e07e`.
No native products were created in this reversal copy; native execution after
this new reversal is unattempted. Subsequent metadata changes require their own
preimage review before using that patch for a live rollback.
