# Selected compiler and delegated Android build inputs

`direct-build-inputs` is a manual, bounded compatibility profile. It pairs the
current source baseline with the isolated typed-facade candidate whose
hand-maintained iOS Gradle bridge is unavailable. It changes no caller pins,
production builder or release defaults.

```sh
./scripts/dev/dependency_updates.sh prepare-kotlin
./scripts/dev/dependency_updates.sh rehearse-compatibility direct-build-inputs --store direct-build-inputs
./scripts/dev/dependency_updates.sh compatibility-report RUN_ID --store direct-build-inputs
./scripts/dev/dependency_updates.sh review-advisories RUN_ID --store direct-build-inputs
./scripts/dev/dependency_updates.sh recover RUN_ID --store direct-build-inputs
./scripts/dev/dependency_updates.sh cleanup RUN_ID --apply --discard --store direct-build-inputs
./scripts/dev/dependency_updates.sh compatibility-report RUN_ID --store direct-build-inputs
```

Use the matching store throughout and the documented Apple Silicon host
prerequisites. The executor copies the Android SDK into owned storage, creates
no simulator, and uses independent caches and Gradle homes for each phase.
Baseline failure prevents candidate execution. Recovery verifies owned process
quiescence before cleanup; cleanup preserves control evidence for replay.

Each phase verifies effective settings and all declared module main/test graphs,
runs existing Android host tests and debug packaging, and compiles shared Kotlin
libraries for `iosArm64` and `iosSimulatorArm64`. This profile does not run Swift
app/test targets or create distributable release artifacts. The earlier
[round-trip](direct-current-assessment.md) remains a separate bounded test.

The compiler collector reads Toolchain 0.12.2 OTLP telemetry emitted by successful
`kotlin-compilation` and `konanc` invocations. It requires selected `-Xplugin`
paths for all five reviewed shared modules on Android and both ARM iOS targets,
and hashes their actual files inside owned roots. Missing target/module scopes,
failed compiler spans, malformed arguments, missing files or escaping paths
refuse. File selection and fingerprints do not independently prove Maven
coordinates, transitive plugin graphs or shaded-library contents.

An observer in the phase-private Gradle home inventories the generated Android
projects used by Toolchain's delegated tasks. It records settings and project
buildscript configurations plus project configurations, distinguishes
non-resolvable configurations, and retains selected components, edges, variants
and artifact fingerprints. The reviewed resolution scope covers settings/project buildscript plus Android
debug-main and compiler/build-tool classpaths. Other resolvable configurations
remain `not_collected` with an explicit scope reason. Missing settings
classpaths, missing Android debug compile/runtime scopes, unresolved required
configurations/edges or missing artifact identity refuse. Opaque file inputs retain fingerprints without invented Maven
identities. Toolchain exposes its injected files as synthetic `localModule` /
`unspecified` module identifiers; the observer recognizes that upstream
namespace and retains opaque hashes rather than submitting false Maven queries. Observer-only resolution can include build-tool configurations the debug job
would otherwise leave lazy. These are resolution evidence, not execution of
every configuration or release target. Collection occurs in the delegated task
graph lifecycle; the completion callback only emits previously collected project
graphs and the already resolved settings classpath.

The final report verifies command/output/reference hashes, replays the retained
compiler and delegated producers, and compares the reconstructed summary.
Exact selected Maven pairs from module graphs and delegated graphs feed the
existing [source-bound OSV review](direct-resolution-review.md). Provider errors,
unfinished pagination, malformed responses and stale receipts remain explicit.
Matches require exposure review; no matches do not establish complete coverage.

Compiler-plugin coordinate attribution, native test compiler inputs, Native
bundle internals, shaded code and unrehearsed delegated configurations remain
unsupported by this collector. Swift,
Ruby/npm, native behavior, device/release, onboarding, hosted operation and
architecture approval remain independent [retirement gates](bridge-retirement-path.md).
Neither this profile nor advisory collection authorizes adoption or bridge removal.

## Failed-run evidence and discard

Review failed command/control evidence and the retained owned workspace before
`cleanup --discard`. Observer packets are initially stored in the phase-private
Gradle home; if failure prevents the final collector from emitting control
packets, preserve needed raw packets before discarding that workspace. Successful
paired control packets remain replayable after cleanup. Discard is cleanup, not
a general archive of every intermediate file. Never replace a failed result
with a diagnostic replay or a later passing run.

See the [measured assessment](direct-build-input-assessment.md) for the current
tuple, retained failed attempts, advisory findings and independent remaining gates.
