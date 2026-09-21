# Second slice: pinned static-quality tools

Status: implemented and locally validated, 2026-09-20. Base: `d93cf03`.
The first slice is committed; this document describes the next focused change,
`pin-static-quality-tools`. Native dependencies, Kotlin Toolchain, the iOS
bridge, release defaults and schedules are outside this change.

## Implemented contract

[`quality-tools.json`](../../quality-tools.json) records exact versions, primary
artifact URLs, SHA-256 digests, platform-specific entries and existing rule hashes.
[`quality_tools.rb`](../../scripts/quality_tools.rb) owns explicit setup and
offline verification. Existing lint, format, hook and CI entry points share it.
No package resolution, Homebrew install, update lookup or network fallback occurs
inside the gate. Manifest-only inspection still needs no installed analyzers.

Setup downloads into temporary owned storage, verifies bytes before extraction,
builds a private Ruby, checks versions, and publishes a completion receipt. The
receipt records every installed file's hash/executable bit or internal symlink
target. Every gate checks that tree, exact reported versions and rule hashes
before invoking analyzers by absolute path. Ruby/Java injection variables are
cleared. ShellCheck ignores personal rc files; undeclared nested rule files,
including ignored files, fail explicitly.

The exclusive setup lock rejects concurrent installers. Failed or interrupted
setup removes its temporary files and any incomplete published slot. A hard kill
can leave scratch files; leftovers without a valid receipt cannot satisfy the gate. `--repair` explicitly
rebuilds only the selected marked slot and refuses unowned/symlinked stores.
Repair removes that slot first, so failure can leave quality checks unavailable.
Older slots remain for rollback. See [local recovery and cleanup](../reference/local-development.md#static-gate-inputs-and-recovery).

The existing CI quality job installs or verifies the lock, runs contract tests,
then calls the existing `quality-check` job. Its optional cache is keyed by OS,
architecture, runner image family, lock and installer content. Restored cache
contents are reverified. No native or release job changes.

## Source selection, checked 2026-09-20

All selected versions were older than seven days at review. This is a reviewed
baseline, not a claim that every pinned component is newest or vulnerability-free.
Artifact digests are in the lock; the [evidence record](evidence/2026-09-20-slice-2.json)
binds the lock and implementation to measured checks.

| Component | Selected identity and primary evidence | Decision and limit |
| --- | --- | --- |
| ktlint | [1.8.0 release](https://github.com/ktlint/ktlint/releases/tag/1.8.0), 2025-11-14; executable JAR asset, GitHub release-asset SHA-256 | Retain slice 1's version; run its JAR under private Java. No Kotlin compiler adoption |
| detekt | [1.23.8 release](https://github.com/detekt/detekt/releases/tag/v1.23.8), 2025-02-21; [Maven Central SHA-256](https://repo.maven.apache.org/maven2/io/gitlab/arturbosch/detekt/detekt-cli/1.23.8/detekt-cli-1.23.8-all.jar.sha256) | Select the Maven fat JAR. The GitHub fat JAR has different bytes; its hash is not interchangeable. [Compatibility docs](https://detekt.dev/docs/1.23.8/introduction/compatibility/) list Kotlin 2.0.21 and JDK 21; current CLI checks remain without type resolution |
| SwiftFormat | [0.62.1 release](https://github.com/nicklockwood/SwiftFormat/releases/tag/0.62.1), 2026-07-07; universal binary ZIP and release-asset SHA-256 | Retain existing version/configuration; no app Swift migration |
| SwiftLint | [0.65.0 release](https://github.com/realm/SwiftLint/releases/tag/0.65.0), 2026-06-27; portable ZIP and release-asset SHA-256 | Retain existing rules; Xcode/SourceKit remains a host dependency |
| ShellCheck | [0.11.0 release](https://github.com/koalaman/shellcheck/releases/tag/v0.11.0), 2025-08-04; separate Darwin arm64/x86_64 archives and release-asset SHA-256 | Retain existing checks; explicitly ignore external rc configuration |
| Ruby | [4.0.6 source and published SHA-256](https://www.ruby-lang.org/en/news/2026/07/14/ruby-4-0-6-released/), 2026-07-14 | Preserve `.ruby-version`; compile a private quality-only runtime. Bundler/Fastlane remain separate |
| libyaml | [0.2.5 release](https://github.com/yaml/libyaml/releases/tag/0.2.5), 2020-06-01; [official release tarball](https://pyyaml.org/download/libyaml/yaml-0.2.5.tar.gz) | Static Ruby YAML dependency. SHA-256 is the observed official download hash, not a separately signed attestation; GitHub's generated source archive is a different artifact |
| Java | [Temurin 21.0.11+10](https://github.com/adoptium/temurin21-binaries/releases/tag/jdk-21.0.11%2B10), 2026-04-23; Darwin arm64/x64 assets and release-asset SHA-256 | Quality-only JDK with exact runtime/vendor checks; native Java defaults remain unchanged |

GitHub release metadata was obtained from each repository's public release API
at the linked exact tag. Setup uses locked URLs/hashes directly and never queries
"latest". The Ruby 4.0.7 release dated September 15 is younger than seven days at
review and does not justify changing this baseline. No advisory inventory was
performed in this slice; that remains explicit work in slice 4.

The prebuilt Ruby from `ruby/ruby-builder` was rejected after a relocation probe
failed with hosted-runner library paths. [Upstream guidance](https://github.com/ruby/setup-ruby#using-self-hosted-runners)
also describes the embedded installation prefix. Building Ruby initially fixed
dynamic-library linkage but still left absolute standard-library load paths.
Recipe 2 enables relative loading and stages Ruby under a private prefix. The
real-tool fixture checks that a copied runtime loads YAML/JSON and other required
libraries without using the original installation.

Ruby's optional JIT, DTrace, OpenSSL, readline extension and GMP integration are
disabled. libyaml is static. This limits dependencies of the quality runtime;
it is not a replacement for a general Ruby development installation. Installation
uses the Apple compiler and source-bundled gems, with no Bundler operation.

## Verified locally

| Probe | Observed result |
| --- | --- |
| Fresh selected slot, direct primary downloads and source build | All seven runtime/analyzer versions verified; 108.13 seconds wall time. No Homebrew, global tool replacement or Bundler operation |
| Repeat explicit setup with network-restricted execution | Verified the same store offline in 1.12 seconds; fixture independently asserts the build/download path is never called |
| Repository `./scripts/ci/run_job.sh quality-check` | Passed: 39 ktlint, 36 detekt, 24 Swift and 43 shell inputs; 5.443 seconds inside the runner, 6.84 seconds including launcher verification |
| Complete source snapshot in a disposable Git repository | Staged all snapshot files and ran `./scripts/dev/check.sh` with the copied private tool store; commit guard and all analyzers passed in 6.579 seconds inside the runner |
| `test_quality.rb` | 35 contracts passed under system Ruby 2.6.10 and again under the private Ruby 4.0.6 |
| `test_quality_real.rb` | Six probe groups passed: valid baseline; manual/staged Kotlin formatting failure and repair; Swift package lint failure and repair; new module/platform detekt failure and repair; hook ShellCheck failure and repair; unusual filenames |
| Runtime relocation | Copied store passed file/version verification and required-library loading without the original prefix appearing in load paths or loaded features; copied Ruby ran real commit-mode checks |
| Ruby dynamic linkage | `otool -L` reports Apple system libraries/frameworks only for the Ruby executable |
| Static review | Ruby syntax, whitespace validation and strict OpenSpec validation passed |

The contract suite covers missing tools, byte corruption, version/runtime mismatch,
rule drift, PATH shadowing, concurrent setup, incomplete receipt, explicit repair,
checksum failure, simulated network failure/interruption, ownership refusal and
installation-free inventory. These fixtures complement real analyzer checks.
Timings are local observations, not universal budgets. Temporary source/fixture
copies are removed; the verified ignored installation remains for normal use.

## Untested assumptions and blockers

- The local host is Apple Silicon, macOS 27.0 / Xcode 27.0. A fresh hosted
  `macos-26` run remains unexecuted; it must validate source compilation, cache
  reuse and SourceKit behavior before hosted compatibility is claimed.
- Intel artifact URLs and upstream digests are locked, but no native Intel Mac
  execution was available. Linux/Windows quality setup is unsupported and fails
  explicitly; mobile support policy is unchanged.
- Apple compiler/SDK/system Ruby/Git/Bash/curl/tar/unzip and local receipt storage
  are trusted prerequisites. Source checksums and exact versions do not make
  compiled Ruby bytes identical across hosts, authenticate a malicious local
  receipt rewrite, or freeze Xcode/SourceKit behavior.
- Failure fixtures simulate transport failure/interruption. They do not claim
  testing every network outage, disk-full state, forced kill or archive exploit.
- This change proves static checks only. It adds no native test, compiler-plugin,
  release-package or direct Toolchain bridge-retirement evidence. All prior
  compatibility blockers remain open.

Next integration: review this lock/setup change and run its existing hosted
quality job. Slice 3 remains the separate conservative validation-selector and
non-mutating test-preparation change.
