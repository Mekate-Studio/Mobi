import ComposableArchitecture
import KotlinModules

@MainActor
struct AppServices {
    let homeFeatureClient: HomeFeatureClient
    let sharedHomeViewControllerFactory: SharedHomeViewControllerFactory

    init(
        homeFeatureService: HomeFeatureService = SharedDependencies.shared.createDefaultHomeFeatureService(),
    ) {
        homeFeatureClient = HomeFeatureClient(service: homeFeatureService)
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
}
