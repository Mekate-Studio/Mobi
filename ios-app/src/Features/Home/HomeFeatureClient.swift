import Foundation
@preconcurrency import KotlinModules
import MobiIOSDependencies

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
                    return service.unexpectedErrorState(
                        counterValue: Int32(counterValue),
                    )
                }
            },
        )
    }
}

extension HomeFeatureClient: DependencyKey {
    static let liveValue = HomeFeatureClient(
        initialState: {
            fatalError(
                "HomeFeatureClient.liveValue was used without AppServices injecting dependencies. Create stores through AppServices so iOS has a single composition root.",
            )
        },
        loadingState: { _ in
            fatalError(
                "HomeFeatureClient.liveValue was used without AppServices injecting dependencies. Create stores through AppServices so iOS has a single composition root.",
            )
        },
        refresh: { _ in
            fatalError(
                "HomeFeatureClient.liveValue was used without AppServices injecting dependencies. Create stores through AppServices so iOS has a single composition root.",
            )
        },
    )
}

extension DependencyValues {
    var homeFeatureClient: HomeFeatureClient {
        get { self[HomeFeatureClient.self] }
        set { self[HomeFeatureClient.self] = newValue }
    }
}
