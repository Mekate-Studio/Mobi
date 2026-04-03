import ComposableArchitecture
import Foundation

@Reducer
struct HomeFeature {
    @Dependency(\.homeFeatureClient) private var homeFeatureClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                state.apply(sharedState: homeFeatureClient.create(state.refreshCount))
                return .none

            case .refreshTapped:
                let nextRefreshCount = homeFeatureClient.reduce(state.refreshCount)
                state.apply(sharedState: homeFeatureClient.create(nextRefreshCount))
                return .none
            }
        }
    }
}
