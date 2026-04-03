import ComposableArchitecture
import SwiftUI

@main
struct iosApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                HomeView(
                    store: Store(
                        initialState: HomeFeature.State(),
                        reducer: {
                            HomeFeature()
                        }
                    )
                )
                .tabItem {
                    Label("Native Home", systemImage: "iphone")
                }

                SharedHomeDemoView()
                    .tabItem {
                        Label("Shared UI", systemImage: "square.stack.3d.up")
                    }
            }
        }
    }
}
