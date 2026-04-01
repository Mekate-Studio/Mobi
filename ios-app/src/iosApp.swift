import SwiftUI

@main
struct iosApp: App {
    @StateObject private var store = HomeStore()

    var body: some Scene {
        WindowGroup {
            HomeView(store: store)
        }
    }
}
