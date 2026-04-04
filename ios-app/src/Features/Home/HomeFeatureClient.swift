import ComposableArchitecture
import Foundation
@preconcurrency import KotlinModules

struct HomeFeatureClient {
    var initialState: @Sendable () -> HomeFeatureState
    var loadingState: @Sendable (_ counterValue: Int) -> HomeFeatureState
    var refresh: @Sendable (_ counterValue: Int) async -> HomeFeatureState
}

extension HomeFeatureClient {
    init(service: HomeFeatureService) {
        self.init(
            initialState: {
                service.initialState()
            },
            loadingState: { counterValue in
                service.loadingState(counterValue: Int32(counterValue))
            },
            refresh: { counterValue in
                do {
                    return try await service.refresh(counterValue: Int32(counterValue))
                } catch {
                    return service.errorState(
                        counterValue: Int32(counterValue),
                        message: error.localizedDescription
                    )
                }
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
