import ComposableArchitecture
import Foundation
@preconcurrency import KotlinModules

struct HomeFeatureClient {
    var create: @Sendable (_ refreshCount: Int) -> HomeFeatureState
    var reduce: @Sendable (_ refreshCount: Int) -> Int
}

extension HomeFeatureClient {
    init(stateFactory: HomeFeatureStateFactory) {
        self.init(
            create: { refreshCount in
                stateFactory.create(refreshCount: Int32(refreshCount))
            },
            reduce: { refreshCount in
                Int(
                    stateFactory.reduce(
                        refreshCount: Int32(refreshCount),
                        event: HomeFeatureEventRefreshClicked.shared
                    )
                )
            }
        )
    }
}

extension HomeFeatureClient: DependencyKey {
    static let liveValue = HomeFeatureClient(
        stateFactory: SharedDependencies.shared.createDefaultHomeFeatureStateFactory()
    )
}

extension DependencyValues {
    var homeFeatureClient: HomeFeatureClient {
        get { self[HomeFeatureClient.self] }
        set { self[HomeFeatureClient.self] = newValue }
    }
}
