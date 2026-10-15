import Foundation
import KotlinModules
import MobiAppComposition
import MobiIOSDependencies

private typealias Composition = ExportedKotlinPackages.studio.mekate.mobi.export.composition

@MainActor final class AppServices {
    private let composition: Composition.AppComposition
    let supervisor = DrainSupervisor()
    let admission: AdmissionPool
    private var homeOwners: [WeakOwner<HomeStoreOwner>] = []
    private var nearbyOwners: [WeakOwner<NearbyStoreOwner>] = []
    lazy var shutdown = ShutdownCoordinator(pool: admission, native: supervisor, composeActive: { [weak self] in
        #if MOBI_PILOT_COMPOSE
            return self?.composeSupervisor.active ?? 0
        #else
            return 0
        #endif
    })
    #if MOBI_PILOT_COMPOSE
        let composeSupervisor = ComposeDrainSupervisor()
        private var composeOwners: [WeakOwner<AdmittedComposeOwner>] = []
    #endif

    init(settings: PilotRuntimeSettings = .current) {
        admission = AdmissionPool(capacity: settings.parentReservations)
        composition = Composition.AppComposition(
            policy: settings.repositoryPolicy == "main-confined" ? 0 : 1,
            nativeJobsPerOwner: settings.nativeJobsPerOwner,
        )
    }

    func makeHomeOwner() -> HomeStoreOwner {
        let owner = HomeStoreOwner(access: NativeHomeAccess(
            facade: composition.makeHomeFacade(),
            supervisor: supervisor,
            admission: admission,
        ))
        homeOwners.removeAll { $0.value == nil }
        homeOwners.append(WeakOwner(owner))
        return owner
    }

    func makeNearbyOwner() -> NearbyStoreOwner {
        let owner = NearbyStoreOwner(access: NativeNearbyAccess(
            hub: composition.nearbyHub,
            supervisor: supervisor,
            admission: admission,
        ))
        nearbyOwners.removeAll { $0.value == nil }
        nearbyOwners.append(WeakOwner(owner))
        return owner
    }

    func repositoryObservation() -> NearbyCohortObservation {
        let metrics = composition.nearbyHub.metrics()
        return NearbyCohortObservation(
            entered: metrics.entered,
            active: metrics.active,
            maximum: metrics.maxActive,
            returned: metrics.returned,
        )
    }

    func ownsHomeService(_ owner: HomeStoreOwner) -> Bool {
        owner.access.usesService(composition.homeService)
    }

    #if MOBI_PILOT_COMPOSE
        func ownsSharedHomeService(_ owner: AdmittedComposeOwner) -> Bool {
            owner.owner.usesService(other: composition.homeService)
        }
    #endif

    func closeAdmission() {
        admission.close()
    }

    func retire() {
        closeAdmission()
        homeOwners.forEach { $0.value?.retire() }
        nearbyOwners.forEach { $0.value?.retire() }
        homeOwners.removeAll()
        nearbyOwners.removeAll()
        #if MOBI_PILOT_COMPOSE
            composeOwners.forEach { _ = $0.value?.retire() }
            composeOwners.removeAll()
        #endif
    }

    #if MOBI_PILOT_COMPOSE
        func makeSharedHomeOwner() throws -> AdmittedComposeOwner {
            let reservation = try admission.reserve(.composeRoute)
            let owner = SharedUIOwner.HomeRouteOwner(
                service: composition.homeService,
                maxJobs: PilotRuntimeSettings.current.composeJobsPerOwner,
            )
            let admitted = AdmittedComposeOwner(owner: owner, reservation: reservation, supervisor: composeSupervisor)
            composeOwners.removeAll { $0.value == nil }
            composeOwners.append(WeakOwner(admitted))
            return admitted
        }
    #endif
}

@MainActor final class HomeStoreOwner {
    let store: StoreOf<HomeFeature>
    let access: NativeHomeAccess
    private let relay = CancellationRelay()
    init(access: NativeHomeAccess) {
        self.access = access
        let client = HomeFeatureClient(access: access, relay: relay)
        let store = Store(initialState: HomeFeature.State()) { HomeFeature().dependency(\.homeFeatureClient, client) }
        self.store = store
        relay.sink = { [weak store] request in _ = store?.send(.cancelled(request)) }
    }

    func retire() {
        store.send(.retire)
    }
}

@MainActor final class NearbyStoreOwner {
    let store: StoreOf<NearbyVehicleMapFeature>
    let access: NativeNearbyAccess
    private let relay = CancellationRelay()
    init(access: NativeNearbyAccess) {
        self.access = access
        let client = NearbyVehicleMapFeatureClient(access: access, relay: relay)
        let store = Store(initialState: NearbyVehicleMapFeature.State()) { NearbyVehicleMapFeature().dependency(
            \.nearbyVehicleMapFeatureClient,
            client,
        ) }
        self.store = store
        relay.sink = { [weak store] request in _ = store?.send(.cancelled(request)) }
    }

    func retire() {
        store.send(.retire)
    }
}

@MainActor private final class WeakOwner<Owner: AnyObject> {
    weak var value: Owner?
    init(_ value: Owner) {
        self.value = value
    }
}

struct NearbyCohortObservation: Sendable {
    let entered: Int32
    let active: Int32
    let maximum: Int32
    let returned: Int32
}
