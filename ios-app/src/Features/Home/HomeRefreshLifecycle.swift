import MobiIOSDependencies
import SwiftUI

struct HomeRefreshLifecycle<Content: View>: View {
    let store: StoreOf<HomeFeature>
    let isHomeSelected: Bool
    @ViewBuilder let content: (@escaping () -> StoreTask) -> Content
    @Environment(\.scenePhase) private var scenePhase
    @State private var lifetime = HomeRefreshLifetime()

    var body: some View {
        content { lifetime.refresh(in: store) }
            .onChange(of: isHomeSelected, initial: true) { _, selected in
                if !selected {
                    lifetime.stop(in: store)
                }
            }
            .onDisappear { lifetime.stop(in: store) }
            .onChange(of: scenePhase, initial: true) { _, phase in
                lifetime.scenePhaseChanged(phase, in: store)
            }
    }
}
