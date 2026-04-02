import ComposableArchitecture
import SwiftUI

struct HomeView: View {
    let store: StoreOf<HomeFeature>

    var body: some View {
        NavigationStack {
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
                    VStack(alignment: .leading, spacing: 12) {
                        Text(store.title)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text(store.message)
                            .font(.title3.weight(.semibold))
                        Text(store.supportingText)
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Text("Refresh count: \(store.refreshCount)")
                            .font(.caption.weight(.bold))
                            .textCase(.uppercase)
                            .foregroundStyle(.blue)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .shadow(color: Color.black.opacity(0.08), radius: 24, y: 12)
                    )

                    Button(action: { store.send(.refreshTapped) }) {
                        Text(store.primaryActionLabel)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.12, green: 0.38, blue: 0.84))
                }
                .padding(24)
            }
            .navigationTitle("Home")
        }
        .task {
            store.send(.task)
        }
    }
}
