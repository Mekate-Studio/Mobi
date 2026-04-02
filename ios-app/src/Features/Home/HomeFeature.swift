import ComposableArchitecture
import Foundation

@Reducer
struct HomeFeature {
    @ObservableState
    struct State: Equatable {
        var title = ""
        var message = ""
        var supportingText = ""
        var refreshCount = 0
        var primaryActionLabel = "Refresh shared state"

        mutating func apply(
            title: String,
            message: String,
            supportingText: String,
            refreshCount: Int,
            primaryActionLabel: String
        ) {
            self.title = title
            self.message = message
            self.supportingText = supportingText
            self.refreshCount = refreshCount
            self.primaryActionLabel = primaryActionLabel
        }
    }

    enum Action: Equatable {
        case task
        case refreshTapped
    }

    @Dependency(\.homeFeatureClient) private var homeFeatureClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let sharedState = homeFeatureClient.create(state.refreshCount)
                state.apply(
                    title: sharedState.title,
                    message: sharedState.message,
                    supportingText: sharedState.supportingText,
                    refreshCount: Int(sharedState.refreshCount),
                    primaryActionLabel: sharedState.primaryActionLabel
                )
                return .none

            case .refreshTapped:
                let nextRefreshCount = homeFeatureClient.reduce(state.refreshCount)
                let sharedState = homeFeatureClient.create(nextRefreshCount)
                state.apply(
                    title: sharedState.title,
                    message: sharedState.message,
                    supportingText: sharedState.supportingText,
                    refreshCount: Int(sharedState.refreshCount),
                    primaryActionLabel: sharedState.primaryActionLabel
                )
                return .none
            }
        }
    }
}
