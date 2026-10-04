# Compiler plugin attribution

This manual follow-up binds an existing successful `direct-build-inputs` pair to
fresh independent plugin resolution. It does not rerun compilation or imply
that the caller's newer source has compiled. The original compiler run and the
new resolver run retain separate source, code, command and result identities.

```bash
./scripts/dev/dependency_updates.sh rehearse-plugin-attribution BUILD_RUN_ID --store direct-build-inputs
./scripts/dev/dependency_updates.sh plugin-report ATTRIBUTION_RUN_ID --store direct-build-inputs
./scripts/dev/dependency_updates.sh review-advisories ATTRIBUTION_RUN_ID --store direct-build-inputs
./scripts/dev/dependency_updates.sh recover ATTRIBUTION_RUN_ID --store direct-build-inputs
./scripts/dev/dependency_updates.sh cleanup ATTRIBUTION_RUN_ID --apply --discard --store direct-build-inputs
./scripts/dev/dependency_updates.sh plugin-report ATTRIBUTION_RUN_ID --store direct-build-inputs
```

Use the same owned store as the original build proof. Prerequisites are the
pinned repository Ruby, JDK 21 discoverable with macOS `java_home`, and public
Gradle/Maven/OSV network access. This adapter follows the current Apple Silicon
Mobi assessment environment. It requires no Codex service, private account or
scheduled job. The common executor and dormant Elixir adapter remain separate.

`maintenance-plugin-resolution.json` pins the reviewed Toolchain plugin mapping
and the independent Gradle distribution checksum. Explicit roots come from the
original verified effective settings; Compose uses the versioned upstream
mapping and effective Kotlin version. The resolver runs separately per root,
with JVM runtime attributes and Maven Central, in each owned phase. Its graphs
retain requested roots, selected components, variants, edges and artifact hashes.
The upstream filename filter for embeddable compiler artifacts is explicit in
excluded-artifact evidence; filenames never assign a selected file's coordinate.

Every measured compiler path must match one unique selected component/variant
by SHA-256 and byte size. Every invocation must have exactly the retained artifact
set for its configured roots. Unresolved graphs, changed roots, missing/extra
files, ambiguity, unsupported platform-specific configurations or producer drift
refuse attribution. Resolver infrastructure failure is inconclusive. A failed
baseline does not run a candidate. Failed control packets and command logs remain;
recovery and explicit cleanup use the existing owned resource controls, including
tagged JVMs and private Gradle registry/distribution identity.

`plugin-report` verifies the old producers again and replays both graph joins
before accepting the summaries. It works after disposable source/cache cleanup.
Keep the original compiler run's control evidence: losing it prevents replay.
This is integrity binding, not a signature or protection against a party rewriting
all local receipts. Provider evidence expires after 24 hours; rerunning
`review-advisories` archives the previous packet by digest. Findings return
`triage_required` and exit 2; provider errors/pagination return `incomplete`.
Neither transport success nor attributed components authorize adoption.

Coverage is the selected inputs of the retained compiler invocations. Shaded
classes, Native distribution contents, unmeasured Native test invocations,
all module/artifact joins, delegated uncollected variants and other ecosystems
remain gaps. Future root/repository changes require review of the adapter and a
fresh compiler proof. Continue the independent
[retirement gates](bridge-retirement-path.md) and
[advisory exposure review](direct-advisory-triage.md).
