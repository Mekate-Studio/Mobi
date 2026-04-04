import SwiftUI

struct HomeScreenContent: View {
    let title: String
    let message: String
    let supportingText: String
    let counterValue: Int
    let primaryActionLabel: String
    let isLoading: Bool
    let onRefreshTapped: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.98, blue: 1.0),
                    Color(red: 0.87, green: 0.93, blue: 0.99),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                HomeHeroCard(
                    title: title,
                    message: message,
                    supportingText: supportingText,
                    counterValue: counterValue
                )

                HomePrimaryActionButton(
                    title: primaryActionLabel,
                    isLoading: isLoading,
                    action: onRefreshTapped
                )
            }
            .padding(24)
        }
    }
}
