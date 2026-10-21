import Foundation
import MobiIOSDependencies

@Reducer
struct HomeFeature {
    @Dependency(\.homeFeatureClient) private var homeFeatureClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                guard case .initial = state.counterLoadable else { return .none }
                state.counterLoadable = homeFeatureClient.initialState()
                return .none

            case .refreshTapped:
                let currentCounterValue = state.counterLoadable.currentValueForRefresh
                state.counterLoadable = homeFeatureClient.loadingState(currentCounterValue)
                return .run { send in
                    let counterLoadable = await homeFeatureClient.refresh(currentCounterValue)
                    await send(.refreshResponse(counterLoadable))
                }

            case let .refreshResponse(counterLoadable):
                state.counterLoadable = counterLoadable
                return .none
            }
        }
    }
}
