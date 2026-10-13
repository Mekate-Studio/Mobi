# Swift export pilot cohort audit

Status: source audit of pilot wiring; bounded local runtime overlap controls passed.
See the [pilot evidence](swift-export-app-pilot-evidence.md) and the separate
[native-first qualification stage](swift-export-native-qualification.md).
Accountable maintainer: Jorge Castro. Initial pilot: `coroutine-swift5` and
`main-confined`; production policy remains unselected.

The shared state algebra and business policies remain in Home and Nearby shared
feature modules. The pilot adds wire values and native lifetime handling without
changing those states or putting TCA types into shared Kotlin.

| Source / caller | Instance boundary | Access policy |
| --- | --- | --- |
| `shared-ios-export/src/AppComposition.kt` | One private Metro graph per app root | Resolves Home and Nearby once; does not expose graph or raw Nearby delegate |
| `shared-ios-export/src/NearbyFacade.kt` hub | Exact repository resolved by that root | One private service/wrapper and cohort mutex; Main entry and final resumption checks for confined policy |
| Native Nearby route owners and `NativeNearbyAccess.swift` | Every owner from that root's hub | Raw facade calls Main; immutable copied native payloads before await; owner-fenced handles |
| `NearbyVehicleMapFeatureService.refreshSnapshot` | Hub's private service | Single wrapped fetch; no raw repository escapes |
| Native Home owners | Root's exact Home service | Separate Home facades, Main registry; not Nearby callers |
| Optional shared Home route | Same Home service | Separate route/job reservations; no Nearby feature in Compose |
| `SharedDependencies.createDefaultGraph` / default service factories | Separate graph per call | Shipping pilot calls only from its private root; default direct and tests remain separate cohorts |
| Android app graph and core/feature tests | Separate process/graph instances | Outside this iOS cohort; no Android qualification inferred |

The actual simulated Nearby implementation delays before selecting a template
and incrementing `nextSnapshotIndex`. Under Main, suspended requests can overlap,
but its index read/increment/return section has no suspension and is sequential
on Main. This is a source observation, not proof for future repository changes.
Local cancellation and overlapping-owner controls passed for the recorded
source/tool tuple. They do not qualify future repository changes or other hosts.

The mutex alternative holds one hub mutex across delegate suspension and return
on Default. Per-owner locks cannot replace it. A noncooperative delegate can
block peers; neither policy establishes fairness or a hard completion deadline.
Any new graph accessor, raw delegate consumer, background Kotlin caller or Compose
Nearby route requires a new caller/instance audit before pilot qualification.
