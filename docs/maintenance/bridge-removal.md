# Physical iOS Gradle bridge removal

Status and final execution receipts: [validation record](bridge-removal-validation.md). Merge remains the maintainer’s decision.

The maintainer explicitly requested physical removal after merging PR #35.
This change is based on `2cc75fd6df31a3470fc9248847b37e7c649ddd53` and preserves
the approved visitor/projection API and development/test/unsigned scope.
Signed archive/export/TestFlight remains held. The 17 inherited findings
(2 Critical, 8 High, 7 Moderate) retain expiry **2026-11-03T05:48:38Z**.
Deletion does not remediate them or extend acceptance.

## Input and caller audit

The [input receipt](evidence/2026-10-04-bridge-removal-audit.json) captures all
eleven deleted paths, SHA-256 hashes and executable modes. The bridge build,
settings, wrapper and root catalog were iOS bridge inputs. The duplicate root
wrapper JAR has no repository bootstrap caller. Android delegated Toolchain
Gradle/AGP builds use generated projects and the unchanged repo-owned
`ensure_android_gradle_distribution.sh` bootstrap.

Independent plugin attribution previously borrowed the bridge wrapper. It now
downloads its separately pinned Gradle distribution into its owned cache,
verifies the configured checksum and invokes that distribution. Historical
catalog/parser and transform/restoration contracts use explicitly scoped
nonfunctional sentinels; they are never native validation inputs.

Current compatibility baseline verification uses direct module Metro declarations.
Generic Kotlin/support rehearsals select the builder from the complete source and
record a direct scope when the bridge is absent. Bridge and old transform profiles
refuse on current source with complete-revision
recovery guidance. Direct mobile/resolution/build-input and unsigned iOS Release/archive profiles use the adopted
content with bridge inputs absent. Scheduled watch has a separate direct scope
and does not discover retired SKIE releases. Workflow cache keys omit removed
inputs; conservative unknown-path build classification remains fail-open.

Ignored bridge products in the caller checkout were preserved by moving their
remaining directory under `.maintenance/bridge-removal-20261004/`; no unrelated
stash or backup was changed. Removal validation uses owned source copies with
these paths physically absent.

## Recovery

Prior direct-default content including bridge files is completely recoverable at
`2cc75fd6df31a3470fc9248847b37e7c649ddd53`. Retained Gradle/SKIE consumer content
is completely recoverable at `349e07e0929033e8feb71269e9555420d3285e35`.
Use a new owned checkout/archive of the chosen complete revision, verify its
tracked file bytes and executable modes, and rerun native consumers using its
repo-owned gate. Returning to SKIE requires full content restoration, including
Swift consumers and integration phases; an environment variable is insufficient.
Stop only owned work and clean only positively owned incompatible products.
Keep unrelated caller source/index and saved stashes intact.

## Evidence and open gates

The [local receipt](evidence/2026-10-04-bridge-removal-local.json) records 289
contracts, five analyzers, all four native jobs, paired unsigned simulator Release
and ARM64 device archives, product inspection, independent plugin bootstrap and
rebuilt retained-content recovery. It preserves source-bound producer distinctions.
The prepared-host local Git clone also passed all 38 Android/shared tests with
fresh wrapper/generated-Gradle caches and removed inputs absent. Its revision and
limits remain explicit; it does not prove empty-host/license onboarding.

The [validation record](bridge-removal-validation.md) records the final normal
hook and hosted PR/Nightly outcomes separately. Earlier green default-integration
runs validate their recorded source, not this removal. Physical-device,
exact-minimum runtime, broad resource/lifecycle coverage, empty-host/license
onboarding, hosted unsigned device archive and signed/export remain separate
unmeasured scopes. Swift export assessment is a separate follow-on after removal
review/merge.
