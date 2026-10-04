# Current direct dependency-resolution assessment

Date: 2026-10-02. Decision: the named module graph and exact-input provider lookup
passed; complete direct dependency/advisory review and bridge retirement remain
**deferred**. Production still uses the Gradle bridge. No dependency, target,
release default or schedule changed, and this assessment was not committed.

## Verified facts

Run `5f3dbe7bd5c6433eb5d93ce558db52fc` used a working snapshot at `ba8270f`
with source identity `c5899fb2eca78ec4a4b86f071b437d71cc0e1e95f6bdb74d4ecf125970ec3745`.
The paired execution ran from 19:59:39Z to 20:00:45Z. Each phase independently
resolved its inputs in owned caches. Toolchain 0.12.2 reported Kotlin 2.4.10,
Compose 1.11.1 and configured Metro compiler/runtime 1.4.5. The retained bridge's
Kotlin 2.4.20/SKIE 0.10.15 pins were preserved in the caller.

| Surface | Verified result | Limit |
| --- | --- | --- |
| Baseline module graphs | 92 roots across seven modules; main/test compile/runtime coverage for declared Android and both ARM iOS targets | This profile does not resolve the Gradle bridge graph. |
| Direct candidate module graphs | 92 roots, same declared target coverage; bridge absent and shared DI reachable in the owned copy | Reachability is graph evidence; native execution was not attempted here. |
| Exact Maven query set | 305 distinct selected package/version queries in each phase; candidate queries submitted to OSV | Compiler/plugin and delegated build-tool graphs are not represented. |
| Downloaded fingerprints | 1,788 baseline and 1,758 candidate relative file identities | Cache inventories are not proof of exact artifact selection or attribution. |
| Provider lookup | Four OSV batches (100/100/100/5), complete response counts, no pagination, zero matching finding IDs | Complete only for the 305 named Maven inputs. |
| Integrity and cleanup | Authored declaration hashes and raw graph replay verified; caller source/HEAD/index preserved; recovery quiescent and cleanup completed for both phases | Retained receipts remain local; owned build copies/caches were removed. |

The [public receipt](evidence/2026-10-02-direct-resolution.json) binds the tuple,
source, implementation, commands, parsed graphs, fingerprints, exact queries and
provider responses. The final report was generated after cleanup released its
lease and reverified both graph and advisory evidence. No native capability was
filled by this graph-only run. The earlier [current-tuple round trip](direct-current-assessment.md)
retains its own simulator, incremental and restoration evidence.

One earlier run, `cf044818b83600ed08891797fb6c0984`, refused its baseline because
the worker supplied a declaration set without `project.yaml` to the new validator.
The candidate never ran. Its outcome and receipts remain retained; recovery was
quiescent and cleanup completed. The call was corrected and a worker contract
now verifies captured project declarations and absence of native setup. The
successful retry uses a distinct source identity and run; the failure was not
relabelled or overwritten.

The initial full suite passed 213 contracts. After that correction, all 20 existing
compatibility contracts and all 10 direct-resolution contracts passed, including
the new worker regression. The repository now contains 214 contracts. Static
checks passed and strict OpenSpec validation passed all 16 items.

## Untested assumptions

The pretty Maven graph does not establish the compiler-plugin classpath, Kotlin
compiler/Native bundle internals, Toolchain-delegated Android Gradle configurations,
shaded code, or Swift/Ruby/npm advisory coverage. Configured Metro compiler 1.4.5
appears in effective settings but not as a selected node in these module graphs.
Both compiler and Kotlin Gradle Plugin coordinates remain outside the queried set.
The earlier Kotlin Gradle-plugin advisory lead therefore remains unverified for
the direct build; absence from this limited graph proves neither selection nor
clearance. The bridge's separate advisory assessment is not transferred here.

Application/native tests and builds were explicitly unexecuted. This profile
adds no device/minimum-floor, Full-plan/macro, release/signing, lifecycle/generic,
clean-clone or cold hosted evidence. No parity is inferred from successful graph
resolution or the absence of named Maven matches.

## Blockers and next small implementation

Stage 1 of the [retirement path](bridge-retirement-path.md) now has verified
module/target graphs and a reusable exact-input OSV lookup. Complete direct graph,
artifact attribution and advisory gates remain open.

The next bounded collector should capture the **selected compiler-plugin and
Toolchain-delegated Android build graphs** during bridge-unavailable execution.
Acceptance: retain upstream version/source and producer bindings; distinguish
configured plugins from selected classpaths; map actual selected artifacts to
hashes; expose unresolved and unsupported configurations; bind fresh advisory
queries to those exact inputs; preserve baseline-first execution, native targets,
Swift state adapters, recovery and cleanup. If upstream offers no authoritative
producer for a scope, record that scope as unsupported rather than deriving
selection from cache filenames. Native bundle and other ecosystem review stays
explicitly separate.

After that evidence, proceed to interop/behavior and native/release/onboarding
stages, then present a reversible default-switch patch for explicit approval.
Default switching and physical bridge deletion remain separate decisions.

The [2026-10-03 build-input follow-up](direct-build-input-assessment.md) now measures
bounded compiler paths/hashes and delegated Android graphs. Its broader named
lookup finds 17 build-tool matches; the earlier 305-query module-only no-match
receipt remains valid only for its original scope and time.
