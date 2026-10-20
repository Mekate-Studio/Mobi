import Foundation
@preconcurrency import MobiHome
import MobiIOSDependencies

struct HomeFeatureClient: Sendable {
    var initialState: @Sendable () -> HomeCounterLoadable
    var loadingState: @Sendable (_ counterValue: Int) -> HomeCounterLoadable
    var refresh: @Sendable (_ counterValue: Int) async -> HomeCounterLoadable
}

extension HomeFeatureClient {
    init(service: HomeFeatureService) {
        self.init(
            initialState: {
                HomeCounterLoadable(sharedState: service.initialState())
            },
            loadingState: { counterValue in
                HomeCounterLoadable(sharedState: service.loadingState(counterValue: Int32(counterValue)))
            },
            refresh: { counterValue in
                do {
                    let sharedState = try await service.refresh(counterValue: Int32(counterValue))
                    return HomeCounterLoadable(sharedState: sharedState)
                } catch {
                    return HomeCounterLoadable(
                        sharedState: service.unexpectedErrorState(counterValue: Int32(counterValue)),
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

private extension HomeCounterLoadable {
    init(sharedState: HomeFeatureState) {
        switch sharedState.counterLoadable.sealedType() {
        case .initial:
            self = .initial

        case let .loading(loading):
            self = .loading(previousValue: loading.value.previousValue.map(Int.init))

        case let .loaded(loaded):
            self = .loaded(value: Int(loaded.value.value))

        case let .error(error):
            self = .error(
                previousValue: error.value.previousValue.map(Int.init),
                reason: HomeCounterLoadFailureReason(sharedReason: error.value.reason),
            )
        }
    }
}

private extension HomeCounterLoadFailureReason {
    init(sharedReason: CounterLoadFailureReason) {
        switch sharedReason.sealedType() {
        case .repositoryUnavailable:
            self = .repositoryUnavailable
        case .unexpected:
            self = .unexpected
        }
    }
}
