import Foundation
import MobiIOSDependencies

@Reducer
struct NearbyVehicleMapFeature {
    @Dependency(\.nearbyVehicleMapFeatureClient) private var client

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                state.apply(sharedState: client.initialState())
                return .none

            case let .locationPermissionResponse(result):
                guard let sharedState = state.sharedState else { return .none }

                switch result {
                case .granted:
                    state.apply(sharedState: client.permissionGrantedState(sharedState))
                    return refreshEffect(state: &state, nowMillis: currentTimeMillis())

                case .denied:
                    state.apply(sharedState: client.permissionDeniedState(sharedState))
                    return .none

                case .temporarilyUnavailable:
                    state.apply(sharedState: client.locationTemporarilyUnavailableState(sharedState))
                    return .none
                }

            case .refreshTapped:
                return refreshEffect(state: &state, nowMillis: currentTimeMillis())

            case let .visibleRefreshDue(nowMillis):
                guard let sharedState = state.sharedState else { return .none }
                guard client.shouldRefresh(sharedState, nowMillis) else { return .none }
                return refreshEffect(state: &state, nowMillis: nowMillis)

            case let .sharedStateLoaded(loadedState):
                state = loadedState
                return .none
            }
        }
    }

    private func refreshEffect(
        state: inout State,
        nowMillis: Int64,
    ) -> Effect<Action> {
        guard let sharedState = state.sharedState else { return .none }

        let loadingState = client.loadingState(sharedState)
        state.apply(sharedState: loadingState)

        return .run { send in
            let sharedState = await client.refresh(loadingState, nowMillis)
            var loadedState = State()
            loadedState.apply(sharedState: sharedState)
            await send(.sharedStateLoaded(loadedState))
        }
    }

    private func currentTimeMillis() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }
}
