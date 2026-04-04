import ComposableArchitecture
import KotlinModules

extension HomeFeature {
    @ObservableState
    struct State: Equatable {
        var title = ""
        var message = ""
        var supportingText = ""
        var primaryActionLabel = "Load next counter value"
        var counterLoadable = HomeCounterLoadable.initial

        mutating func apply(sharedState: HomeFeatureState) {
            title = sharedState.title
            message = sharedState.message
            supportingText = sharedState.supportingText
            primaryActionLabel = sharedState.primaryActionLabel
            counterLoadable = HomeCounterLoadable(sharedLoadable: sharedState.counterLoadable)
        }
    }
}
