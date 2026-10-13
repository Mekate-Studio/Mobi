# Swift export follow-ups

Status: deferred follow-up work. Accountable maintainer: Jorge Castro.

The immediate next step is a separate OpenSpec proposal for an opt-in app adoption
pilot, using the [adoption handoff](swift-export-adoption-plan.md). The following
items should be revisited with dependency maintenance and architecture archiving.

## Dependency maintenance

Include Swift export in the existing discover → assess → rehearse → review → adopt
workflow whenever dependency maintenance resumes. Use the workflow's existing
review cadence; this note does not establish a new scheduled job.

Assess new exporter and Kotlin Toolchain versions together with the affected
Kotlin, coroutines, Compose, Metro, Swift/Xcode/SDK and native macro dependencies.
Review breaking changes, new APIs, supported integration paths and opportunities
to replace custom producer or facade code with upstream capabilities.

Keep Swift 6 language mode for every module as an explicit assessment goal.
Rehearse a strict Swift 6 profile when upstream changes make it viable, comparing
it against the qualified profiles. Retain the possibility of a compiled Swift 5
support module consumed from Swift 6 while it remains useful. Neither a newer
version nor fewer warnings alone establishes compatibility or risk acceptance.

Bind results to the source and complete dependency/compiler tuple. Repeat the
affected cold production, guarded post-cleanup replay and integrated app checks;
review diagnostic fingerprints, cancellation, lifetime, resources and repository
concurrency. Preserve incomplete discovery and failed rehearsals as evidence.
Keep adoption decisions explicit and operational behavior in repo-owned scripts.

## Architecture decision history

Refine the archive process into a public, linked account of the architecture
decisions: retained-bridge assessments, direct Kotlin projections, retirement of
the hand-maintained iOS Gradle bridge, native macro repair, optional Swift export
qualification, the app adoption pilot and eventual full Kotlin Toolchain adoption.

Keep these decisions and their evidence distinct within that coherent story.
Record the problem, alternatives, selected scope, trade-offs, evidence limits,
maintainer, rollback and remaining adoption gates for each decision. Clearly
distinguish proposals, implemented candidates, measured behavior and approved
adoption; eventual full Toolchain adoption is a goal, not a completed outcome.

Before archiving, promote durable evidence summaries and cross-references into
the repository so the reference remains useful without ignored local build
products. Preserve provenance for failed and inconclusive attempts as well as
successful runs. Link the relevant OpenSpec changes and architecture decisions,
and retain a complete rollback snapshot that includes approved dependency repairs.

Archive changes only through their completion/review process. This follow-up note
does not archive a change or select a production builder, language profile,
repository policy, runtime budget or diagnostic risk disposition.
