import Foundation
import KotlinModules

@MainActor
final class AppDependencies {
    let homeFeatureStateFactory: HomeFeatureStateFactory
    let homeFeatureClient: HomeFeatureClient
    let sharedHomeViewControllerFactory: SharedHomeViewControllerFactory

    init(
        homeFeatureStateFactory: HomeFeatureStateFactory = SharedDependencies.shared.createDefaultHomeFeatureStateFactory()
    ) {
        self.homeFeatureStateFactory = homeFeatureStateFactory
        self.homeFeatureClient = HomeFeatureClient(stateFactory: homeFeatureStateFactory)
        self.sharedHomeViewControllerFactory = SharedHomeViewControllerFactory(
            stateFactory: homeFeatureStateFactory
        )
    }
}
