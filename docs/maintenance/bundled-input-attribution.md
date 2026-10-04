# Bundled Toolchain file attribution

This manual follow-up accounts for opaque files from a passing retained-bridge upstream rehearsal. It uses public primary artifacts and repository-owned commands; no private service, AI tool or credentials are required. Production wrappers, dependencies and SDK declarations remain unchanged.

`maintenance-bundled-inputs.json` reviews Toolchain 0.13.0, nine independent Maven reference artifacts and 23 source-module correspondences. Future distribution shapes or versions need a reviewed configuration and compatible parser; filenames alone cannot supply coordinates.

```sh
./scripts/dev/dependency_updates.sh attribute-bundled RUN_ID --store upstream-remediation
./scripts/dev/dependency_updates.sh review-bundled-advisories RUN_ID --store upstream-remediation
./scripts/dev/dependency_updates.sh bundled-report RUN_ID --store upstream-remediation
```

Before comparison, refresh the baseline with the existing `review-advisories RUN_ID --phase baseline` command and the same store. `attribute-bundled` verifies the original passing pair, candidate version, selected producer identities and reviewed configuration. It downloads the distribution through HTTPS-only redirects, verifies its pinned archive checksum, and compares all measured settings-file bytes and classpath membership. Archive entries are read as data; only reviewed source-module JARs are copied into owned temporary storage for `/usr/bin/unzip -p` metadata inspection. No distribution code executes.

Independent Maven artifacts must match SHA-256 and byte length exactly. Source-module correspondence requires checksum-pinned distribution membership, reviewed embedded Kotlin module metadata, a registered versioned project module and its declaration. That evidence establishes release membership and source correspondence; reproducible source-to-binary compilation and embedded third-party code remain unproven. The 23 project modules do not acquire invented Maven coordinates.

The producer binds original run/result/source identities, current reviewed configuration and derivation code hashes. Collection checkpoints remain incomplete on transport or byte/source failures. Normal failure, timeout and interruption unwind owned temporary storage; retained producer receipts survive. Changed configuration, incomplete cleanup, missing or extra artifacts, classpath mismatches and altered metadata refuse replay. Repeating collection archives earlier producer/provider receipts; the original compilation and advisory receipts remain separate. Partial OSV responses cannot become a clean lookup by omitting records.

The public report uses `measured_file_identities_accounted_for` for this bounded scope. It neither labels the whole dependency surface secure nor grants adoption. Full provider records and exact lookup bindings remain subject to freshness and triage. The [measured assessment](bundled-input-assessment.md) explains the restored KAPT finding and remaining adoption gates.

The collector uses the existing pinned Ruby runtime, `/usr/bin/curl`, `/usr/bin/unzip` and Git. Contract fixtures also use `/usr/bin/zip`. Execution was verified on macOS; Linux execution remains unverified. No schedule, automatic SDK migration or adoption command is added.
