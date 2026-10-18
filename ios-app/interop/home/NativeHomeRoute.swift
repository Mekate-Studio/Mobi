import MobiIOSDependencies
import SwiftUI
import UIKit

/// The shell owns route lifetime; tab changes/backgrounding need not retire it.
@MainActor public final class NativeHomeRoute {
    let store: StoreOf<HomeFeature>
    private let access: NativeHomeAccess
    private let relay = CancellationRelay()

    init(access: NativeHomeAccess) {
        self.access = access
        let client = HomeFeatureClient(access: access, relay: relay)
        let store = Store(initialState: HomeFeature.State()) { HomeFeature().dependency(\.homeFeatureClient, client) }
        self.store = store
        relay.sink = { [weak store] request in _ = store?.send(.cancelled(request)) }
    }

    public func makeViewController() -> UIViewController {
        UIHostingController(rootView: HomeView(store: store))
    }

    public func retire() {
        store.send(.retire)
    }
}

@MainActor final class WeakHomeRoute {
    weak var value: NativeHomeRoute?
    init(_ route: NativeHomeRoute) {
        value = route
    }
}
