import Foundation
import MobiIOSDependencies

@Reducer
struct NearbyVehicleMapFeature {
    @Dependency(\.nearbyVehicleMapFeatureClient) private var client
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                guard !state.retired, state.sharedState == nil else { return .none }
                state.sharedState = try? client.initialState()
                return .none
            case let .locationResolutionResponse(result):
                guard !state.retired, state.sharedState != nil else { return .none }
                restoreBeforeCancel(state: &state)
                guard let current = state.sharedState else { return .none }
                do {
                    switch result {
                    case let .precise(latitude, longitude):
                        try replace(client.preciseLocationResolvedState(current, latitude, longitude), state: &state)
                        return .concatenate(
                            .cancel(id: state.cancellationID),
                            refreshEffect(state: &state, nowMillis: client.nowMillis()),
                        )
                    case let .blocked(reason): try replace(client.locationBlockedState(current, reason), state: &state)
                    case .temporarilyUnavailable: try replace(
                            client.locationTemporarilyUnavailableState(current),
                            state: &state,
                        )
                    }
                } catch { /* Keep the restored native state on transport/input failure. */ }
                return .cancel(id: state.cancellationID)
            case .refreshTapped:
                return refreshEffect(state: &state, nowMillis: client.nowMillis())
            case let .visibleRefreshDue(nowMillis):
                guard state.admissionFailure == nil, !state.retired, state.activeRequest == nil,
                      let current = state.sharedState else { return .none }
                guard (try? client.shouldRefresh(current, nowMillis)) == true else { return .none }
                return refreshEffect(state: &state, nowMillis: nowMillis)
            case let .timePassed(nowMillis):
                guard !state.retired, state.activeRequest == nil, let current = state.sharedState,
                      let value = try? client.timePassed(current, nowMillis) else { return .none }
                replace(value, state: &state)
                return .none
            case let .response(request, value):
                guard !state.retired, state.activeRequest == request else { client.discard(value); return .none }
                do {
                    try client.adopt(value)
                } catch { client.discard(value); return .none } // no foreign/duplicate handle can become current
                replace(value, state: &state)
                if let previous = state.previousState {
                    client.release(previous)
                }
                state.previousState = nil; state.activeRequest = nil
                return .none
            case let .admissionDenied(request, error):
                guard !state.retired, state.activeRequest == request else { return .none }
                restoreBeforeCancel(state: &state); state.admissionFailure = error
                return .none
            case let .aborted(request):
                guard !state.retired, state.activeRequest == request else { return .none }
                restoreBeforeCancel(state: &state)
                return .none
            case let .cancelled(request):
                guard !state.retired, state.activeRequest == request else { return .none }
                restoreBeforeCancel(state: &state)
                return .none
            case .cancelRefresh:
                restoreBeforeCancel(state: &state)
                return .cancel(id: state.cancellationID)
            case .retire:
                guard !state.retired else { return .none }
                restoreBeforeCancel(state: &state)
                state.retired = true; client.retire()
                return .cancel(id: state.cancellationID)
            }
        }
    }

    private func replace(_ value: NativeNearbyState, state: inout State) {
        if let old = state.sharedState, !old.sameHandle(as: value) {
            client.release(old)
        }
        state.sharedState = value
    }

    private func restoreBeforeCancel(state: inout State) {
        if let previous = state.previousState {
            replace(previous, state: &state)
        }
        state.previousState = nil; state.activeRequest = nil
    }

    private func refreshEffect(state: inout State, nowMillis: Int64) -> Effect<Action> {
        guard state.canRequestRefresh, state.activeRequest == nil, let current = state.sharedState, current.canRefresh,
              let loading = try? client.loadingState(current) else { return .none }
        state.admissionFailure = nil
        let request = UUID(), client = client
        state.previousState = current; state.sharedState = loading; state.activeRequest = request
        return .run { send in
            do {
                let value = try await client.refresh(loading, nowMillis)
                await send(.response(request, value))
                // Even if TCA drops a cancelled send, release any result the reducer did not adopt.
                await client.discardAfterSend(value)
            } catch is CancellationError { client.notifyCancelled(request); return } catch let error as AdmissionError {
                await send(.admissionDenied(
                    request,
                    error,
                ))
            } catch { await send(.aborted(request)) }
        }.cancellable(id: state.cancellationID)
    }
}
