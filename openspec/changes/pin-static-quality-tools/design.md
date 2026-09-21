## Context

See the proposal and the completed static-input slice. Existing analyzer versions
pass the repository, but Homebrew installation and PATH selection float. Ruby is
already declared as 4.0.6. The quality runtime must not change native build jobs.

## Goals / Non-Goals

**Goals:** Reviewed artifact and rule identities; repeatable explicit setup;
offline rejection of incomplete, corrupt or mismatched installations.

**Non-Goals:** New lint policy, mobile dependency adoption, native build runtime
changes, a hermetic operating-system image, new schedules or a general package
manager. Xcode/SDK and OS utilities remain declared host prerequisites.

## Decisions

- Keep reviewed analyzer versions from slice 1 after checking primary releases,
  artifact availability and age. Pin Ruby 4.0.6 and a quality-only Temurin 21.0.11
  runtime. Lock release URLs, SHA-256 digests and current rule-file hashes in JSON.
- Install beneath ignored `.quality/`, in a versioned slot bound to the lock.
  The separate bootstrap owns downloads, archive extraction and Ruby compilation.
  Use system Ruby only as the bootstrap/verification launcher on supported macOS.
  The gate itself runs under the verified pinned Ruby and never installs anything.
- Build Ruby from the official checksummed source with a pinned static libyaml,
  without optional JIT/OpenSSL/readline/GMP integration. It is a private quality
  runtime, not the application's Bundler/Fastlane runtime. Prebuilt CI Ruby embeds
  hosted-runner paths and failed relocation, so it is unsuitable for this local
  installation. The existing `.ruby-version` does not change.
  Enable Ruby's relative load paths so cached/copied installations resolve their
  own standard library. Recipe 2 invalidates the initial nonrelocatable probe.
- Invoke Kotlin analyzers as verified JARs under the private Java runtime and
  native analyzers by absolute managed paths. PATH tools cannot shadow them.
  Verify an installation receipt's complete file tree and exact reported versions;
  match the receipt to the lock and reject changed rule configuration.
- Publish a completion receipt only after verification. Use an exclusive install
  lock and temporary build/download directories; fail closed on concurrent or
  interrupted installation. Preserve valid prior slots and provide explicit
  repair of the selected owned slot. Network/checksum failure never publishes a
  usable install. Caches are optional and are reverified.
- Retain the existing CI job and bootstrap command. Put behavior in repository
  scripts, cache only the owned store by lock/recipe/OS identity, and run contracts
  alongside the gate. Do not alter native or release workflow paths.

## Risks / Trade-offs

- Source compilation adds cold setup cost → cache the verified installation and
  report measured setup time separately from steady-state gate time.
- Host compiler/SDK differences affect built Ruby bytes → receipt the built tree;
  claim exact source/runtime versions, not identical binaries across machines.
- Native Intel execution may be unavailable locally → provide upstream artifacts
  where verified and distinguish simulated routing from native execution evidence.
- External source archives are executable supply-chain inputs → pin hashes before
  extraction/build, require HTTPS, retain source-bound evidence and never resolve
  a floating release during bootstrap.

## Migration Plan

Run the explicit installer once, then use existing lint/check/format commands.
Wrong-version global tools do not satisfy the lock. Restore the prior reviewed
lock and rerun setup to roll back; no global uninstall is required. Validate an
empty-store install, offline reuse, failure/repair fixtures and the existing gate.
