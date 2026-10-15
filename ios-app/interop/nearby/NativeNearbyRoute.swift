import MobiIOSDependencies
import SwiftUI
import UIKit

/// The shell retains this route until the navigation owner ends.
@MainActor public final class NativeNearbyRoute {
    let store: StoreOf<NearbyVehicleMapFeature>
    private let access: NativeNearbyAccess
    private let relay = CancellationRelay()

    init(access: NativeNearbyAccess) {
        self.access = access
        let client = NearbyVehicleMapFeatureClient(access: access, relay: relay)
        let store = Store(initialState: NearbyVehicleMapFeature.State()) {
            NearbyVehicleMapFeature().dependency(\.nearbyVehicleMapFeatureClient, client)
        }
        self.store = store
        relay.sink = { [weak store] request in _ = store?.send(.cancelled(request)) }
    }

    public func makeViewController() -> UIViewController {
        UIHostingController(rootView: NearbyVehicleMapView(store: store))
    }

    public func retire() {
        store.send(.retire)
    }
}

@MainActor final class WeakNearbyRoute {
    weak var value: NativeNearbyRoute?
    init(_ route: NativeNearbyRoute) {
        value = route
    }
}
