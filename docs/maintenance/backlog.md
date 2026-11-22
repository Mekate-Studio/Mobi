# Maintenance backlog

## First rule: automate assessment before assessing new releases

No further manual assessment of new releases until the assessment automation is
operational. Discovery/notification alone does not satisfy this requirement.
Normal cleanup validation against the adopted tuple is allowed. Do not manually
investigate open dependency-update candidates while this prerequisite is unmet.

## Ordered increments

1. Remove the unused Gradle preseed helper pair and its obsolete Renovate and
   inventory tracking. Preserve Toolchain delegated Android Gradle/AGP bootstrap
   and the retired state of the hand-maintained iOS bridge. Correct the live
   index while retaining dated historical evidence and qualification limits.
2. Implement bounded automated assessment, reusing existing repo-owned
   maintenance/release-watch workflows, scripts, policy and relevant configured
   app automations. Audit them first; avoid duplicate schedules or reminders.
   Keep CI thin, operational behavior in scripts, and no mandatory private
   infrastructure or AI service in the public architecture.

   Assess stable **and all prerelease** versions. Cover official releases,
   source and documentation across the relevant interval; applicability to
   actual Mobi code and the selected graph; dependency/security provenance and
   freshness; affected workaround IDs; supported replacement leads; and
   meaningful change-relevant qualification checks. Emit explicit incomplete
   and blocked states rather than treating missing evidence as success.

   For Swift export, use official Kotlin docs/implementation as primary
   authority, the official Kotlin/swift-export-sample as supporting guidance,
   and relevant YouTrack issues including KT-64572 and KT-80305. A parent issue
   closure or release alone cannot establish retirement.

   Bound execution, concurrency, caching, resource cleanup and provider
   requests. Preserve baseline-versus-candidate failure attribution. Commit
   compact results and proposed next slices against the current app; keep raw
   inventories/logs ignored or as CI artifacts. Show an end-to-end automated
   assessment result before declaring this prerequisite complete. Surface
   meaningful decisions with code and execution cost visible; prepare concrete
   evidence before requesting critical approvals.
3. Revisit interop only through that automation: nine active entries, two
   qualified removals and six historical experiments. IOS-10 custom exporter,
   IOS-08 Swift 5 exception, IOS-02 caller-isolation profile and IOS-17 coroutine
   inheritance remain active; IOS-07/12/13/14/16 retain separate purposes.
   The Toolchain upgrade qualified no further retirement. See the
   [registry guide](interop-workarounds.md).
4. Address [compiler warning debt](compiler-warning-follow-ups.md) in small
   actual-code slices. Do not hand-edit generated output or suppress diagnostics
   to claim closure.
5. Evaluate simpler supported Shared Home UI runners through automation when
   ready (AND-03, MOB-04/05/06). Draft #99 is deliberately deferred; its extra
   build/private-metadata machinery was disproportionate and must not be adopted.
6. Review deferred copy/public interfaces and document visible feature behavior
   in small actual-code slices, with important design choices reviewed.
7. Keep physical-device/exact-OS-floor, recreation/process restoration and
   credentialed-delivery acceptance separate from development CI evidence.
8. Decide disposition of superseded pilot drafts #37/#38 and open Renovate
   PRs #31/#32/#33. Their new-release assessments remain gated by item 2.

Dependency adoption, age/risk exceptions, merges, signing/delivery and workaround
retirement remain explicit human decisions. This backlog authorizes none of them.
