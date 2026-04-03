import ComposableArchitecture
import KotlinModules

@MainActor
struct AppServices {
    let homeFeatureClient: HomeFeatureClient
    let sharedHomeViewControllerFactory: SharedHomeViewControllerFactory

    init(
        homeFeatureStateFactory: HomeFeatureStateFactory = SharedDependencies.shared.createDefaultHomeFeatureStateFactory()
    ) {
        self.homeFeatureClient = HomeFeatureClient(stateFactory: homeFeatureStateFactory)
        self.sharedHomeViewControllerFactory = SharedHomeViewControllerFactory(
            stateFactory: homeFeatureStateFactory
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
            }
        )
    }
}
