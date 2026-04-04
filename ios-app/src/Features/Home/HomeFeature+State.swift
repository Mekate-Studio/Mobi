import ComposableArchitecture
import KotlinModules

extension HomeFeature {
    @ObservableState
    struct State: Equatable {
        var title = ""
        var message = ""
        var supportingText = ""
        var counterValue = 0
        var primaryActionLabel = "Load next counter value"
        var isLoading = false

        mutating func apply(sharedState: HomeFeatureState) {
            title = sharedState.title
            message = sharedState.message
            supportingText = sharedState.supportingText
            counterValue = Int(sharedState.counterValue)
            primaryActionLabel = sharedState.primaryActionLabel
            isLoading = sharedState.isLoading
        }
    }
}
