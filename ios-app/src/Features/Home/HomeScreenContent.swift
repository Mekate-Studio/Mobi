import SwiftUI

struct HomeScreenContent: View {
    let title: String
    let message: String
    let supportingText: String
    let counterLoadable: HomeCounterLoadable
    let primaryActionLabel: String
    let onRefreshTapped: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.98, blue: 1.0),
                    Color(red: 0.87, green: 0.93, blue: 0.99),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                HomeHeroCard(
                    title: title,
                    message: message,
                    supportingText: supportingText,
                    counterLoadable: counterLoadable,
                )

                HomePrimaryActionButton(
                    title: primaryActionLabel,
                    isLoading: counterLoadable.isLoading,
                    action: onRefreshTapped,
                )
            }
            .padding(24)
        }
    }
}
