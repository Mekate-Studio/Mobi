import Foundation
import MobiIOSDependencies

@Reducer
struct HomeFeature {
    @Dependency(\.homeFeatureClient) private var homeFeatureClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .scenePhaseChanged(.background):
                if let previousState = state.refreshPreviousState {
                    state.counterLoadable = previousState
                    state.refreshPreviousState = nil
                }
                return .none

            case .scenePhaseChanged:
                return .none

            case .task:
                guard case .initial = state.counterLoadable else { return .none }
                state.counterLoadable = homeFeatureClient.initialState()
                return .none

            case .refreshTapped:
                guard !state.counterLoadable.isLoading else { return .none }
                let previousState = state.counterLoadable
                state.refreshPreviousState = previousState
                let currentCounterValue = previousState.currentValueForRefresh
                state.counterLoadable = homeFeatureClient.loadingState(currentCounterValue)
                return .run { send in
                    let counterLoadable = await homeFeatureClient.refresh(previousState)
                    await send(.refreshResponse(counterLoadable))
                }

            case let .refreshResponse(counterLoadable):
                state.counterLoadable = counterLoadable
                state.refreshPreviousState = nil
                return .none
            }
        }
    }
}
