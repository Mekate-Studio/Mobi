# Swift export production risk review

Date: 2026-10-13. Status: technical assessment complete; production adoption held.
Accountable maintainer: Jorge Castro. Risk dispositions remain pending.
The [machine-readable packet](evidence/2026-10-13-swift-export-risk-review.json)
records source bindings, query identities, provider hashes and findings.

The reviewed opt-in pilot supplies source and execution evidence for a later
production integration. That integration should supersede the alternate pilot
path while preserving the main app's Shared UI and one Kotlin delivery. This
review changes no dependency pins, builder defaults, compiler flags or risk
approval. PR [#37](https://github.com/Mekate-Studio/Mobi/pull/37) remains unmerged.

## Evidence boundary

The inspected hosted source is `00814c8f4389e04e025ebdc420d42f3dd71bf399`,
[run 38444261023](https://github.com/Mekate-Studio/Mobi/actions/runs/38444261023).
The review checkout is `1a8197051117004ec9247b309e61179a8b612422`; all 111
selected producer/pilot hashes and modes still match the qualified source.
The native source identity is
`89058d0ac9018f9ce73431fd1ff405d6e86e5056538c60ac07a707cd960c81b9`;
the hosted compiler tuple identity is
`cd164717723457c4aa68f1184a11f85d7c02c8fe1b30c648f4172290ae5800cf`.

Scope is `coroutine-swift5`, `main-confined`, Compose disabled, arm64 simulator,
deployment target 26.0 and SDK/runtime 27.0. Both cold enum phases and both
guarded original-archive replay phases passed nine tests each. The
[qualification record](swift-export-native-qualification.md) preserves receipt,
delivery, quiescence and cleanup verification. Those results do not qualify a
changed production graph or broader generated APIs.

## Diagnostic decisions

Both cold check receipts contain 203 exact fingerprint entries. Their combined
406 entries include repeated compiler context and are **not 406 unique warnings**.
Independent inspection of retained replay build/runtime logs found 122 further
review fingerprints in seven of the same families, with no unclassified family.
Replay fingerprints use the replay check hash as their analysis binding;
they are distinct from the producer's original fingerprints.

| Family | Production requirement |
| --- | --- |
| Coroutine inheritance | Generated `SwiftJob : Job by Job()` needs an upstream-compatible bridge, or a demonstrated export surface that excludes it from supported use. Adding an opt-in is insufficient. |
| Error sendability | Generated `KotlinError` stores mutable, non-Sendable `KotlinBase`. Broader async/error crossing needs an isolation/value-error design and negative concurrency controls. |
| Implementation-only imports | Use an actively checked compiler recipe, then repeat affected hosted cold/replay qualification. The local rehearsal below supports this candidate. |
| Kotlin and Swift generated casts | Bind exact exporter/runtime/types; audit callback lifetime and erased Flow casts for any expanded API. Preserve typed wire/owner validation. |
| Unused/redundant values and unreachable defaults | Retain scoped source/message review. Original/reordered facade controls cover the declared transport; new variants and exporters need review. |
| Generated C++ initializer extension | Keep the Clang/target gate. Compiler or target changes require requalification; full temporary `api.cpp` is not retained in the delivery. |
| JDK restricted/native/Unsafe APIs | Current JDK 26 passed; future removal remains a tool compatibility concern. Blanket native-access enablement or warning suppression is not a repair. |
| AppIntents metadata | Extraction skips match the absent AppIntents dependency in this pilot. AppIntents and signed/archive behavior remain unqualified. |
| MapLibre inset deprecation | Include explicit inset handling and map UI verification in production/platform work. |
| Module ordering and absent signing configuration | Organizational and unsigned-build findings. They do not establish signed-delivery capability. |

The [coroutines API documentation](https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines/-internal-for-inheritance-coroutines-api/)
marks the inheritance contract unsafe; the retained 1.12.0 producer warning
also says future enforcement will become an error. The generated Swift source
and compiler diagnostics establish the error-sendability finding directly.
The current adapters use synchronous Main-confined facade calls, copy checked
Swift values, and await native polling/cancellation seams. A source audit found
no pilot call to `KotlinError`, `withKotlinContinuation`, `withKotlinTask`,
`asAsyncSequence` or `KotlinTask`. This narrower call path does not establish
whole-binary unreachability or general bridge safety.

For production, define the supported facade API explicitly and constrain exports
and callers accordingly. Broader generated suspend/Flow/error use remains held
until its bridge and lifetime contracts are repaired and tested. Do not patch
generated sources to add unchecked Sendable or suppress inheritance enforcement.

### Checked-import rehearsal

Swift's [implementation-only diagnostic explanation](https://github.com/swiftlang/swift/blob/main/userdocs/diagnostics/implementation-only-deprecated.md)
describes hidden-type layout hazards without library evolution. The isolated
local comparison added `-enable-experimental-feature CheckImplementationOnly`.
A deliberately invalid public layout containing a hidden imported type compiled
under the baseline and was rejected with the checker, proving that the control
was active. All ten retained original-delivery modules emitted successfully both
before and after adding the checker. Implementation-only deprecation messages
disappeared; other generated findings remained visible.

This is module typechecking evidence, not an app link/runtime, binary stability
or library-evolution qualification. Local and hosted tools report Swift 6.4 /
Xcode 27.0, but their bound tool bytes differ. The local tuple is
`a44ec744bb9333e3ec14ea5786aa9ce3e0db45a13246e74b61588070803ac97d`;
fresh hosted receipts are required after adopting the recipe change. Earlier
probe setup attempts had a fixture syntax error and a graph-array parsing error;
only the corrected paired comparison is credited.

## Fresh dependency review

GitHub advisory requests used the existing macOS Keychain-backed login, without
retaining credential values. OSV was an independent public provider, as in the
repo's advisory collector. Failed authentication would not trigger an anonymous
GitHub fallback. The [GitHub advisory API](https://docs.github.com/en/rest/security-advisories/global-advisories)
and [OSV schema](https://ossf.github.io/osv-schema/) define the lookup scopes.

The review queried 25 Maven package/version probes, 15 native Swift package
versions and 15 locked Git commits. Maven probes include explicitly recorded
canonical counterparts of target-specific artifacts; applicability still needs
platform triage. The separate 549-query refresh describes retained historical
build-input producers, **not a newly collected selected graph for this pilot**.
All 61 query/finding response packets passed status, cardinality/pagination,
content-hash and freshness checks. Fifteen authenticated repository metadata
lookups verified native package identities.

A positive SwiftNIO lookup exposed a normalization error: HTTPS SwiftURL names
returned empty answers, whereas `github.com/apple/swift-nio` returned the known
findings. Initial HTTPS lookups were superseded for coverage; all 15 native names
were requeried in canonical form. The control package is excluded from Mobi's
finding counts. Corrected native named lookups returned no matches; embedded
MapLibre C/C++ components are outside those lookups.

The current exporter JAR inputs match
[GHSA-rcgg-9c38-7xpx](https://github.com/advisories/GHSA-rcgg-9c38-7xpx):
`io.opentelemetry:opentelemetry-api:1.41.0`, Medium, unbounded baggage parsing.
The provider names 1.62.0 as a patched version. The actual parser's reachability
from this compiler/build path is unmeasured; the version match is retained for
triage. A standalone transitive override has not been adopted or rehearsed.

The historical build-input refresh returns **22 IDs: two Critical, nine High,
ten Medium and one Low**. Five IDs are outside the old 17-ID decision:

| New ID in this review | Severity | Matched historical component |
| --- | --- | --- |
| [GHSA-mcr4-qmvw-px4g](https://github.com/advisories/GHSA-mcr4-qmvw-px4g) | High | `org.lz4:lz4-java:1.8.0`, shared-temp native extraction |
| [GHSA-4v53-57pg-c464](https://github.com/advisories/GHSA-4v53-57pg-c464) | Medium | Same component, unvalidated compressed length allocation |
| [GHSA-6cx8-rjf8-pr8g](https://github.com/advisories/GHSA-6cx8-rjf8-pr8g) | Medium | Same component, unvalidated decompressed length allocation |
| [GHSA-gm45-99xc-r7wv](https://github.com/advisories/GHSA-gm45-99xc-r7wv) | Medium | Same component, frame-buffer CPU/GC amplification |
| [GHSA-343h-94h5-c4wr](https://github.com/advisories/GHSA-343h-94h5-c4wr) | Low | Same component, recursive empty-block handling |

Existing findings, including Bouncy Castle, Jackson, JDOM and jose4j, remain in
the packet. They were not erased by the new findings or passing application CI.
These are build-input findings; phone-runtime exposure is not established.

### Existing controls and approval limits

For the new LZ4 extraction finding, the primary advisory names private
`java.io.tmpdir` as a workaround. The owned executor already creates phase
directories with mode 0700 and launches workers with umask 077. The producer
passes its owned temp path through explicit Java/Toolchain options. An isolated
Toolchain 0.13.0 version launch confirmed the requested JVM temp property and
mode 0700 with matching owner/process UID. This is a launch/control observation;
every production JVM path and native-library use still needs verification.
It does not remediate the separate LZ4 allocation/decoder findings.

The existing `review-toolchain-risk` checker currently returns `blocked` for
stale advisory/release evidence and source-binding drift. The new provider packet
was kept separate to preserve the historical receipts. Even after freshness is
restored, the five additional IDs prevent carrying forward the old exact finding
set unchanged. Its November 3 expiry is not approval for new findings, changed
source or production/release scope. No approval record was extended.

Prefer a supported repaired Toolchain/exporter dependency cohort, or prepare a
new bounded source/artifact/control decision after verifying the production
selection. The fixed yawkat LZ4 coordinate differs from `org.lz4`; do not silently
swap vendor JARs. Preserve the private-temp control through production wiring.

The remaining security surfaces are a fresh selected Toolchain graph for this
pilot, embedded MapLibre dependencies, host JDK/Swift/Xcode/Ruby vendor coverage,
the future production Compose graph and actual consumer reachability. Empty
named lookups cannot close them.

## Production handoff

The next production proposal should carry these requirements:

1. A supported, enforced facade API boundary; resolve broader coroutine/error
   bridge use before exposing it.
2. A checked generated import recipe, source-bound diagnostic gate and fresh
   affected cold/replay/hosted evidence.
3. Current selected dependency attribution, remediation or a concrete bounded
   risk decision covering the new findings and exact production source.
4. Verified private JVM temp handling for every affected launch path.
5. Preservation of Shared UI, the same Home service and one Kotlin delivery;
   runtime settings, devices, deployment floors and release remain separate gates.

All diagnostic catalog entries retain `review_required`. The result is a
concrete review packet with production holds, not an activated risk exception.
Raw responses, exact cold/replay ledgers and probe receipts are retained under
ignored `.maintenance/swift-export-risk-review-20261013T202940Z/`.
