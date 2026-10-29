import MobiIOSDependencies
import SwiftUI

struct NearbyVehicleMapLifecycle<Content: View>: View {
    let store: StoreOf<NearbyVehicleMapFeature>
    @ViewBuilder let content: (@escaping (NearbyVehicleMapFeature.Action) -> Void) -> Content
    @Environment(\.scenePhase) private var scenePhase
    @State private var lifetime = NearbyVehicleMapLifetime()

    var body: some View {
        content { lifetime.send($0, in: store) }
            .task(id: scenePhase != .background) {
                guard scenePhase != .background, !Task.isCancelled else { return }
                lifetime.start(in: store)
            }
            .onChange(of: scenePhase != .background) { _, outsideBackground in
                if !outsideBackground {
                    lifetime.stop(in: store)
                }
            }
            .onDisappear { lifetime.stop(in: store) }
    }
}
