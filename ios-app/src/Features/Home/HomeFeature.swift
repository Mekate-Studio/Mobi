import ComposableArchitecture
import Foundation

@Reducer
struct HomeFeature {
    @Dependency(\.homeFeatureClient) private var homeFeatureClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                state.apply(sharedState: homeFeatureClient.initialState())
                return .none

            case .refreshTapped:
                let currentCounterValue = state.counterLoadable.currentValueForRefresh
                state.apply(sharedState: homeFeatureClient.loadingState(currentCounterValue))
                return .run { send in
                    let sharedState = await homeFeatureClient.refresh(currentCounterValue)
                    var loadedState = State()
                    loadedState.apply(sharedState: sharedState)
                    await send(.sharedStateLoaded(loadedState))
                }

            case let .sharedStateLoaded(loadedState):
                state = loadedState
                return .none
            }
        }
    }
}
