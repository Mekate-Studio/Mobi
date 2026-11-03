import MobiIOSDependencies
import SwiftUI

struct HomeRefreshLifecycle<Content: View>: View {
    let store: StoreOf<HomeFeature>
    let isHomeSelected: Bool
    @ViewBuilder let content: (@escaping () -> StoreTask?) -> Content
    @Environment(\.scenePhase) private var scenePhase
    @State private var lifetime = HomeRefreshLifetime()
    @State private var acceptsRefresh = false

    var body: some View {
        content {
            guard acceptsRefresh else { return nil }
            return lifetime.refresh(in: store)
        }
        .onChange(of: isHomeSelected && scenePhase != .background, initial: true) { _, allowed in
            acceptsRefresh = allowed
            if isHomeSelected {
                lifetime.scenePhaseChanged(scenePhase, in: store)
            } else {
                lifetime.stop(in: store)
            }
        }
        .onDisappear {
            acceptsRefresh = false
            lifetime.stop(in: store)
        }
    }
}
