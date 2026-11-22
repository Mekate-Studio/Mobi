# Toolchain 0.14.1 local native delivery check — 2026-11-22

**Result: both wrappers pass the existing iOS native plan from empty private
Kotlin caches, then launch the copied tested app with original producer paths
unavailable. Android unseeded retrieval is inconclusive on the baseline;
its candidate did not start.** The app stays on 0.13.0. Adoption, dependency-risk
acceptance and signed delivery remain separate decisions.

Base: `be039d3c978b081673add4fa036a02b2c571e445`, merged PR #132.
Kotlin/exporter 2.5.0-RC, Metro 1.5.0, Swift package locks, platform floors and
app behavior stayed fixed. Only
the reviewed candidate wrapper pair differs in captured app/build inputs. The
[0.14.1-specific qualification exception](2026-11-21-toolchain-0141-qualification.md)
applies; receipts retain `age_blocked` and November 26 normal eligibility.

## iOS tests and relocation

Run `2ef6086ae85c0ffd3d33ed3c5d5a437e` used the existing `ios-test` job and
PullRequest plan. Each app declares iOS 26.0; owned iOS 27.1 iPhone Duo simulators
ran the tests and copied apps.
Each phase verified five empty/absent private roots: project build, bootstrap,
Kotlin user home, Gradle and Kotlin/Native caches. No JAR seed was used. Installed
Xcode/SDKs, Ruby/JDK, CoreSimulator and host SwiftPM caches remained available.
This is bounded local cache evidence, not a fully cold host.

| Check | 0.13.0 | 0.14.1 |
| --- | --- | --- |
| Native case functions / passed executions | 80 / 174 | 80 / 174 |
| Exact native case set | Same | Same |
| Complete switches / deliberate omissions | 6 pass / 6 reject | 6 pass / 6 reject |
| Kotlin runtime / Swift-export mode | One image / verified | Same |
| Copied tested app contents | 319 files unchanged | 319 files unchanged |
| Installed executable | Matches copied binary | Same |
| Stable launched process with producer paths unavailable | 10 seconds | 10 seconds |
| Mach-O images inspected | 49 | 49 |
| Producer-directory runpath entries retained | 43 | 43 |

After tests, each Debug simulator app was copied to a sibling delivery directory
and every regular file's content hash compared. Compiler children were stopped;
the exact project, private cache and private home directories were renamed out
of reach. The copy was installed on an owned simulator. Its installed executable
matched the copy and process identity stayed stable for ten seconds. The original
directories were restored and authored input hashes/modes verified afterward.

Load-command inspection records absolute `PackageFrameworks` search paths inside
the build tree. [Apple's run-path guide](https://developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/DynamicLibraries/100-Articles/RunpathDependentLibraries.html)
describes runpaths as a search list for resolving dependent libraries. Presence
alone does not establish reliance on that directory. The unavailable-path launch
provides the narrow runtime observation here; no runpath stripping, relinking or
app/build flags were added. It does not prove every image or code path is portable.

This is the **tested Debug container, including its test plugin/support**.
Raw generated-module reuse, relocated test-runner execution, Release runtime,
minimum-OS/physical-device behavior and full UI acceptance remain outside this
launch smoke. Both inspected primary-display screenshots show Nearby Map with
the location prompt unanswered. Permission was not granted. The
[unsigned Release](2026-11-21-toolchain-0141-release.md) and
[synthetic-signing AAB](2026-11-22-toolchain-0141-aab.md) records retain their scopes.

## Android retrieval remains incomplete

Independent run `eef74ca1f16e66a8e1c72b78d9584299` verified empty private Kotlin
roots and ran the adopted 0.13.0 Android Debug job without the historical JAR seed. Maven
Central returned HTTP 429 for `org.robolectric:nativeruntime-dist-compat:1.0.20`;
the existing sequential hydration/retry also received 429. The executor recorded
`inconclusive`, preserving baseline failure rather than classifying a candidate
regression. No 0.14.1 phase ran and no APK was qualified by this attempt.

One subsequent HEAD request returned HTTP 429 with `Retry-After: 83295` and server
date November 22 at 07:35:23 UTC. The recorded response requests waiting until
**November 23 at 06:43:38 UTC** before retrying from this host.
That is retry guidance, not a promise of recovery. No alternate repository,
dependency override or cache seed was added. Android cache-free retrieval stays
open; iOS success does not close it. Repeat retrieval without the historical
one-file seed only after the provider's retry window permits it.

## Evidence, retained attempts and limits

The [compact receipt](2026-11-22-toolchain-0141-delivery.json) binds independent
outcomes, source/index, implementation/policy, initial roots, native case sets,
generated controls, copied/installed products, screenshots, load paths, retry
guidance and cleanup. Full logs, case lists, images and inventories stay ignored.
Owned simulators/compiler processes were verified quiescent before heavy-output
removal and final workspace cleanup. Authored source was restored; the original
caller checkout was not switched or cleaned.

Two incomplete iOS observer attempts remain explicit. Both passed the baseline
native plan (80 functions / 174 executions); neither reached relocated launch.
The first over-constrained absolute runpath presence. The second tripped on an empty bundle
file during Mach-O inspection. The corrected inspector was validated against
the retained app's 49 images before the complete pair. Original observer identities,
diagnostics and owned cleanup are retained. No maintained policy was relaxed.

Both strict-support probes remain blocked; IOS-10 and other active interop
mechanisms are retained. Passing does not close the
[compiler/Xcode/simulator warning backlog](../compiler-warning-follow-ups.md),
[dependency findings](2026-11-21-toolchain-0141-dependencies.md) or
[delegated-owner/transform-observer gaps](2026-11-21-toolchain-0141-delegated.md).
