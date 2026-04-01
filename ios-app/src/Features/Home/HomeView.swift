import KotlinModules
import SwiftUI

struct ComposeHomeView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> some UIViewController {
        ViewControllerKt.ViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {}
}

struct HomeView: View {
    @ObservedObject var store: HomeStore

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
                        Text(store.state.title)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text(store.state.message)
                            .font(.title3.weight(.semibold))
                        Text(store.state.supportingText)
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Text("Refresh count: \(store.state.refreshCount)")
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
                        Text(store.state.primaryActionLabel)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.12, green: 0.38, blue: 0.84))

                    ComposeHomeView()
                        .frame(height: 0)
                        .opacity(0.0)
                        .accessibilityHidden(true)
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
