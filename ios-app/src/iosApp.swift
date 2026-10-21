import MobiIOSDependencies
import SwiftUI

@main
struct IOSApp: App {
    private let appServices = AppServices()

    var body: some Scene {
        WindowGroup {
            AppRootView(appServices: appServices)
        }
    }
}

private struct AppRootView: View {
    let appServices: AppServices
    @StateObject private var homeStore: StoreOf<HomeFeature>
    @StateObject private var nearbyStore: StoreOf<NearbyVehicleMapFeature>
    @SceneStorage("selectedAppDestination") private var selectedDestination = AppDestination.nearbyMap

    init(appServices: AppServices) {
        self.appServices = appServices
        _homeStore = StateObject(wrappedValue: appServices.makeHomeStore())
        _nearbyStore = StateObject(wrappedValue: appServices.makeNearbyVehicleMapStore())
    }

    var body: some View {
        TabView(selection: $selectedDestination) {
            HomeView(store: homeStore)
                .tabItem {
                    Label("Native Home", systemImage: "iphone")
                }
                .tag(AppDestination.nativeHome)

            NearbyVehicleMapView(store: nearbyStore)
                .tabItem {
                    Label("Nearby Map", systemImage: "map")
                }
                .tag(AppDestination.nearbyMap)

            SharedHomeDemoView(makeViewController: appServices.makeSharedHomeViewController)
                .tabItem {
                    Label("Shared UI", systemImage: "square.stack.3d.up")
                }
                .tag(AppDestination.sharedUI)
        }
    }
}

private enum AppDestination: String {
    case nativeHome
    case nearbyMap
    case sharedUI
}
