import MobiIOSDependencies
import KotlinModules

@MainActor
struct AppServices {
    let homeFeatureClient: HomeFeatureClient
    let nearbyVehicleMapFeatureClient: NearbyVehicleMapFeatureClient
    let sharedHomeViewControllerFactory: SharedHomeViewControllerFactory

    init(
        homeFeatureService: HomeFeatureService = SharedDependencies.shared.createDefaultHomeFeatureService(),
        nearbyVehicleMapFeatureService: NearbyVehicleMapFeatureService = SharedDependencies.shared
            .createDefaultNearbyVehicleMapFeatureService(),
    ) {
        homeFeatureClient = HomeFeatureClient(service: homeFeatureService)
        nearbyVehicleMapFeatureClient = NearbyVehicleMapFeatureClient(service: nearbyVehicleMapFeatureService)
        sharedHomeViewControllerFactory = SharedHomeViewControllerFactory(
            service: homeFeatureService,
        )
    }

    func makeHomeStore() -> StoreOf<HomeFeature> {
        Store(
            initialState: HomeFeature.State(),
            reducer: {
                HomeFeature()
            },
            withDependencies: {
                $0.homeFeatureClient = homeFeatureClient
            },
        )
    }

    func makeNearbyVehicleMapStore() -> StoreOf<NearbyVehicleMapFeature> {
        Store(
            initialState: NearbyVehicleMapFeature.State(),
            reducer: {
                NearbyVehicleMapFeature()
            },
            withDependencies: {
                $0.nearbyVehicleMapFeatureClient = nearbyVehicleMapFeatureClient
            },
        )
    }
}
