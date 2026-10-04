# Bridge removal validation

Local validation passed. The [initial source-bound receipt](evidence/2026-10-04-bridge-removal-local.json)
retains its capture-time status; the [final normal-hook receipt](evidence/2026-10-04-bridge-removal-native.json)
records both complete native gates and the unchanged operational source between them.
The [scoped risk receipt](evidence/2026-10-04-bridge-removal-risk.json) binds all 168 current
risk inputs without extending the expiry or claiming advisory remediation.

Validation covers 289 contracts in 18 suites, five static analyzers, 38 Android/shared
tests, twelve original Swift cases, both debug builds and paired unsigned simulator
Release/device archives. Native source bytes/modes, public identity, typed visitor
symbols and compiled native assets were preserved. A prepared-host clean clone
passed Android/shared tests. Independent plugin bootstrap passed both phases,
replay and owned cleanup. Full recovery rebuilt all four native jobs from retained
revision `349e07e0929033e8feb71269e9555420d3285e35`, preserving 570 tracked paths.

The [hosted receipt](evidence/2026-10-04-bridge-removal-hosted.json) records passing PR run 37233143062 and Nightly run 37231981662, including all job identities, twelve original Swift cases, artifact digests and source bindings.

[PR #36](https://github.com/Mekate-Studio/Mobi/pull/36) records the final hosted
PR run, its exact source revision and job outcomes before being marked ready.
[Nightly run 37231981662](https://github.com/Mekate-Studio/Mobi/actions/runs/37231981662)
uses implementation revision `3e1b7c40ca87f50e60683a22bbfce1e41827c82f`.
Later evidence/documentation commits preserve that operational source; hosted
completion must be verified independently from local success. Superseded run
37231901460 was cancelled by a newer push and does not supply a passing PR gate.
Hosted results are recorded in the PR to avoid a receipt-only push invalidating
the very final revision being checked. The source/API scope and complete-content
recovery policy are defined in the [removal record](bridge-removal.md).

Physical device, exact-floor runtime, broad Compose resources/lifecycle,
empty-host/license onboarding, hosted unsigned device archive and signed/export
remain separate unmeasured scopes. Risk expiry remains 2026-11-03T05:48:38Z.
Merge remains the maintainer's decision. Swift export assessment follows separately
after removal review and merge.
