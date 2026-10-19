import MobiHome
import MobiIOS
import MobiIOSDependencies
import MobiNearby
import UIKit

@MainActor
struct AppServices {
    let homeFeatureClient: HomeFeatureClient
    let nearbyVehicleMapFeatureClient: NearbyVehicleMapFeatureClient
    let makeSharedHomeViewController: @MainActor () -> UIViewController

    init(
        homeFeatureService: HomeFeatureService = IosDependencies.shared.createHomeFeatureService(),
        nearbyVehicleMapFeatureService: NearbyVehicleMapFeatureService = IosDependencies.shared
            .createNearbyVehicleMapFeatureService(),
    ) {
        homeFeatureClient = HomeFeatureClient(service: homeFeatureService)
        nearbyVehicleMapFeatureClient = NearbyVehicleMapFeatureClient(service: nearbyVehicleMapFeatureService)
        makeSharedHomeViewController = {
            IosDependencies.shared.createSharedHomeViewController(service: homeFeatureService)
        }
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
