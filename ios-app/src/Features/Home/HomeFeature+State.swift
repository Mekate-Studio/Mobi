import MobiIOSDependencies

extension HomeFeature {
    @ObservableState
    struct State: Equatable {
        var counterLoadable = HomeCounterLoadable.initial
        /// Loading retains a number, so keep the exact prior state only while refresh is owned.
        var refreshPreviousState: HomeCounterLoadable?

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
