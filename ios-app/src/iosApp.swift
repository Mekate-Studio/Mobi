import ComposableArchitecture
import SwiftUI

@main
struct iosApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView(
                store: Store(
                    initialState: HomeFeature.State(),
                    reducer: {
                        HomeFeature()
                    }
                )
            )
        }
    }
}
