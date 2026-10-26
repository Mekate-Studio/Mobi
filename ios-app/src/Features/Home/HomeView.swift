import MobiIOSDependencies
import SwiftUI

struct HomeView: View {
    let store: StoreOf<HomeFeature>
    let onRefreshTapped: () -> Void

    var body: some View {
        NavigationStack {
            HomeScreenContent(
                title: store.title,
                message: store.message,
                supportingText: store.supportingText,
                counterLoadable: store.counterLoadable,
                primaryActionLabel: store.primaryActionLabel,
                onRefreshTapped: onRefreshTapped,
            )
            .navigationTitle("Home")
        }
        .task {
            store.send(.task)
        }
    }
}
