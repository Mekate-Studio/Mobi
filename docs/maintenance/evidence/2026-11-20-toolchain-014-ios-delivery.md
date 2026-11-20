# Toolchain 0.14.0 local iOS delivery check — 2026-11-20

**Result: both wrappers pass the existing native test plan from empty private
Kotlin caches, then launch the copied tested app with its original producer
paths unavailable.** This closes the measured local delivery/relocation slice.
Fully cold hosts, hosted candidate execution and adoption remain open.

Base: `cdde1b91c9c6b92219f0cd0ae81e7c8a43874589` (merged PR #119).
Kotlin/exporter 2.5.0-RC, Metro 1.5.0, Swift locks, platform floors and app behavior
were fixed. The candidate changes only the reviewed wrapper pair. The existing
[release-specific qualification exception](2026-11-18-toolchain-014-qualification.md)
applies; the receipt retains `age_blocked` and normal November 23 eligibility.
The selected app remains on Toolchain 0.13.0.

## Scope and executed checks

Run `909a7d3155058d2f9628a1ecae52356c` used the existing `ios-test` job and
PullRequest plan. Each phase verified an absent project build directory and empty
private bootstrap, Kotlin-user-home, Gradle and Kotlin/Native caches before work.
Xcode/SDKs, Ruby/JDK, CoreSimulator and host SwiftPM caches remained available;
SwiftPM explicitly reported cached fetches. This is bounded local cache evidence.

| Check | 0.13.0 | 0.14.0 |
| --- | --- | --- |
| Native case functions / passed executions | 80 / 174 | 80 / 174 |
| Exact native case set | Same | Same |
| Generated complete-switch / omission controls | 6 passed / 6 rejected | Same |
| Linked Kotlin runtime / Swift-export mode | One image / mode verified | Same |
| Copied tested app | 319 files unchanged | 319 files unchanged |
| Installed executable | Matches copied executable | Same |
| Relaunched process with original paths unavailable | Stable for 10 seconds | Same |
| Mach-O dependency paths inspected | 49 images; platform/relative paths | Same |

After the native plan, the tested Debug simulator app was copied to a sibling
delivery directory and its complete file manifest compared. Once compiler
children were quiescent, the exact project, private-cache and private-home paths
were renamed out of reach. The copied app was installed and launched on an owned
iOS 27.1 iPhone Duo simulator. Installed executable identity and stable process
identity were checked before restoring those paths and verifying source content.
This tests the application bundle; portable reuse of raw generated Swift modules
or project incremental state is outside this result.

This is the **tested Debug container, including its test plugin/support**.
The separate [unsigned Release assessment](2026-11-19-toolchain-014-release.md)
retains its own producer-input and optimized-runtime limits. Both manually
inspected screenshots show the native Nearby map and the location-permission
prompt. Permission was left unset; location interaction and full feature/physical
device acceptance were not exercised by this launch smoke.

## Preserved limits and diagnostics

The initial run passed the baseline native plan and reached app launch, but its
screenshot call did not select among the Duo's two displays. It remains an
inconclusive observer attempt. The corrected pair uses simctl's documented
`--display=primary`; no app/producer change or maintained runner was added.

Both runs retain Xcode's runtime-version parsing diagnostic and CoreSimulator's
Safari data-migration failure text, including simctl's zero bootstatus exit.
Successful app/test results do not close those host diagnostics. They are tracked
as [WARN-13](../compiler-warning-follow-ups.md#warn-13-xcode-and-simulator-diagnostics).
Other compiler/generated warnings remain in the raw logs and existing backlog.
IOS-08 strict support stays blocked in both modules; IOS-10 and other active
interop mechanisms remain. No warning suppression or workaround retirement is
credited to these passing checks.

The [compact receipt](2026-11-20-toolchain-014-ios-delivery.json) binds the source,
run, case sets, copied products, screenshots and load-path observations. Full
logs/inventories/screenshots stay ignored. Source/index preservation, owned
simulator removal and quiescence were verified before cleanup; heavy outputs were
removed between phases to bound disk use. Dependency-risk acceptance, fully cold
hosted execution, minimum-OS/device proof and signed delivery remain separate.
