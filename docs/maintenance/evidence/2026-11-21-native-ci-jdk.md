# Native CI JDK selection — 2026-11-21

## Scope and review decision

The four GitHub Mobile CI native jobs currently request Temurin `25`.
[Toolchain qualification](2026-11-21-toolchain-0141-qualification.md) observed
`setup-java@v5` satisfying that request from the image's older `25.0.5+8.0`
tool cache even when repository dependency caches were absent.

This PR selects the reviewed **Temurin 25.0.5.1+2** build through the same
supported action. One workflow constant serves all four native jobs. The
existing CI Java setup also runs `"${JAVA_HOME}/bin/java" -version`, making the
actual selected runtime visible alongside its path. No installer, resolver,
runner or interop adapter is added. Toolchain remains 0.13.0 and the compiler /
exporter remain 2.5.0-RC; the quality-tool JDK is separately pinned to Java 21.

The alternative is `check-latest: true` with the broad `25` request. That follows
new matching patches automatically and can download them before a repository
review. The proposed exact pin favors reproducibility and explicit upgrades;
its maintenance cost is reviewing and updating one constant on later JDK
releases. The action's [documented selection behavior](https://github.com/actions/setup-java/blob/b6effb05e454b25005698d916606bdc6ffcbf961/README.md#check-latest)
supports both choices. Default cache preference stays in place with the exact
pin; no cache deletion or new runtime flags are needed.

## Exact published identity

Adoptium's [official API response](https://api.adoptium.net/v3/assets/feature_releases/25/ga?architecture=aarch64&image_type=jdk&os=mac&jvm_impl=hotspot&vendor=eclipse&page_size=10)
maps release `jdk-25.0.5.1+2` to `version_data.semver`
**`25.0.5+100000002.0.LTS`**. That is the workflow selector, not a handwritten
version conversion. The action consumes this field and compares the full
build metadata for an exact request. A literal four-part Java version is not
valid for its SemVer input.

The [release](https://github.com/adoptium/temurin25-binaries/releases/tag/jdk-25.0.5.1%2B2)
was published **2026-11-18T19:34:09Z**. Its macOS arm64 JDK archive is
136,452,381 bytes, SHA-256
`248353ea41be39d5d2c1c67c7ce0ae4d1668966aacd0c5308464bc1be42f677b`.
The action-downloaded archive matches that digest.

The [seven-day policy](../../../maintenance-policy.json) gives normal
eligibility at **2026-11-25T19:34:09Z**. The maintainer authorized preparation
and qualification of this CI pin on November 21. That does not transfer
Toolchain 0.14.1's qualification waiver into JDK adoption approval. Before
merging early, record an explicit JDK-specific release-age exception; otherwise
wait until eligibility. No dependency-risk acceptance follows from this PR.

## Measured selection controls

The unmodified `setup-java` distribution at commit
`b6effb05e454b25005698d916606bdc6ffcbf961` ran in owned cache/home/temp
directories with real JDK binaries. A copied older JDK seeded the tool cache.

| Actual action request | Observed result |
| --- | --- |
| `25`, older completed cache present | Uses `25.0.5+8-LTS`; no download |
| Exact proposed pin, older cache present | Downloads `25.0.5.1+2-LTS` |
| Repeat exact pin | Reuses `25.0.5.1+2-LTS`; no download |

All commands exited successfully and preserved the older cache. No user tool
cache, installed JDK or ordinary Maven home was changed. Local action probes
used Node 26.5.1; the real hosted action's Node 24 path and native jobs still
need their own evidence. Native qualification results follow after the existing
local gate completes.

## Update and rollback

On Temurin, setup-action, runner-image or JDK-advisory updates, recheck the
vendor release, publication age, CPU/OS scope, package digest and API SemVer
mapping. Review the exact candidate before updating `NATIVE_CI_JAVA_VERSION`.
Repeat older-cache/new-slot/reuse controls and existing native test/build jobs;
record selected `JAVA_HOME` and runtime versions separately from the managed
CLI JRE. This remains a manual review step; the watch does not automatically
discover or adopt CI JDK patches. Existing Android SDK, warning and interop
follow-ups remain active.

Rollback restores the previous workflow constant/references and runtime-report
line as a reviewed revision. Developer JDK selection, retained project JDK
provisioning records and other OS/CPU architectures are outside this slice.
The current arm64 runs do not exercise the advisory's affected x64 CPU path.
