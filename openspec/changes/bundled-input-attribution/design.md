## Context

See proposal.md. The passing upstream pair retained settings-file fingerprints. Baseline Maven artifact bytes account for 183 of 215 files, leaving 32 unmatched. Previous compilation and provider receipts must remain historical, source-bound evidence.

## Goals / Non-Goals

Goals: account for each measured file through independently retrieved Maven bytes or explicit released-distribution/module ownership; repeat verification and advisory collection using repository-owned commands.

Non-goals: filename-derived Maven coordinates, source reproducible-build attestations, shaded-code completeness, dependency adoption, or new native build claims.

## Decisions

Verify the complete distribution archive against the reviewed wrapper pin, then match each measured file's member bytes and settings-classpath membership. Read archives as data without executing or extracting arbitrary members. Independently fetch reviewed Maven artifacts; exact SHA-256 and byte length establish a reference artifact identity, not candidate Maven resolution or a selected variant.

For release-owned files, bind embedded Kotlin module metadata, registered versioned source modules and their module declarations. Record this as source-module correspondence and distribution ownership, with reproducible source-to-binary and embedded third-party code still unproven. Do not manufacture Maven queries for unpublished project modules.

Keep a separate reviewed configuration, producer receipt and report over the original passing rehearsal. Extend the advisory lookup only with independently matched third-party identities. Preserve earlier provider receipts; incomplete transport, changed bytes, missing classpath membership, unrecognized files or mismatched source/configuration remain explicit failures. Temporary downloaded binary data is disposable and cleaned; public-safe digests and source bodies needed for replay survive.

## Risks / Trade-offs

Self-reported embedded metadata → cross-check checksum-pinned release membership and versioned registered module declarations; do not claim reproducible compilation.
Shaded or copied code → explicit separate exposure/coverage gaps, regardless of complete top-level file accounting.
Provider access or artifact mismatch → preserve incomplete evidence and do not reduce query coverage to obtain a passing result.

## Migration Plan

Capture primary sources, implement small collection/replay commands and refusal contracts, execute read-only attribution, refresh advisories, publish the next qualified decision gates. Production stays unchanged; evidence additions are reversible.
