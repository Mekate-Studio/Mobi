import ComposableArchitecture
import KotlinModules

extension HomeFeature {
    @ObservableState
    struct State: Equatable {
        var counterLoadable = HomeCounterLoadable.initial

        mutating func apply(sharedState: HomeFeatureState) {
            counterLoadable = HomeCounterLoadable(sharedLoadable: sharedState.counterLoadable)
        }

        var title: String {
            "Shared feature, platform rendering"
        }

        var message: String {
            "Shared business logic feeding a platform-specific screen."
        }

        var supportingText: String {
            counterLoadable.supportingText
        }

        var primaryActionLabel: String {
            "Load next counter value"
        }
    }
}
