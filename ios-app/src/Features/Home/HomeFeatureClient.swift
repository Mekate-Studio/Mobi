import ComposableArchitecture
import Foundation
import KotlinModules

struct HomeFeatureClient {
    var create: @Sendable (_ refreshCount: Int) -> HomeFeatureState
    var reduce: @Sendable (_ refreshCount: Int) -> Int
}

extension HomeFeatureClient: DependencyKey {
    static let liveValue: HomeFeatureClient = {
        return HomeFeatureClient(
            create: { refreshCount in
                HomeFeatureStateFactory().create(refreshCount: Int32(refreshCount))
            },
            reduce: { refreshCount in
                Int(
                    HomeFeatureStateFactory().reduce(
                        refreshCount: Int32(refreshCount),
                        event: HomeFeatureEventRefreshClicked.shared
                    )
                )
            }
        )
    }()
}

extension DependencyValues {
    var homeFeatureClient: HomeFeatureClient {
        get { self[HomeFeatureClient.self] }
        set { self[HomeFeatureClient.self] = newValue }
    }
}
