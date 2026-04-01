import Foundation
import KotlinModules

struct HomeViewState: Equatable {
    var title = ""
    var message = ""
    var supportingText = ""
    var refreshCount = 0
    var primaryActionLabel = "Refresh shared state"

    mutating func apply(sharedState: HomeFeatureState) {
        title = sharedState.title
        message = sharedState.message
        supportingText = sharedState.supportingText
        refreshCount = Int(sharedState.refreshCount)
        primaryActionLabel = sharedState.primaryActionLabel
    }
}

enum HomeAction {
    case task
    case refreshTapped
}

final class HomeStore: ObservableObject {
    @Published private(set) var state = HomeViewState()

    private let stateFactory: HomeFeatureStateFactory

    init(stateFactory: HomeFeatureStateFactory = HomeFeatureStateFactory()) {
        self.stateFactory = stateFactory
    }

    func send(_ action: HomeAction) {
        switch action {
        case .task:
            state.apply(sharedState: stateFactory.create(refreshCount: Int32(state.refreshCount)))

        case .refreshTapped:
            let nextRefreshCount = Int(
                stateFactory.reduce(
                    refreshCount: Int32(state.refreshCount),
                    event: HomeFeatureEventRefreshClicked.shared
                )
            )
            state.apply(sharedState: stateFactory.create(refreshCount: Int32(nextRefreshCount)))
        }
    }
}
