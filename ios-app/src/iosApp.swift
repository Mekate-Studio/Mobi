import ComposableArchitecture
import SwiftUI

@main
struct IOSApp: App {
    private let appServices = AppServices()

    var body: some Scene {
        WindowGroup {
            TabView {
                HomeView(store: appServices.makeHomeStore())
                    .tabItem {
                        Label("Native Home", systemImage: "iphone")
                    }

                SharedHomeDemoView(factory: appServices.sharedHomeViewControllerFactory)
                    .tabItem {
                        Label("Shared UI", systemImage: "square.stack.3d.up")
                    }
            }
        }
    }
}
