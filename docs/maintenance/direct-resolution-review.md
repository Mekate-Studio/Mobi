# Direct resolution and advisory review

`direct-resolution` is a manual graph-only compatibility profile. It reuses the
paired executor and typed-facade transformation. The candidate has no bridge in
its owned build copy; production remains on the Gradle builder.

```sh
./scripts/dev/dependency_updates.sh prepare-kotlin
./scripts/dev/dependency_updates.sh rehearse-compatibility direct-resolution --store direct-resolution
./scripts/dev/dependency_updates.sh compatibility-report RUN_ID --store direct-resolution
./scripts/dev/dependency_updates.sh review-advisories RUN_ID --store direct-resolution
./scripts/dev/dependency_updates.sh recover RUN_ID --store direct-resolution
./scripts/dev/dependency_updates.sh cleanup RUN_ID --apply --discard --store direct-resolution
./scripts/dev/dependency_updates.sh compatibility-report RUN_ID --store direct-resolution
```

Use the matching store throughout. The existing Apple Silicon host prerequisites
apply; this profile creates no simulator and runs no application or native tests.
A graph pass retains those gaps, even when an earlier round-trip profile passed.
The production tuple, native targets, Swift adapters, tests and release defaults
are preserved in the caller.

Both phases retain effective settings and all-module/test dependency output.
Reporting verifies file hashes, declaration hashes against authored manifests,
module coverage and every declared platform's main/test compile/runtime roots,
and reparses the raw dependencies log. Selected versions and printed edges are
retained; repeated branches are not expanded by inference. Missing or unresolved
scopes refuse. Downloaded files have relative-path hashes and sizes, but these
fingerprints do not establish exact graph-to-artifact attribution or a complete
compiler/plugin, Kotlin/Native or delegated Android build graph.

The report emits exact selected Maven package/version queries. Supported
`@aar`, `@jar` and `@klib` suffixes are normalized with receipts; constraint
nodes are excluded. `review-advisories` submits candidate queries in batches of
100 to the public [OSV API](https://google.github.io/osv.dev/post-v1-querybatch/)
and fetches every returned finding's full record. No account or credentials are
required. Requests, raw responses, hashes, HTTP status and retrieval timestamps
are retained in `advisory-review.json` inside the owned run. Repeated collections
archive the previous packet by digest. The final compatibility report recomputes
the review rather than trusting a stored success summary.

A complete exact-input lookup with no matches is `provider_complete`; matches
are `triage_required`. Neither means complete dependency coverage or adoption
approval. Failed requests, malformed/cardinality-mismatched responses, missing
records, unfinished pagination and evidence older than 24 hours are `incomplete`.
Pagination is currently detected and retained, requiring a follow-up collector
extension if encountered; it is never silently truncated. Exit 2 signals findings
or incomplete evidence; malformed/binding failures refuse. Network timeouts are
bounded per request and partial packets remain available after normal collection.

The broader advisory gate remains open for compiler/plugin graphs, delegated
Android internals, shaded code, Native bundles and Swift/Ruby/npm dependencies.
This graph-only profile does not verify the Kotlin Gradle-plugin lead. The
separate [build-input assessment](direct-build-input-assessment.md) now proves
selected delegated 2.2.10 and reports fresh build-tool matches requiring triage. Human review must assess actual selection and exposure before any
retirement or adoption decision. Existing bridge-review evidence remains on its
own track. See the [retirement path](bridge-retirement-path.md) for the independent
native behavior, onboarding, hosted CI, release and approval gates.
