# TCA and reporting-package assessment — 2026-11-14

Base: `448a604dd9448801f9e1fd45be075a23e3f0f816`, merged PR #108.
This candidate updates TCA and its coupled reporting packages. Mobi adds no
adapter, module alias, source patch or compiler exception. App behavior, test
assertions, Kotlin/exporter versions and platform floors remain unchanged.

## Package changes and source review

| Package identity | Baseline | Candidate |
| --- | --- | --- |
| `swift-composable-architecture` | 1.26.0 | 1.26.2 |
| `xctest-dynamic-overlay` | 1.10.0 | 1.13.1 |
| `swift-issue-reporting` | absent | 2.1.2 |

The complete [TCA interval](https://github.com/pointfreeco/swift-composable-architecture/compare/1.26.0...1.26.2)
contains 15 commits. Its only non-documentation library-source change removes
unused internal notification-name globals. Mobi calls none of those symbols.
Effect, TestStore and macro implementation sources are unchanged. The package
manifests change reporting-package ownership and support compiler-specific
dependency graphs; a patch label does not make this a one-package update.

The [reporting interval](https://github.com/pointfreeco/swift-issue-reporting/compare/1.10.0...2.1.2)
contains 18 commits across 52 files. It includes the 2.0 package rename/API
changes, `expectReportsIssue`, restored deprecated migration APIs in 2.1,
test-support symbol caching and the 2.1.2 Swift 6.2 fix. Mobi does not directly
call the removed notification globals or the reporting migration helpers.
TCA's failure reporting still requires actual runtime qualification.

The [legacy-package interval](https://github.com/pointfreeco/xctest-dynamic-overlay/compare/1.10.0...1.13.1)
supplies upstream compatibility products for owners still using the old URL.
Its Swift 6.4 manifest forwards through `_IssueReporting` to the canonical
package, avoiding duplicate target names. Version 1.13.1 corrects that manifest's
minimum platforms; iOS 15 remains below Mobi's unchanged iOS 26 floor.
This is upstream packaging, not a new Mobi workaround.

All three selected stable releases exceed the seven-day review window:
TCA 1.26.2 was published August 28, compatibility package 1.13.1 August 27,
and IssueReporting 2.1.2 October 13. No age waiver is needed.

## Actual local resolution

Xcode 27.2 / Swift 6.4.2 selects the default Swift 6.4 manifests for TCA and
the compatibility package, and the Swift 6.0 manifest for IssueReporting.
`swift package dump-package` on the actual checkouts records these selections.
Older supported compilers have different upstream versioned manifests; hosted
resolution and compiled-target results are recorded in the review PR. Identical
compiler graphs are not assumed from a shared version number or lockfile.

Updating TCA alone fails actual workspace resolution: the new package and
legacy 1.10.0 both declare `IssueReporting` and `IssueReportingTestSupport` targets.
The coupled candidate resolves successfully with **16 pins instead of 15**.
Only the three identities in the table change; the other 13 pins, including
SwiftSyntax 601.0.1, remain identical. Local frozen resolution succeeds and
the lockfile stays byte-identical through the normal Debug test build.
No exclusion, forced module rename or custom lockfile selector is introduced.

The existing inventory contract initially failed because it hard-coded 15 Swift
packages. It now compares every identity, version, revision and repository with
the reviewed lockfile. The inventory parser itself needs no change.

## Behavior qualification and limits

The unchanged baseline is the immediately preceding PR #108 qualification.
Its tested head `6ed88dd410a1c00f07b8533e91c439ac0640b01f` and this merged base
have the identical Git tree `7b54356ef39cff64bac311da8fd61bb81b12189b`.
The local Xcode/Swift tuple is unchanged; that baseline passed 79 native test
functions, all four staged mobile gates and [hosted CI #709](https://github.com/Mekate-Studio/Mobi/actions/runs/43611080040).
It is reused as source-bound baseline evidence, not described as a new run.

The candidate passes all 79 local native test functions, with no failures/skips,
including Home/Nearby cancellation, exact-state recovery, supersession, retained
failures, scene/tab lifetime, timer cases and Kotlin/Swift repository controls.
All generated-case, actor and one-Kotlin-runtime checks pass.

An intentional TestStore control changes only the initial Home send expectation
to loaded value 999 while the reducer remains initial. The test fails with
exit 65 and `A state change does not match expectation`, reported through TCA
and the new reporting graph. The ordinary Swift Testing state assertion still
expects the actual initial state. This checks failure routing, not merely a
successful test launch. The original test bytes are restored afterward.

Unsigned Release, final normal staged gates and hosted compiler-specific results
are recorded in the PR. Download caches were seeded privately; build iterations
may reuse outputs. No controlled performance or byte-equivalence claim is made.
Signed delivery, physical-device/exact-floor execution and complete advisory
coverage remain separate. Authenticated public repository advisory queries for
the three owners returned no records; this is a bounded provider observation,
not a complete Swift dependency scan or new risk acceptance.

## Retained mechanisms and future review

TCA's unchanged Effect/TestStore implementation supplies no source-level lead
for removing the pre-registration lifetime owners or IOS-13's global executor
constraint. Existing runtime regressions qualify their continued behavior;
no new cancellation-ID removal control is claimed. All nine active interop
requirements remain. The historical timer flake stays unresolved.

On native dependency/compiler updates, inspect both selected manifests and the
actual resolved and compiled graphs. Requalify normal behavior and deliberate
failure reporting. The upstream compatibility package can leave the graph when
supported owners no longer require its old URL/products; do not replace it with
Mobi glue. Revisit IOS-13 and MOB-08 only when supported APIs and their existing
runtime removal controls qualify simplification.
