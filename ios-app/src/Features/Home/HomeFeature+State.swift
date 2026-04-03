import ComposableArchitecture
import KotlinModules

extension HomeFeature {
    @ObservableState
    struct State: Equatable {
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
}
