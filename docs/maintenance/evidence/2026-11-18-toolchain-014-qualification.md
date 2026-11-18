# Toolchain 0.14.0 qualification — 2026-11-18

Status: local functional checks passed; adoption remains unqualified.
The [source assessment](2026-11-17-toolchain-014-assessment.md) was merged as
`4f1974c324f55e6fe53a11cc3011889c36d76ce9` (PR #114).

## Approved age exception

On November 18 the maintainer explicitly approved the proposed release-specific
exception: “ok merged, and exception is approved”. This permits experimental
qualification of Toolchain **0.14.0**, published **2026-11-16T14:49:08Z**, with
declared distribution SHA-256
`69112cebc1fdb14c92a213244182d0834896e71b3d9411b8e8c18540da2884a6`.
Normal eligibility remains **2026-11-23T14:49:08Z** under the unchanged seven-day
policy. Runs must retain `age_blocked` and `adoption_authorized: false` while
under age; earlier releases' decisions do not authorize this one.

The exception does not authorize adoption, a default switch, security acceptance,
signing/publication or workaround removal. The maintained wrappers and baseline
remain 0.13.0. Kotlin/exporter 2.5.0-RC, Metro 1.5.0, Swift packages, platform floors
and feature behavior remain fixed during comparison.

## Compatibility adaptations for review

- IOS-10's existing producer accepts only the reviewed 0.13.0 and 0.14.0 wrappers;
  each library record must match the selected wrapper exactly. Mixed task-record
  versions and mixed Kotlin compilers still refuse. This is producer maintenance,
  not a supported replacement or retirement of IOS-10.
- Owned Gradle cleanup recognizes the 0.13 wrapper distribution and the 0.14
  root-stripped Toolchain extraction cache. Launcher/classpath ownership stays
  inside the exact private snapshot or execution phase. Foreign processes,
  redirected paths, missing/unknown launchers and identity changes must still
  refuse; recovery paths remain retained on uncertain cleanup.

No new build project, general metadata adapter, dependency override or test runner
is introduced. The [structured receipt](2026-11-18-toolchain-014-qualification.json)
binds the actual results, staged input identities and retained failure records.

The existing input runner also needs a correction independent of Swift export:
`tools/swift-export` is a nested module path, not a flat module name. Source guards
now use the validated path while graph coverage uses its basename. Traversal and
duplicate names refuse. The current output parser accepts the specifically tested
0.14.0 format; unknown formats and incomplete module/root coverage still refuse.

## Evidence collected so far

The paired input run `e736b701784a6fc0ee6c434f9cff883e` passed on both wrappers:
all nine modules, 104 dependency roots and 359 normalized Maven queries per phase.
The queried package/version sets match. The raw graphs are not identical: the
0.14.0 Android main/test runtime views omit a printed `lifecycle-livedata` constraint.
New effective-setting defaults include disabled desugaring and disabled klibs.io
publishing notifications; this does not enable either behavior in Mobi.

A fresh OSV batch has complete response cardinality, no pagination and both full
matched records. The measured module graph matches only the exporter's existing
OpenTelemetry API 1.41.0 findings, `GHSA-ccrj-gw8r-854m` and
`GHSA-rcgg-9c38-7xpx` (Moderate). This is not Toolchain-distribution or delegated
Gradle coverage, artifact remediation, security clearance or risk acceptance.

The initial input attempt refused the current nested module before executing a
Toolchain. After the path correction, the paired input run above passed.

The initial native run `c702475dcf4144d309e5a0b0d71cb370` passed the 0.13.0
Android/shared tests and Android Debug build. Its baseline iOS archive construction
then failed with `write64 ... errno=28` while writing `libMobiNative.a` (disk full).
This is an inconclusive baseline infrastructure result, not a candidate regression;
the executor did not start candidate native jobs. The failed run was verified
quiescent and its disposable work cleaned through the owned recovery protocol.
Raw logs, task records and input-run evidence remain retained.

## Completed local native comparison

Both versions passed the existing staged validation gate sequentially. The
baseline is preparation commit `78de93ee5815dd3229828e17ff62e69876deeca8`, whose
normal commit hooks ran with the unchanged 0.13.0 wrappers. The candidate is that
same code plus only the reviewed, LF-normalized 0.14.0 wrapper pair in an isolated
checkout; the overlay was not committed or adopted. Staged index/input hashes and
raw-log hashes are recorded in the receipt.

| Existing check | 0.13.0 baseline | 0.14.0 candidate |
| --- | --- | --- |
| Android/shared tests | 94 passed | 94 passed |
| iOS PullRequest plan | 80 functions / 174 executions; no failures or skips | Same counts; no failures or skips |
| Android Debug build | Passed | Passed |
| iOS Debug build | Passed | Passed |
| Actual Native project records | Seven records, code version 0.13.0, Kotlin 2.5.0-RC | Seven records, code version 0.14.0, Kotlin 2.5.0-RC |
| Generated Swift modules | Eight | Same eight |
| Generated API and actor controls | Passed, including six omission rejections | Passed, including the same rejections |
| Owned Gradle shutdown and copy cleanup | Passed; Gradle 9.5.0 | Passed; Gradle 9.8.0 in the new extraction cache |

The actual candidate delivery report identifies one Kotlin runtime image and
Swift-export mode. Both support-module strict probes remain blocked; these are
not a successful full strict-support producer run or grounds to retire IOS-08.
All active interop mechanisms remain. The full repository contract suite also
passed, including 25 iOS builder, 32 validation and 29 rehearsal contracts.

The candidate Debug APK was inspected with installed `aapt2` 37.0.0: application
ID is `studio.mekate.mobi`, minimum/target APIs are 36 and compile API is 37.
That verifies the expected identity/floors for the namespace migration, not full
resource invalidation, binary equivalence or signed-release delivery.

Sequential use of the existing staged gate avoids retaining two full SDK/native
workspaces together and adds no runner or SDK-copy machinery. Unlike the initial
paired executor attempt, it uses the standard local validation environment and
host SDK. These are local host checks, not cold-host, device, minimum-runtime or
signed-delivery evidence. The maintenance resource handler's new classpath roots
are exercised by the existing real-process ownership contracts; the staged gate
exercises the actual 9.8.0 launcher/shutdown path. The original paired mobile
executor result remains inconclusive.

Hosted validation of the preparation code with the selected 0.13.0 wrappers passed in
[CI run 44321876603](https://github.com/Mekate-Studio/Mobi/actions/runs/44321876603).
It does not independently execute the uncommitted 0.14.0 overlay.

## Simplification rechecks

The two-version acceptance is transitional qualification support. If 0.14.0 is
separately adopted, recheck the selected wrapper and retained resource inventory:
once no old-layout run needs recovery, review narrowing the producer to the
selected version and removing obsolete wrapper-cache discovery. Full-revision
rollback preserves the old implementation; this PR does not authorize removal.

On each Toolchain update, the existing IOS-10 review must still check the official
Swift-export docs, maintained sample and actual supported integration. A supported
producer replacement plus real delivery/regression evidence remains the condition
for removing the complete custom producer. Passing its 0.14.0 maintenance checks
does not satisfy that replacement condition.

## Remaining qualification gates

- Measure and attribute the Toolchain distribution and delegated Gradle graphs,
  then refresh their advisories. Module queries do not substitute for these owners.
- Verify unsigned Release, cold/relocated delivery, resource behavior and a
  controlled manifest/resource invalidation case.
- Preserve warning evidence; reduced default deprecation output is not WARN-09
  remediation. IOS-10 and AND-03 remain active/deferred respectively.

No adoption or workaround-removal conclusion follows from these functional
checks. Later qualification stages and their costs remain separately reviewable.
