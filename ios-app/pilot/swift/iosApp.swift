import SwiftUI

@main struct SwiftExportPilotApp: App {
    var body: some Scene {
        WindowGroup { PilotRootView() }
    }
}

@MainActor private final class PilotSession: ObservableObject {
    let services = AppServices()
    isolated deinit { services.retire() }
}

private struct PilotRootView: View {
    @StateObject private var session = PilotSession()
    @SceneStorage("selectedAppDestination") private var selected = AppDestination.nearbyMap
    var body: some View {
        TabView(selection: $selected) {
            OwnedNativeHomeRoute(services: session.services)
                .tabItem { Label("Native Home", systemImage: "iphone") }.tag(AppDestination.nativeHome)
            OwnedNearbyRoute(services: session.services)
                .tabItem { Label("Nearby Map", systemImage: "map") }.tag(AppDestination.nearbyMap)
            #if MOBI_PILOT_COMPOSE
                SharedHomeDemoView(services: session.services)
                    .tabItem { Label("Shared UI", systemImage: "square.stack.3d.up") }.tag(AppDestination.sharedUI)
            #endif
        }
    }
}

private enum AppDestination: String { case nativeHome, nearbyMap, sharedUI }
