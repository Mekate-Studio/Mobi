import ComposableArchitecture
import SwiftUI

struct HomeView: View {
    let store: StoreOf<HomeFeature>

    var body: some View {
        NavigationStack {
            HomeScreenContent(
                title: store.title,
                message: store.message,
                supportingText: store.supportingText,
                counterLoadable: store.counterLoadable,
                primaryActionLabel: store.primaryActionLabel,
                onRefreshTapped: refreshTapped,
            )
            .navigationTitle("Home")
        }
        .task {
            store.send(.task)
        }
    }

    private func refreshTapped() {
        store.send(.refreshTapped)
    }
}
