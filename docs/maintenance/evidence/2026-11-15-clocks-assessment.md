# Swift Clocks assessment — 2026-11-15

Base: `8da37587f6e17bec7f9884ea14932117792351c6`, merged PR #111.
Candidate: Swift Clocks **1.0.6 → 1.1.1**, revision
`82440fa0a8b1c381a6d1e8e0fc7bbba53ec63204`.

## Source review and actual use

The [complete interval](https://github.com/pointfreeco/swift-clocks/compare/1.0.6...1.1.1)
contains ten commits. It modernizes the compiler profile, adds the `.test`
constructor, makes imports/error existentials explicit, and updates documentation
and upstream tests. It does not replace `TestClock.advance` or its scheduling
algorithm. The new compiler settings can still affect actor execution, so a
small source diff is not behavior-neutral evidence.

Mobi reexports Clocks through its native test product and uses `TestClock` in
five actual SwiftUI timer scenarios. Swift Dependencies also uses Clocks in its
clock dependency implementation. This is not described as a test-only graph
update. Mobi's existing constructors, feature code, test assertions, compiler
settings and target memberships stay unchanged; adopting shorthand is separate.

The [1.1.1 release](https://github.com/pointfreeco/swift-clocks/releases/tag/1.1.1)
was published August 27 and exceeds the seven-day policy. No age waiver is needed.

## Compiler-specific dependency cost

On local Xcode 27.2 / Swift 6.4.2, the actual selected manifest changes from tools
6.0 to 6.4. It enables six upcoming features, including
`NonisolatedNonsendingByDefault`. Its package iOS minimum rises from 13 to 15,
below Mobi's unchanged iOS 26 minimum.

The local resolution retains 16 remote pins; only Clocks changes. The rooted
native-test dependency model retains all 76 targets. Its two changed edges are
Clocks and its product switching from the old `xctest-dynamic-overlay`
IssueReporting product to `swift-issue-reporting` **2.1.2**, already resolved by
the baseline. No package or product is added to Mobi's declarations.

The [Swift 6.0 fallback manifest](https://github.com/pointfreeco/swift-clocks/blob/1.1.1/Package%40swift-6.0.swift)
instead keeps the iOS 13 minimum and the old IssueReporting identity, with a
1.13.0 minimum. Its six upcoming-feature settings are also new against 1.0.6.
Hosted Xcode 26.6 must qualify that selected profile independently; the local
graph is not presented as its compiler-specific graph. Final hosted results
and actual resolved versions belong to the review PR.

## Qualification and retained requirements

The merged base and #111's tested head
`7fb534325bb005f17e0de4935145fbaddf2e4177` share the exact tree
`cb11111ee9e2b6d5a4751125bfa36aa410c5f2d9`. Its local native gate and
[hosted CI #726](https://github.com/Mekate-Studio/Mobi/actions/runs/43699633302)
passed. This reuses source-bound baseline test evidence, not a freshly executed
full baseline test suite. The installed local compiler/JDK tuple is unchanged.

The candidate passes all 80 native test functions, zero failures/skips, with
generated-case, actor and single-runtime checks. Each of the five unchanged
timer scenarios passes five configured iterations: 25 observed executions.
Their one-minute limits and all cadence, background, reentry and admitted-request
assertions remain; no retry-on-failure, scheduler-count override or sleep is
added. These are not independent cold launches or long-run reliability evidence.
All 19 repository contract groups pass. Release, final frozen resolution and
normal staged/hosted gate results are recorded in the review PR.

The file/line warning snapshot matches the previous successful native snapshot:
29 emissions at 27 distinct normalized locations, without added/removed entries.
The inspection-prepared candidate test build additionally records 20 package-
framework `-Wincompatible-sysroot` diagnostics. A fresh baseline Debug build
passes without them; that comparison does not establish their cause or attribute
them to the update. Preserve these diagnostics and the final fresh-gate results
with the warning follow-up; no suppression or SDK override is introduced.

**IOS-13: retained.** `.test` constructs the same clock; it is not per-test
executor isolation. The serialized suite, whole-scenario executor scopes and
readiness assertions remain. No scope-removal or parallel-execution probe is
claimed. Recheck the existing cold/parallel and negative controls when a supported
replacement becomes available. The historical timer flake remains unattributed
and open. All nine active interop requirements and MOB-08 remain unchanged.

The existing live release reader reads the 1.1.1 lock pin automatically, with no
newer Clocks lead observed in its bounded response. Future eligible Clocks leads
still request IOS-13 review; this feed check executes no native retirement probe.
Separate Metro release leads remain outside this update.

The authenticated owner advisory feed returns no published records; this is
bounded coverage, not full dependency-security clearance or risk acceptance.
Signed delivery, physical-device/exact-floor execution and performance remain
separate. Rollback restores the two package files; no application migration is
required.
