import ComposableArchitecture
import Foundation
@preconcurrency import KotlinModules

struct HomeFeatureClient {
    var initialState: @Sendable () -> HomeFeatureState
    var loadingState: @Sendable (_ counterValue: Int) -> HomeFeatureState
    var refresh: @Sendable (_ counterValue: Int) async throws -> HomeFeatureState
}

extension HomeFeatureClient {
    init(service: HomeFeatureService) {
        self.init(
            initialState: {
                service.initialState(counterValue: 0)
            },
            loadingState: { counterValue in
                service.loadingState(counterValue: Int32(counterValue))
            },
            refresh: { counterValue in
                try await service.refresh(counterValue: Int32(counterValue))
            }
        )
    }
}

extension HomeFeatureClient: DependencyKey {
    static let liveValue = HomeFeatureClient(
        service: SharedDependencies.shared.createDefaultHomeFeatureService()
    )
}

extension DependencyValues {
    var homeFeatureClient: HomeFeatureClient {
        get { self[HomeFeatureClient.self] }
        set { self[HomeFeatureClient.self] = newValue }
    }
}
