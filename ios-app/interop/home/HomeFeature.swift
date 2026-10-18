import Foundation
import MobiIOSDependencies

@Reducer
struct HomeFeature {
    @Dependency(\.homeFeatureClient) private var homeFeatureClient
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                guard !state.retired, state.activeRequest == nil else { return .none }
                guard case .initial = state.counterLoadable else { return .none }
                do {
                    state.counterLoadable = try homeFeatureClient.initialState()
                } catch let error as AdmissionError {
                    state.admissionFailure = error
                } catch {
                    state.boundaryFailure = (error as? HomeBoundaryFailure) ?? .invalidResult
                }
                return .none
            case .refreshTapped:
                guard state.canRequestRefresh, state.activeRequest == nil else { return .none }
                state.admissionFailure = nil
                state.boundaryFailure = nil
                let previous = state.counterLoadable
                let current = previous.currentValueForRefresh
                let client = homeFeatureClient
                let request = UUID()
                do {
                    state.counterLoadable = try client.loadingState(current)
                } catch let error as AdmissionError {
                    state.admissionFailure = error
                    return .none
                } catch {
                    state.boundaryFailure = (error as? HomeBoundaryFailure) ?? .invalidResult
                    return .none
                }
                state.previousValue = previous
                state.activeRequest = request
                return .run { send in
                    do {
                        try await send(.response(request, client.refresh(current)))
                    } catch is CancellationError { client.notifyCancelled(request); return
                    } catch let error as AdmissionError { await send(.admissionDenied(
                        request,
                        error,
                    )) } catch { await send(.boundaryFailed(
                        request,
                        (error as? HomeBoundaryFailure) ?? .invalidResult,
                    )) }
                }.cancellable(id: state.cancellationID)
            case let .response(request, value):
                guard !state.retired, state.activeRequest == request else { return .none }
                state.counterLoadable = value
                state.activeRequest = nil
                state.previousValue = nil
                return .none
            case let .admissionDenied(request, error):
                guard !state.retired, state.activeRequest == request else { return .none }
                if let previous = state.previousValue {
                    state.counterLoadable = previous
                }
                state.previousValue = nil; state.activeRequest = nil; state.admissionFailure = error
                return .none
            case let .cancelled(request):
                guard !state.retired, state.activeRequest == request else { return .none }
                if let previous = state.previousValue {
                    state.counterLoadable = previous
                }
                state.activeRequest = nil; state.previousValue = nil
                return .none
            case let .boundaryFailed(request, error):
                guard !state.retired, state.activeRequest == request else { return .none }
                if let previous = state.previousValue {
                    state.counterLoadable = previous
                }
                state.activeRequest = nil
                state.previousValue = nil
                state.boundaryFailure = error
                return .none
            case .cancelRefresh:
                if let previous = state.previousValue {
                    state.counterLoadable = previous
                }
                state.activeRequest = nil
                state.previousValue = nil
                return .cancel(id: state.cancellationID)
            case .retire:
                state.retired = true
                if let previous = state.previousValue {
                    state.counterLoadable = previous
                }
                state.activeRequest = nil
                state.previousValue = nil
                homeFeatureClient.retire()
                return .cancel(id: state.cancellationID)
            }
        }
    }
}
