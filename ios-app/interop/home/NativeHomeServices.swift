import Foundation
@_implementationOnly import MobiAppComposition
import MobiIOSDependencies
@_implementationOnly import MobiNativeServices
import SwiftUI
import UIKit

private typealias Composition = ExportedKotlinPackages.studio.mekate.mobi.export.composition

/// Provisional Home integration. Settings are explicit evaluation inputs.
/// The composition will also supply Nearby and Shared UI before adoption.
@MainActor public final class NativeHomeServices {
    private let composition: Composition.AppComposition
    private let admission: AdmissionPool
    private let supervisor = CompletionDrainSupervisor()
    private let jobsPerOwner: Int32
    private let observersPerRequest: Int32
    private var routes: [WeakHomeRoute] = []

    public init(parentReservations: Int, jobsPerOwner: Int32, observersPerRequest: Int32) {
        precondition(parentReservations > 0 && jobsPerOwner > 0 && observersPerRequest > 0)
        admission = AdmissionPool(capacity: parentReservations)
        self.jobsPerOwner = jobsPerOwner
        self.observersPerRequest = observersPerRequest
        // Main confinement is provisional. This Home slice does not qualify
        // the complete Nearby/Compose repository cohort or production settings.
        composition = Composition.AppComposition(policy: 0, nativeJobsPerOwner: jobsPerOwner)
    }

    public func makeHomeRoute() -> NativeHomeRoute {
        let facade = HomeTransport.HomeRequestOwner(
            service: composition.homeService,
            maxJobs: jobsPerOwner,
            maxObserversPerRequest: observersPerRequest,
        )
        let route = NativeHomeRoute(access: NativeHomeAccess(
            facade: facade,
            supervisor: supervisor,
            admission: admission,
        ))
        routes.removeAll { $0.value == nil }
        routes.append(WeakHomeRoute(route))
        return route
    }

    public func retire() {
        admission.close()
        routes.forEach { $0.value?.retire() }
        routes.removeAll()
    }
}

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

@MainActor private final class WeakHomeRoute {
    weak var value: NativeHomeRoute?
    init(_ route: NativeHomeRoute) {
        value = route
    }
}
