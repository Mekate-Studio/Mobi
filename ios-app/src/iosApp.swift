import ComposableArchitecture
import SwiftUI

@main
struct iosApp: App {
    private let appDependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            TabView {
                HomeView(
                    store: Store(
                        initialState: HomeFeature.State(),
                        reducer: {
                            HomeFeature()
                        },
                        withDependencies: {
                            $0.homeFeatureClient = appDependencies.homeFeatureClient
                        }
                    )
                )
                .tabItem {
                    Label("Native Home", systemImage: "iphone")
                }

                SharedHomeDemoView(factory: appDependencies.sharedHomeViewControllerFactory)
                    .tabItem {
                        Label("Shared UI", systemImage: "square.stack.3d.up")
                    }
            }
        }
    }
}
